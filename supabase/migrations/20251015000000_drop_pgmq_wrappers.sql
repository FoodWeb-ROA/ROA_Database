-- ============================================================================
-- Drop Custom PGMQ Wrapper Functions
-- ============================================================================
-- These wrapper functions are no longer needed. Backend will use pgmq.send()
-- directly via service role, and pgmq.read/delete/archive are only called
-- by service role (backend workers).
-- ============================================================================

-- Drop the wrapper functions
DROP FUNCTION IF EXISTS public.pgmq_read(TEXT, INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS public.pgmq_delete(TEXT, BIGINT) CASCADE;
DROP FUNCTION IF EXISTS public.pgmq_archive(TEXT, BIGINT) CASCADE;

-- Note: Backend will now use native PGMQ functions directly:
-- - pgmq.send(queue_name, message) - for enqueueing
-- - pgmq.read(queue_name, vt, qty) - service role only
-- - pgmq.delete(queue_name, msg_id) - service role only
-- - pgmq.archive(queue_name, msg_id) - service role only
