-- ============================================================================
-- Expose PGMQ functions to PostgREST API
-- ============================================================================
-- PostgREST requires explicit grants for functions to be accessible via RPC.
-- This migration grants necessary permissions for PGMQ operations.
-- ============================================================================

-- Grant execute permissions on PGMQ functions to authenticated users
GRANT EXECUTE ON FUNCTION pgmq.read(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION pgmq.delete(text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION pgmq.archive(text, bigint) TO authenticated;

-- Grant execute permissions to service role (for backend workers)
GRANT EXECUTE ON FUNCTION pgmq.read(text, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION pgmq.delete(text, bigint) TO service_role;
GRANT EXECUTE ON FUNCTION pgmq.archive(text, bigint) TO service_role;

-- Note: The function names in PostgREST RPC calls should be:
-- - pgmq_read (for pgmq.read)
-- - pgmq_delete (for pgmq.delete)
-- - pgmq_archive (for pgmq.archive)
-- PostgREST automatically maps schema.function to schema_function format.
