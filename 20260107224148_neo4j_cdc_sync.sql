-- ============================================================
-- Neo4j CDC Sync Setup
-- Enables CDC sync: Neo4j → Supabase (metadata cache)
-- ============================================================

-- ============================================================
-- 1. CDC Deduplication Table
-- Tracks processed change_ids from Neo4j CDC to ensure idempotent writes
-- ============================================================
CREATE TABLE IF NOT EXISTS public.cdc_dedup (
  change_id text PRIMARY KEY,
  processed_at timestamptz DEFAULT now() NOT NULL,
  entity_type text,
  operation text
);



CREATE INDEX IF NOT EXISTS idx_cdc_dedup_processed_at 
  ON public.cdc_dedup(processed_at);

COMMENT ON TABLE public.cdc_dedup IS 'Tracks processed Neo4j CDC change_ids for idempotent cache updates';

-- Cleanup function: remove entries older than 30 days
CREATE OR REPLACE FUNCTION public.cleanup_cdc_dedup()
RETURNS void AS $$
BEGIN
  DELETE FROM public.cdc_dedup 
  WHERE processed_at < now() - interval '30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 2. CDC Cursor Storage
-- Stores the last processed CDC cursor for the poller
-- ============================================================
CREATE TABLE IF NOT EXISTS public.cdc_cursors (
  id text PRIMARY KEY DEFAULT 'neo4j_ingredients',
  cursor_value text NOT NULL,
  last_updated_at timestamptz DEFAULT now() NOT NULL,
  neo4j_db text
);

COMMENT ON TABLE public.cdc_cursors IS 'Stores Neo4j CDC cursor position for resumable polling';


-- ============================================================
-- 3. Component Linkage to Neo4j Taxonomy
-- Links Supabase components to global Neo4j ingredient taxonomy
-- ============================================================
ALTER TABLE public.components
  ADD COLUMN IF NOT EXISTS neo4j_ingredient_id text,
  ADD COLUMN IF NOT EXISTS is_global_ingredient boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS metadata_jsonb jsonb,
  ADD COLUMN IF NOT EXISTS metadata_last_synced_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_components_neo4j_id
  ON public.components(neo4j_ingredient_id)
  WHERE neo4j_ingredient_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_components_global_ingredients
  ON public.components(kitchen_id, is_global_ingredient)
  WHERE is_global_ingredient = true;

COMMENT ON COLUMN public.components.neo4j_ingredient_id IS 'Links to Neo4j ENTRY node canonical_id (e.g., "en:soya-lecithin")';
COMMENT ON COLUMN public.components.is_global_ingredient IS 'True if this component references global taxonomy, false if kitchen-specific custom ingredient';
COMMENT ON COLUMN public.components.metadata_jsonb IS 'Cached metadata from Neo4j taxonomy (names, allergens, etc.) for fast reads';
COMMENT ON COLUMN public.components.metadata_last_synced_at IS 'Last time metadata was synced from Neo4j CDC';



-- ============================================================
-- 4. RLS Policies (Service Role Only)
-- These tables are managed by the CDC service, not directly by users
-- ============================================================

ALTER TABLE public.cdc_dedup ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cdc_cursors ENABLE ROW LEVEL SECURITY;

-- Service role has full access (policies will be bypassed)
-- No user-facing policies needed for sync infrastructure tables

COMMENT ON TABLE public.cdc_dedup IS 'Internal: CDC sync infrastructure (service role only)';
COMMENT ON TABLE public.cdc_cursors IS 'Internal: CDC sync infrastructure (service role only)';
