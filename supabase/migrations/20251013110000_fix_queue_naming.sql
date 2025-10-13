-- ============================================================================
-- Fix Queue Naming: Use 'kp_' prefix instead of 'kitchen_parse_'
-- ============================================================================
-- PGMQ has 48-char limit. 'kitchen_parse_' + UUID = 50 chars (TOO LONG!)
-- Solution: Use 'kp_' prefix: 'kp_' + UUID = 39 chars (FITS!)
-- ============================================================================

-- 1. Update queue creation trigger
-- ============================================================================
CREATE OR REPLACE FUNCTION create_kitchen_parsing_queue()
RETURNS TRIGGER AS $$
DECLARE
  v_queue_name TEXT;
BEGIN
  -- Use 'kp_' prefix (3 chars + 36 UUID = 39 chars, within 48 limit)
  v_queue_name := CONCAT('kp_', NEW.kitchen_id::text);
  PERFORM pgmq.create(v_queue_name);
  PERFORM enable_queue_rls(v_queue_name);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update queue deletion trigger
-- ============================================================================
CREATE OR REPLACE FUNCTION delete_kitchen_parsing_queue()
RETURNS TRIGGER AS $$
DECLARE
  v_queue_name TEXT;
BEGIN
  v_queue_name := CONCAT('kp_', OLD.kitchen_id::text);
  PERFORM pgmq.drop_queue(v_queue_name);
  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  -- If queue doesn't exist or other error, don't block deletion
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update enqueue RPC
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
  v_request_id := gen_random_uuid();
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

-- 4. Update kitchen_has_active_parsing RPC
-- ============================================================================
CREATE OR REPLACE FUNCTION kitchen_has_active_parsing(p_kitchen_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_queue_name TEXT;
  v_metrics JSONB;
BEGIN
  v_queue_name := CONCAT('kp_', p_kitchen_id::text);
  
  BEGIN
    v_metrics := pgmq.metrics(v_queue_name);
    IF (v_metrics->>'queue_length')::int > 0 THEN
      RETURN TRUE;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
