-- Function to get all kitchen IDs that have active PGMQ parse requests
-- Used as fallback when realtime presence is unavailable (sync client)

CREATE OR REPLACE FUNCTION get_kitchens_with_active_parsing()
RETURNS TABLE(kitchen_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  queue_record RECORD;
  parsed_kitchen_id uuid;
BEGIN
  -- Iterate through all PGMQ queues matching kp_* pattern (kitchen parse queues)
  FOR queue_record IN 
    SELECT schemaname, tablename 
    FROM pg_tables 
    WHERE schemaname = 'pgmq' 
    AND tablename LIKE 'q_kp_%'
    AND tablename NOT LIKE '%_archive'
  LOOP
    -- Extract kitchen_id from queue name (format: q_kp_<uuid>)
    BEGIN
      parsed_kitchen_id := substring(queue_record.tablename from 'q_kp_(.+)')::uuid;
      
      -- Check if this queue has any messages
      EXECUTE format(
        'SELECT EXISTS(SELECT 1 FROM %I.%I LIMIT 1)',
        queue_record.schemaname,
        queue_record.tablename
      ) INTO FOUND;
      
      IF FOUND THEN
        kitchen_id := parsed_kitchen_id;
        RETURN NEXT;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      -- Skip invalid queue names
      CONTINUE;
    END;
  END LOOP;
  
  RETURN;
END;
$$;

-- Grant execute to authenticated users (they can only see their own kitchens via RLS elsewhere)
GRANT EXECUTE ON FUNCTION get_kitchens_with_active_parsing() TO authenticated;
GRANT EXECUTE ON FUNCTION get_kitchens_with_active_parsing() TO service_role;

COMMENT ON FUNCTION get_kitchens_with_active_parsing() IS 
'Returns list of kitchen IDs with active PGMQ parse requests. Used as fallback when realtime presence unavailable.';
