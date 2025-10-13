-- ============================================================================
-- Remove client_id from parsing_results and improve queue backfill
-- ============================================================================

-- 1. Update parsing_results schema
-- ============================================================================
-- Remove client_id (not needed for polling-only pattern)
ALTER TABLE public.parsing_results DROP COLUMN IF EXISTS client_id;

-- Remove recipe_ids (we're not saving to recipes table yet)
ALTER TABLE public.parsing_results DROP COLUMN IF EXISTS recipe_ids;

-- Add recipe_data to store parser JSON output directly
ALTER TABLE public.parsing_results ADD COLUMN IF NOT EXISTS recipe_data JSONB;

-- 1.1 Update enqueue_parse_request to remove client_id
-- ============================================================================
CREATE OR REPLACE FUNCTION enqueue_parse_request(
  p_kitchen_id UUID,
  p_gcs_files TEXT[]
)
RETURNS UUID AS $$
DECLARE
  v_request_id UUID;
  v_queue_name TEXT;
BEGIN
  -- Generate request ID
  v_request_id := gen_random_uuid();
  
  -- Send to PGMQ queue (using kp_ prefix - shortened for 48 char limit)
  v_queue_name := CONCAT('kp_', p_kitchen_id::text);
  PERFORM pgmq.send(
    v_queue_name,
    jsonb_build_object(
      'request_id', v_request_id,
      'kitchen_id', p_kitchen_id,
      'user_id', auth.uid(),
      'gcs_files', p_gcs_files,
      'enqueued_at', NOW()
    )
  );
  
  RETURN v_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Improved backfill with better error reporting
-- ============================================================================
-- This backfill is more explicit and will report which queues it creates

DO $$
DECLARE
  k RECORD;
  v_queue_name TEXT;
  v_created_count INT := 0;
  v_rls_count INT := 0;
BEGIN
  RAISE NOTICE 'Starting queue backfill for existing kitchens...';
  
  FOR k IN SELECT kitchen_id, name FROM public.kitchen ORDER BY kitchen_id LOOP
    -- Use kitchen_parse_ prefix (48 char limit allows: kitchen_parse_ = 14 + UUID = 36 = 50 chars - TOO LONG!)
    -- Solution: Shorten prefix to 'kp_' (11 chars total)
    v_queue_name := CONCAT('kp_', k.kitchen_id::text);
    
    BEGIN
      -- Try to create queue
      PERFORM pgmq.create(v_queue_name);
      v_created_count := v_created_count + 1;
      RAISE NOTICE 'Created queue: % for kitchen: %', v_queue_name, COALESCE(k.name, 'Personal');
    EXCEPTION 
      WHEN duplicate_table THEN
        RAISE NOTICE 'Queue already exists: % for kitchen: %', v_queue_name, COALESCE(k.name, 'Personal');
      WHEN OTHERS THEN
        RAISE WARNING 'Failed to create queue % for kitchen %: % - %', 
          v_queue_name, k.kitchen_id, SQLSTATE, SQLERRM;
    END;
    
    BEGIN
      -- Apply RLS (idempotent)
      PERFORM enable_queue_rls(v_queue_name);
      v_rls_count := v_rls_count + 1;
      RAISE NOTICE 'Applied RLS to queue: %', v_queue_name;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to apply RLS to queue % for kitchen %: % - %', 
        v_queue_name, k.kitchen_id, SQLSTATE, SQLERRM;
    END;
    
  END LOOP;
  
  RAISE NOTICE 'Backfill complete. Created: %, RLS applied: %', v_created_count, v_rls_count;
END;
$$;
