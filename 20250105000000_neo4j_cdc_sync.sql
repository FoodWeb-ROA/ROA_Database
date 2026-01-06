-- ============================================================
-- Neo4j CDC Bidirectional Sync Setup
-- Enables direct CDC sync: Neo4j → Supabase (cache) and Supabase → Neo4j (occurrences)
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
-- 4. Ingredient Occurrence Sync Queue
-- Tracks when components should be synced to Neo4j as IngredientOccurrence nodes
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ingredient_occurrence_sync_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  component_id uuid NOT NULL REFERENCES public.components(component_id) ON DELETE CASCADE,
  kitchen_id uuid NOT NULL REFERENCES public.kitchen(kitchen_id) ON DELETE CASCADE,
  operation text NOT NULL CHECK (operation IN ('create', 'update', 'delete')),
  queued_at timestamptz DEFAULT now() NOT NULL,
  processed_at timestamptz,
  retry_count int DEFAULT 0 NOT NULL,
  last_error text,
  neo4j_occurrence_id text
);

CREATE INDEX IF NOT EXISTS idx_occurrence_sync_pending
  ON public.ingredient_occurrence_sync_queue(queued_at)
  WHERE processed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_occurrence_sync_component
  ON public.ingredient_occurrence_sync_queue(component_id);

COMMENT ON TABLE public.ingredient_occurrence_sync_queue IS 'Queue for syncing Supabase components to Neo4j as IngredientOccurrence nodes';


-- ============================================================
-- 5. Trigger: Auto-queue occurrences when components are created/updated
-- Only queue Raw_Ingredient components that reference global taxonomy
-- ============================================================
CREATE OR REPLACE FUNCTION public.queue_ingredient_occurrence_sync()
RETURNS TRIGGER AS $$
BEGIN
  -- Only sync Raw_Ingredient components linked to Neo4j taxonomy
  IF NEW.component_type = 'Raw_Ingredient' AND NEW.neo4j_ingredient_id IS NOT NULL THEN
    INSERT INTO public.ingredient_occurrence_sync_queue (
      component_id,
      kitchen_id,
      operation,
      queued_at
    ) VALUES (
      NEW.component_id,
      NEW.kitchen_id,
      CASE 
        WHEN TG_OP = 'INSERT' THEN 'create'
        WHEN TG_OP = 'UPDATE' THEN 'update'
      END,
      now()
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_queue_occurrence_sync ON public.components;
CREATE TRIGGER trigger_queue_occurrence_sync
  AFTER INSERT OR UPDATE ON public.components
  FOR EACH ROW
  EXECUTE FUNCTION public.queue_ingredient_occurrence_sync();


-- ============================================================
-- 6. Trigger: Queue deletion sync
-- ============================================================
CREATE OR REPLACE FUNCTION public.queue_ingredient_occurrence_delete()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.component_type = 'Raw_Ingredient' AND OLD.neo4j_ingredient_id IS NOT NULL THEN
    INSERT INTO public.ingredient_occurrence_sync_queue (
      component_id,
      kitchen_id,
      operation,
      queued_at,
      neo4j_occurrence_id
    ) VALUES (
      OLD.component_id,
      OLD.kitchen_id,
      'delete',
      now(),
      OLD.component_id::text  -- Use component_id as lookup key
    );
  END IF;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_queue_occurrence_delete ON public.components;
CREATE TRIGGER trigger_queue_occurrence_delete
  BEFORE DELETE ON public.components
  FOR EACH ROW
  EXECUTE FUNCTION public.queue_ingredient_occurrence_delete();


-- ============================================================
-- 7. Helper Functions for Cloud Run Service
-- ============================================================

-- Mark sync item as processed
CREATE OR REPLACE FUNCTION public.mark_occurrence_sync_processed(
  p_sync_id uuid,
  p_neo4j_occurrence_id text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  UPDATE public.ingredient_occurrence_sync_queue
  SET processed_at = now(),
      neo4j_occurrence_id = COALESCE(p_neo4j_occurrence_id, neo4j_occurrence_id),
      last_error = NULL
  WHERE id = p_sync_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Mark sync item as failed
CREATE OR REPLACE FUNCTION public.mark_occurrence_sync_failed(
  p_sync_id uuid,
  p_error text
)
RETURNS void AS $$
BEGIN
  UPDATE public.ingredient_occurrence_sync_queue
  SET retry_count = retry_count + 1,
      last_error = p_error
  WHERE id = p_sync_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get pending sync items (for batch processing)
CREATE OR REPLACE FUNCTION public.get_pending_occurrence_syncs(
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  sync_id uuid,
  component_id uuid,
  component_name text,
  kitchen_id uuid,
  neo4j_ingredient_id text,
  operation text,
  queued_at timestamptz,
  retry_count int
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    q.id,
    q.component_id,
    c.name,
    q.kitchen_id,
    c.neo4j_ingredient_id,
    q.operation,
    q.queued_at,
    q.retry_count
  FROM public.ingredient_occurrence_sync_queue q
  JOIN public.components c ON c.component_id = q.component_id
  WHERE q.processed_at IS NULL
    AND q.retry_count < 5  -- Max 5 retries
  ORDER BY q.queued_at ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================
-- 8. RLS Policies (Service Role Only)
-- These tables are managed by the CDC service, not directly by users
-- ============================================================

ALTER TABLE public.cdc_dedup ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cdc_cursors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredient_occurrence_sync_queue ENABLE ROW LEVEL SECURITY;

-- Service role has full access (policies will be bypassed)
-- No user-facing policies needed for sync infrastructure tables

COMMENT ON TABLE public.cdc_dedup IS 'Internal: CDC sync infrastructure (service role only)';
COMMENT ON TABLE public.cdc_cursors IS 'Internal: CDC sync infrastructure (service role only)';
COMMENT ON TABLE public.ingredient_occurrence_sync_queue IS 'Internal: CDC sync infrastructure (service role only)';
