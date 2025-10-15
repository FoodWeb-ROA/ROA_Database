-- ============================================================================
-- Update enqueue_parse_request Function
-- ============================================================================
-- Simplify the enqueue function to remove client_id (not needed) and use
-- pgmq.send() directly instead of via wrapper.
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
  
  -- Construct queue name (shortened to kp_ due to PGMQ 48-char limit)
  v_queue_name := CONCAT('kp_', p_kitchen_id::text);
  
  -- Send directly to PGMQ queue
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

COMMENT ON FUNCTION enqueue_parse_request IS 'Enqueues a parse request to the kitchen-specific PGMQ queue. Returns request_id for tracking.';
