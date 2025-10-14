-- ============================================================================
-- PGMQ Wrapper Functions with Named Parameters
-- ============================================================================
-- PostgREST passes named JSON parameters, not positional arguments.
-- The native pgmq functions have signature: pgmq.read(text, int, int)
-- which makes it impossible for PostgREST to determine parameter order.
-- 
-- These wrapper functions have explicit named parameters so PostgREST
-- can correctly map the JSON payload to function arguments.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.pgmq_read(
  queue_name TEXT,
  vt INTEGER,
  qty INTEGER
)
RETURNS SETOF pgmq.message_record
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT * FROM pgmq.read(queue_name, vt, qty);
$$;

CREATE OR REPLACE FUNCTION public.pgmq_delete(
  queue_name TEXT,
  msg_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT pgmq.delete(queue_name, msg_id);
$$;

CREATE OR REPLACE FUNCTION public.pgmq_archive(
  queue_name TEXT,
  msg_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT pgmq.archive(queue_name, msg_id);
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.pgmq_read(TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pgmq_read(TEXT, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.pgmq_delete(TEXT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pgmq_delete(TEXT, BIGINT) TO service_role;
GRANT EXECUTE ON FUNCTION public.pgmq_archive(TEXT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pgmq_archive(TEXT, BIGINT) TO service_role;

COMMENT ON FUNCTION public.pgmq_read IS 
'Wrapper for pgmq.read with named parameters for PostgREST RPC compatibility';
COMMENT ON FUNCTION public.pgmq_delete IS 
'Wrapper for pgmq.delete with named parameters for PostgREST RPC compatibility';
COMMENT ON FUNCTION public.pgmq_archive IS 
'Wrapper for pgmq.archive with named parameters for PostgREST RPC compatibility';
