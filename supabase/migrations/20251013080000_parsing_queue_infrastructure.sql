-- ============================================================================
-- Parsing Queue Infrastructure: Per-Kitchen PGMQ Queues
-- ============================================================================

-- 1. Create PGMQ queue on kitchen creation
-- ============================================================================
CREATE OR REPLACE FUNCTION create_kitchen_parsing_queue()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pgmq.create(CONCAT('kitchen_parse_', NEW.kitchen_id::text));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_kitchen_created
  AFTER INSERT ON public.kitchen
  FOR EACH ROW
  EXECUTE FUNCTION create_kitchen_parsing_queue();

-- Backfill queues for existing kitchens
DO $$
DECLARE
  k RECORD;
BEGIN
  FOR k IN SELECT kitchen_id FROM public.kitchen LOOP
    BEGIN
      PERFORM pgmq.create(CONCAT('kitchen_parse_', k.kitchen_id::text));
    EXCEPTION WHEN OTHERS THEN
      NULL; -- Queue may already exist, ignore
    END;
  END LOOP;
END;
$$;

-- 2. Dead Letter Queue for failed requests
-- ============================================================================
SELECT pgmq.create('parse_dlq');

-- 3. Parsing request metadata table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.parsing_requests (
  request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kitchen_id UUID NOT NULL REFERENCES public.kitchen(kitchen_id) ON DELETE CASCADE,
  client_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  gcs_file_paths TEXT[] NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  enqueued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  error_message TEXT,
  result_recipe_ids TEXT[],
  retry_count INT NOT NULL DEFAULT 0,
  max_retries INT NOT NULL DEFAULT 3,
  CONSTRAINT valid_status CHECK (status IN ('queued', 'processing', 'completed', 'failed'))
);

CREATE INDEX idx_parsing_requests_kitchen_status ON public.parsing_requests(kitchen_id, status);
CREATE INDEX idx_parsing_requests_client ON public.parsing_requests(client_id);
CREATE INDEX idx_parsing_requests_status_enqueued ON public.parsing_requests(status, enqueued_at);

ALTER TABLE public.parsing_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own parsing requests"
  ON public.parsing_requests FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own parsing requests"
  ON public.parsing_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can manage all parsing requests"
  ON public.parsing_requests FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');

-- 4. RPC: Enqueue parse request
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
  INSERT INTO public.parsing_requests (kitchen_id, client_id, user_id, gcs_file_paths, status)
  VALUES (p_kitchen_id, p_client_id, auth.uid(), p_gcs_files, 'queued')
  RETURNING request_id INTO v_request_id;
  
  v_queue_name := CONCAT('kitchen_parse_', p_kitchen_id::text);
  PERFORM pgmq.send(
    v_queue_name,
    jsonb_build_object(
      'request_id', v_request_id,
      'client_id', p_client_id,
      'gcs_files', p_gcs_files
    )
  );
  
  RETURN v_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: Dequeue parse request (with visibility timeout)
-- ============================================================================
CREATE OR REPLACE FUNCTION dequeue_parse_request(
  p_kitchen_id UUID,
  p_vt_seconds INT DEFAULT 300
)
RETURNS TABLE (
  msg_id BIGINT,
  request_id UUID,
  client_id TEXT,
  gcs_files TEXT[]
) AS $$
DECLARE
  v_queue_name TEXT;
  v_message RECORD;
BEGIN
  v_queue_name := CONCAT('kitchen_parse_', p_kitchen_id::text);
  
  SELECT * INTO v_message
  FROM pgmq.read(v_queue_name, p_vt_seconds, 1)
  LIMIT 1;
  
  IF v_message.msg_id IS NOT NULL THEN
    RETURN QUERY SELECT
      v_message.msg_id,
      (v_message.message->>'request_id')::UUID,
      v_message.message->>'client_id',
      ARRAY(SELECT jsonb_array_elements_text(v_message.message->'gcs_files'));
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: Complete parse request
-- ============================================================================
CREATE OR REPLACE FUNCTION complete_parse_request(
  p_kitchen_id UUID,
  p_msg_id BIGINT,
  p_request_id UUID,
  p_recipe_ids TEXT[]
)
RETURNS VOID AS $$
DECLARE
  v_queue_name TEXT;
BEGIN
  v_queue_name := CONCAT('kitchen_parse_', p_kitchen_id::text);
  PERFORM pgmq.delete(v_queue_name, p_msg_id);
  
  UPDATE public.parsing_requests
  SET 
    status = 'completed',
    completed_at = NOW(),
    result_recipe_ids = p_recipe_ids
  WHERE request_id = p_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: Fail parse request (with DLQ and retry)
-- ============================================================================
CREATE OR REPLACE FUNCTION fail_parse_request(
  p_kitchen_id UUID,
  p_msg_id BIGINT,
  p_request_id UUID,
  p_error_message TEXT
)
RETURNS VOID AS $$
DECLARE
  v_queue_name TEXT;
  v_request RECORD;
BEGIN
  v_queue_name := CONCAT('kitchen_parse_', p_kitchen_id::text);
  
  SELECT * INTO v_request
  FROM public.parsing_requests
  WHERE request_id = p_request_id;
  
  IF v_request.retry_count < v_request.max_retries THEN
    UPDATE public.parsing_requests
    SET retry_count = retry_count + 1
    WHERE request_id = p_request_id;
  ELSE
    PERFORM pgmq.delete(v_queue_name, p_msg_id);
    
    PERFORM pgmq.send(
      'parse_dlq',
      jsonb_build_object(
        'request_id', p_request_id,
        'kitchen_id', p_kitchen_id,
        'client_id', v_request.client_id,
        'gcs_files', v_request.gcs_file_paths,
        'error', p_error_message,
        'failed_at', NOW()
      )
    );
    
    UPDATE public.parsing_requests
    SET 
      status = 'failed',
      completed_at = NOW(),
      error_message = p_error_message
    WHERE request_id = p_request_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RPC: Check if kitchen has active parsing
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
  
  IF EXISTS (
    SELECT 1 FROM public.parsing_requests
    WHERE kitchen_id = p_kitchen_id
    AND status IN ('queued', 'processing')
  ) THEN
    RETURN TRUE;
  END IF;
  
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Function: Cleanup old parsing requests (run daily)
-- ============================================================================
CREATE OR REPLACE FUNCTION cleanup_old_parsing_requests()
RETURNS INT AS $$
DECLARE
  v_deleted INT;
BEGIN
  DELETE FROM public.parsing_requests
  WHERE status IN ('completed', 'failed')
  AND completed_at < NOW() - INTERVAL '7 days';
  
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
    SELECT jobid FROM cron.job WHERE jobname = 'cleanup-parsing-requests'
  LOOP
    PERFORM cron.unschedule(v_job_id);
  END LOOP;

  -- Schedule at 02:00 daily
  PERFORM cron.schedule(
    'cleanup-parsing-requests',
    '0 2 * * *',
    $sql$SELECT public.cleanup_old_parsing_requests()$sql$
  );
END;
$$;
