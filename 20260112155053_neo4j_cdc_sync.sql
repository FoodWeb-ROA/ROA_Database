-- ============================================================
-- Neo4j CDC Sync Setup
-- Enables CDC sync: Neo4j → Supabase (metadata cache)
-- ============================================================

-- Enable pg_jsonschema extension for JSONB validation
CREATE EXTENSION IF NOT EXISTS pg_jsonschema WITH SCHEMA extensions;

-- ============================================================
-- 0. Enums and Types
-- ============================================================

-- Storage type for ingredients (where they're stored)
CREATE TYPE public.StorageType AS ENUM ('Dry', 'Fresh', 'Prep');

COMMENT ON TYPE public.StorageType IS 'Storage location type for ingredients: Dry (pantry), Fresh (fridge/freezer), Prep (prepared items)';

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
-- 3. Component Schema Extensions
-- ============================================================

-- Add Neo4j linkage and metadata columns to components
ALTER TABLE public.components
  ADD COLUMN IF NOT EXISTS neo4j_ingredient_id text,
  ADD COLUMN IF NOT EXISTS metadata jsonb,
  ADD COLUMN IF NOT EXISTS metadata_last_synced_at timestamptz,
  ADD COLUMN IF NOT EXISTS shelf_life interval;

CREATE INDEX IF NOT EXISTS idx_components_neo4j_id
  ON public.components(neo4j_ingredient_id)
  WHERE neo4j_ingredient_id IS NOT NULL;

COMMENT ON COLUMN public.components.neo4j_ingredient_id IS 'Links to Neo4j ENTRY node canonical_id (e.g., "en:soya-lecithin"). Required for Raw_Ingredient, NULL for Preparation.';
COMMENT ON COLUMN public.components.metadata IS 'READ-ONLY cached metadata from Neo4j (for Raw_Ingredient) or user-editable prep metadata (for Preparation). Schema: {storage_type: StorageType, food_class?: string, modifiers?: {processing?: string[], part?: string[]}}. Modifiers describe the specific item (e.g., boneless breast, diced).';
COMMENT ON COLUMN public.components.metadata_last_synced_at IS 'Last time metadata was synced from Neo4j CDC (only for Raw_Ingredient with neo4j_ingredient_id)';
COMMENT ON COLUMN public.components.shelf_life IS 'How long this ingredient/prep lasts in storage';

-- Constraint: Raw_Ingredient must have neo4j_ingredient_id
ALTER TABLE public.components
  ADD CONSTRAINT components_raw_requires_neo4j_id 
  CHECK (
    (component_type = 'Preparation') OR 
    (component_type = 'Raw_Ingredient' AND neo4j_ingredient_id IS NOT NULL)
  );

-- Constraint: Preparations must have metadata (user-editable)
ALTER TABLE public.components
  ADD CONSTRAINT components_prep_requires_metadata 
  CHECK (
    (component_type = 'Raw_Ingredient') OR 
    (component_type = 'Preparation' AND metadata IS NOT NULL)
  );

COMMENT ON CONSTRAINT components_raw_requires_neo4j_id ON public.components IS 'Raw ingredients must link to Neo4j taxonomy';
COMMENT ON CONSTRAINT components_prep_requires_metadata ON public.components IS 'Preparations must have metadata (storage_type, food_class)';

-- ============================================================
-- 3a. Components Metadata JSONB Schema
-- ============================================================

-- JSON Schema for component metadata validation
CREATE OR REPLACE FUNCTION public.validate_component_metadata(metadata jsonb)
RETURNS boolean AS $$
DECLARE
  schema jsonb := '{
    "type": "object",
    "properties": {
      "storage_type": {
        "type": "string",
        "enum": ["Dry", "Fresh", "Prep"]
      },
      "food_class": {
        "type": "string",
        "description": "High-level food category: Meat, Flour, Base, Spices, etc."
      },
      "modifiers": {
        "type": "object",
        "properties": {
          "processing": {
            "type": "array",
            "items": {"type": "string"},
            "description": "Processing methods: boneless, skinless, diced, minced, etc."
          },
          "part": {
            "type": "array",
            "items": {"type": "string"},
            "description": "Ingredient parts: breast, thigh, yolk, etc."
          }
        },
        "additionalProperties": false
      }
    },
    "required": ["storage_type"],
    "additionalProperties": true
  }'::jsonb;
BEGIN
  RETURN extensions.json_matches_schema(schema, metadata);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.validate_component_metadata IS 'Validates component metadata against schema. Required: storage_type. Optional: food_class, modifiers (processing, part).';

-- Add CHECK constraint for metadata validation
ALTER TABLE public.components
  ADD CONSTRAINT components_metadata_schema_valid 
  CHECK (
    metadata IS NULL OR 
    public.validate_component_metadata(metadata)
  );



-- ============================================================
-- 3b. Recipe Component Modifiers Column
-- ============================================================

-- Add modifiers column to recipe_components for per-ingredient usage qualifiers
ALTER TABLE public.recipe_components
  ADD COLUMN IF NOT EXISTS modifiers jsonb;

COMMENT ON COLUMN public.recipe_components.modifiers IS 'Per-ingredient modifiers describing how this specific component is used in the recipe (e.g., {"processing": ["diced"], "part": ["breast"]}). Different from component.metadata.modifiers which describes the inventory item.';

-- JSON Schema for recipe component modifiers validation
CREATE OR REPLACE FUNCTION public.validate_recipe_component_modifiers(modifiers jsonb)
RETURNS boolean AS $$
DECLARE
  schema jsonb := '{
    "type": "object",
    "properties": {
      "processing": {
        "type": "array",
        "items": {"type": "string"},
        "description": "Processing methods: dry, diced, minced, etc."
      },
      "part": {
        "type": "array",
        "items": {"type": "string"},
        "description": "Ingredient parts: head, breast, thigh, yolk, etc."
      }
    },
    "additionalProperties": false
  }'::jsonb;
BEGIN
  RETURN extensions.json_matches_schema(schema, modifiers);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.validate_recipe_component_modifiers IS 'Validates recipe_components.modifiers JSON structure. Describes how ingredient is used in recipe.';

-- Add CHECK constraint for modifiers validation
ALTER TABLE public.recipe_components
  ADD CONSTRAINT recipe_components_modifiers_schema_valid 
  CHECK (
    modifiers IS NULL OR 
    public.validate_recipe_component_modifiers(modifiers)
  );


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


-- ============================================================
-- 5. RPC Function for Dynamic Schema Updates
-- Allows Pydantic schemas to update validation functions at runtime
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_validation_function(
  p_function_name text,
  p_json_schema jsonb,
  p_description text DEFAULT NULL
)
RETURNS void AS $$
DECLARE
  v_schema_escaped text;
  v_sql text;
BEGIN
  -- Escape single quotes in JSON schema
  v_schema_escaped := replace(p_json_schema::text, '''', '''''');
  
  -- Build dynamic SQL for validation function
  v_sql := format(
    $func$
    CREATE OR REPLACE FUNCTION public.%I(data jsonb)
    RETURNS boolean AS $body$
    DECLARE
      schema jsonb := '%s'::jsonb;
    BEGIN
      RETURN extensions.json_matches_schema(schema, data);
    END;
    $body$ LANGUAGE plpgsql IMMUTABLE;
    $func$,
    p_function_name,
    v_schema_escaped
  );
  
  -- Execute the dynamic SQL
  EXECUTE v_sql;
  
  -- Add comment if provided
  IF p_description IS NOT NULL THEN
    EXECUTE format(
      'COMMENT ON FUNCTION public.%I(jsonb) IS %L',
      p_function_name,
      p_description
    );
  END IF;
  
  RAISE NOTICE 'Updated validation function: %', p_function_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.update_validation_function IS 'RPC function to dynamically update JSONB validation functions from Pydantic schemas. Called by ROA_FoodWeb GitHub workflow.';
