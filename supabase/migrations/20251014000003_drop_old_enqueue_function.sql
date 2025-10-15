-- ============================================================================
-- Drop old enqueue_parse_request function with client_id parameter
-- ============================================================================
-- PostgreSQL allows function overloading, so the old 3-parameter version
-- may still exist alongside the new 2-parameter version.
-- This migration explicitly drops the old signature.
-- ============================================================================

-- Drop the old function with client_id (3 parameters)
DROP FUNCTION IF EXISTS public.enqueue_parse_request(UUID, TEXT, TEXT[]);

-- Verify the correct function exists (2 parameters: kitchen_id, gcs_files)
-- This should already exist from migration 20251013110000
-- If it doesn't exist, this comment serves as documentation that it should be created

COMMENT ON FUNCTION public.enqueue_parse_request(UUID, TEXT[]) IS 
'Enqueues a parse request to the kitchen-specific PGMQ queue. Parameters: p_kitchen_id, p_gcs_files. Returns: request_id UUID.';
