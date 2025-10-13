-- ============================================================================
-- Simplified Parsing Queue: PGMQ + Results Table Only
-- ============================================================================
-- This migration simplifies the parsing infrastructure to use:
-- 1. PGMQ queues for work distribution (transient, RLS-secured)
-- 2. parsing_results table for completed/failed results only (persistent, RLS-secured)
--
-- Removes: parsing_requests lifecycle tracking, dequeue/complete/fail RPCs
-- Keeps: Per-kitchen queues, enqueue RPC, cleanup function
--
-- RLS Security:
-- - PGMQ queues: Kitchen members + service role can read/write
-- - parsing_results: Users can view their own results, service role full access
-- ============================================================================

-- Drop old infrastructure if exists
DROP TABLE IF EXISTS public.parsing_requests CASCADE;
DROP FUNCTION IF EXISTS dequeue_parse_request(UUID, INT) CASCADE;
DROP FUNCTION IF EXISTS complete_parse_request(UUID, BIGINT, UUID, TEXT[]) CASCADE;
DROP FUNCTION IF EXISTS fail_parse_request(UUID, BIGINT, UUID, TEXT) CASCADE;

-- 1. Helper function to enable RLS on PGMQ queues
-- ============================================================================
CREATE OR REPLACE FUNCTION enable_queue_rls(p_queue_name TEXT)
RETURNS VOID AS $$
DECLARE
  v_table_name TEXT;
BEGIN
  -- PGMQ creates tables with pattern: pgmq.q_{queue_name}
  v_table_name := 'q_' || p_queue_name;
  
  -- Enable RLS (use schema.table format correctly)
  EXECUTE format('ALTER TABLE pgmq.%I ENABLE ROW LEVEL SECURITY', v_table_name);
  
  -- Policy: Kitchen members can read/write their kitchen's queue
  EXECUTE format('
    CREATE POLICY "Kitchen members can access their queue"
      ON pgmq.%I
      FOR ALL
      USING (
        EXISTS (
          SELECT 1 FROM public.kitchen_users
          WHERE kitchen_users.user_id = auth.uid()
          AND kitchen_users.kitchen_id::text = substring(%L from ''kitchen_parse_(.*)$'')
        )
      )
  ', v_table_name, p_queue_name);
  
  -- Policy: Service role has full access
  EXECUTE format('
    CREATE POLICY "Service role full access"
      ON pgmq.%I
      FOR ALL
      USING (auth.jwt() ->> ''role'' = ''service_role'')
  ', v_table_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create per-kitchen PGMQ queue on kitchen creation
-- ============================================================================
CREATE OR REPLACE FUNCTION create_kitchen_parsing_queue()
RETURNS TRIGGER AS $$
DECLARE
  v_queue_name TEXT;
BEGIN
  v_queue_name := CONCAT('kitchen_parse_', NEW.kitchen_id::text);
  PERFORM pgmq.create(v_queue_name);
  PERFORM enable_queue_rls(v_queue_name);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_kitchen_created ON public.kitchen;
CREATE TRIGGER on_kitchen_created
  AFTER INSERT ON public.kitchen
  FOR EACH ROW
  EXECUTE FUNCTION create_kitchen_parsing_queue();

-- Backfill queues for existing kitchens (create if not exists)
DO $$
DECLARE
  k RECORD;
BEGIN
  FOR k IN SELECT kitchen_id FROM public.kitchen LOOP
    BEGIN
      DECLARE
        v_queue_name TEXT;
      BEGIN
        v_queue_name := CONCAT('kitchen_parse_', k.kitchen_id::text);
        PERFORM pgmq.create(v_queue_name);
        PERFORM enable_queue_rls(v_queue_name);
      END;
    EXCEPTION WHEN OTHERS THEN
      NULL; -- Queue may already exist, ignore
    END;
  END LOOP;
END;
$$;

-- Backfill RLS for already-existing queues (in case they were created before RLS setup)
DO $$
DECLARE
  k RECORD;
BEGIN
  FOR k IN SELECT kitchen_id FROM public.kitchen LOOP
    BEGIN
      DECLARE
        v_queue_name TEXT;
      BEGIN
        v_queue_name := CONCAT('kitchen_parse_', k.kitchen_id::text);
        PERFORM enable_queue_rls(v_queue_name);
      END;
    EXCEPTION WHEN OTHERS THEN
      NULL; -- Queue may not exist or RLS already applied, ignore
    END;
  END LOOP;
END;
$$;

-- Trigger to delete kitchen queue when kitchen is deleted
CREATE OR REPLACE FUNCTION delete_kitchen_parsing_queue()
RETURNS TRIGGER AS $$
DECLARE
  v_queue_name TEXT;
BEGIN
  v_queue_name := CONCAT('kitchen_parse_', OLD.kitchen_id::text);
  PERFORM pgmq.drop_queue(v_queue_name);
  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  -- If queue doesn't exist or other error, don't block deletion
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_kitchen_deleted ON public.kitchen;
CREATE TRIGGER on_kitchen_deleted
  BEFORE DELETE ON public.kitchen
  FOR EACH ROW
  EXECUTE FUNCTION delete_kitchen_parsing_queue();

-- 3. Dead Letter Queue for failed requests
-- ============================================================================
DO $$
BEGIN
  PERFORM pgmq.create('parse_dlq');
  PERFORM enable_queue_rls('parse_dlq');
END;
$$;

-- 4. Results table (lightweight, only completed/failed)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.parsing_results (
  request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kitchen_id UUID NOT NULL REFERENCES public.kitchen(kitchen_id) ON DELETE CASCADE,
  client_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL CHECK (status IN ('completed', 'failed')),
  recipe_ids TEXT[],  -- Array of recipe IDs saved via save_recipe_batch
  error TEXT,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_parsing_results_user_time ON public.parsing_results(user_id, completed_at DESC);
CREATE INDEX idx_parsing_results_kitchen ON public.parsing_results(kitchen_id, completed_at DESC);

ALTER TABLE public.parsing_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own parsing results"
  ON public.parsing_results FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage all parsing results"
  ON public.parsing_results FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');

-- 5. RPC: Enqueue parse request (returns request_id)
-- ============================================================================
CREATE OR REPLACE FUNCTION enqueue_parse_request(
  p_kitchen_id UUID,
  p_client_id TEXT,
  p_gcs_files TEXT[]
)
RETURNS UUID AS $$
DECLARE
  v_request_id UUID;
  v_queue_name TEXT;
BEGIN
  -- Generate request ID
  v_request_id := gen_random_uuid();
  
  -- Send to PGMQ queue
  v_queue_name := CONCAT('kitchen_parse_', p_kitchen_id::text);
  PERFORM pgmq.send(
    v_queue_name,
    jsonb_build_object(
      'request_id', v_request_id,
      'kitchen_id', p_kitchen_id,
      'client_id', p_client_id,
      'user_id', auth.uid(),
      'gcs_files', p_gcs_files,
      'enqueued_at', NOW()
    )
  );
  
  RETURN v_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: Check if kitchen has active parsing (for agent lifecycle)
-- ============================================================================
CREATE OR REPLACE FUNCTION kitchen_has_active_parsing(p_kitchen_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_queue_name TEXT;
  v_metrics JSONB;
BEGIN
  v_queue_name := CONCAT('kitchen_parse_', p_kitchen_id::text);
  
  BEGIN
    SELECT pgmq.metrics(v_queue_name) INTO v_metrics;
    IF (v_metrics->>'queue_length')::INT > 0 THEN
      RETURN TRUE;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Function: Cleanup old parsing results (run daily)
-- ============================================================================
CREATE OR REPLACE FUNCTION cleanup_old_parsing_results()
RETURNS INT AS $$
DECLARE
  v_deleted INT;
BEGIN
  DELETE FROM public.parsing_results
  WHERE completed_at < NOW() - INTERVAL '7 days';
  
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable and schedule daily cleanup via pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
DECLARE
  v_job_id INT;
BEGIN
  -- Remove any existing job with the same name to avoid duplicates
  FOR v_job_id IN
    SELECT jobid FROM cron.job WHERE jobname = 'cleanup-parsing-results'
  LOOP
    PERFORM cron.unschedule(v_job_id);
  END LOOP;

  -- Schedule at 02:00 daily
  PERFORM cron.schedule(
    'cleanup-parsing-results',
    '0 2 * * *',
    $sql$SELECT public.cleanup_old_parsing_results()$sql$
  );
END;
$$;
