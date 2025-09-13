-- Add indexes to support Unicode-safe name exact and fuzzy matching
-- Safe to run multiple times (IF NOT EXISTS + partial indexes)

BEGIN;

-- Trigram GIN index for fuzzy similarity on ingredient names (Unicode-safe)
-- Matches queries using extensions.similarity(lower(trim(c.name)), lower(trim(q.name)))
CREATE INDEX IF NOT EXISTS idx_components_name_trgm_unicode
  ON public.components
  USING gin (lower(btrim(name)) extensions.gin_trgm_ops)
  WHERE component_type = 'Raw_Ingredient';

-- Composite btree index for exact name match per kitchen (Unicode-safe)
-- Matches lower(trim(c.name)) equality with kitchen_id
CREATE INDEX IF NOT EXISTS idx_components_kitchen_lowername
  ON public.components (kitchen_id, lower(btrim(name)))
  WHERE component_type = 'Raw_Ingredient';

COMMIT;


