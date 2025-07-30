-- Ensure uuid_generate_v5 wrapper is secured with empty search_path
-- Migration generated 2025-07-30

BEGIN;

-- Set search_path to empty string to satisfy security lint 0011_function_search_path_mutable
ALTER FUNCTION public.uuid_generate_v5(uuid, text)
    SET search_path TO '';

COMMIT;
