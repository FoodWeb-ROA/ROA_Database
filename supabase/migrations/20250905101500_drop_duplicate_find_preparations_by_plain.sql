-- Drop duplicate legacy function signature without _threshold parameter
-- Idempotent and safe to run multiple times

BEGIN;

-- Remove the old two-argument version, keeping the newer three-argument variant
DROP FUNCTION IF EXISTS public.find_preparations_by_plain(text[], uuid);

COMMIT;


