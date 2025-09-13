-- Add fingerprint columns to recipes table for preparation fingerprinting
-- Idempotent: use IF NOT EXISTS
-- Security: none (DDL)

BEGIN;

ALTER TABLE IF EXISTS public.recipes
    ADD COLUMN IF NOT EXISTS fingerprint uuid,
    ADD COLUMN IF NOT EXISTS fingerprint_plain text;

-- Optional GIN trigram index for fingerprint_plain for similarity search
-- Ensure any previous index with incorrect opclass path is removed
DROP INDEX IF EXISTS idx_recipes_fingerprint_plain_trgm;
CREATE INDEX IF NOT EXISTS idx_recipes_fingerprint_plain_trgm
    ON public.recipes USING gin (fingerprint_plain extensions.gin_trgm_ops);

COMMIT;
