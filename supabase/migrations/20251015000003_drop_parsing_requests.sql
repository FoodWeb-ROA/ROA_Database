-- ============================================================================
-- Drop parsing_requests Table
-- ============================================================================
-- This table was used for lifecycle tracking (queued -> processing -> completed)
-- but is no longer needed with the simplified PGMQ + results table approach.
-- ============================================================================

-- Drop the table and all dependent objects
DROP TABLE IF EXISTS public.parsing_requests CASCADE;

-- Drop associated functions if they exist
DROP FUNCTION IF EXISTS fail_parse_request(UUID, BIGINT, UUID, TEXT) CASCADE;

COMMENT ON SCHEMA public IS 'Simplified parsing: PGMQ for work distribution, parsing_results for delivery only.';
