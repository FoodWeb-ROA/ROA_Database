-- Migration: Unified save_recipe RPC
-- Consolidates recipe + recipe_components writes into a single atomic operation
-- Replaces fragmented flow: upsertRecipe() + replace_recipe_components()

-- ============================================================================
-- CREATE UNIFIED RPC: save_recipe
-- ============================================================================
-- Handles both INSERT (new recipe) and UPDATE (existing recipe) with components
-- For Preparations: creates/updates paired component automatically
-- Returns recipe_id and component_id (null for Dishes)

CREATE OR REPLACE FUNCTION public.save_recipe(
  _kitchen_id uuid,
  _recipe_id uuid,                    -- NULL for new recipe, UUID for update
  _recipe_data jsonb,                 -- Recipe metadata
  _components jsonb                   -- Array of {component_id, amount, unit, item}
) RETURNS TABLE(recipe_id uuid, component_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_recipe_id uuid;
  v_component_id uuid := NULL;
  v_recipe_name text;
  v_recipe_type public.recipe_type;
  v_category_id uuid;
  v_time interval;
  v_directions text[];
  v_cooking_notes text;
  v_serving_amount numeric;
  v_serving_unit public.unit;
  v_serving_item text;
  v_existing_type public.recipe_type;
  v_existing_component_id uuid;
  v_component_ids uuid[];
  v_missing uuid[];
BEGIN
  -- Extract recipe data from JSONB
  v_recipe_name := COALESCE(NULLIF(TRIM(_recipe_data->>'recipe_name'), ''), 'Untitled');
  v_recipe_type := COALESCE((_recipe_data->>'recipe_type')::public.recipe_type, 'Dish');
  v_category_id := NULLIF(_recipe_data->>'category_id', '')::uuid;
  v_time := COALESCE((_recipe_data->>'time')::interval, '00:30:00'::interval);
  v_directions := COALESCE(
    ARRAY(SELECT jsonb_array_elements_text(_recipe_data->'directions')),
    ARRAY[]::text[]
  );
  v_cooking_notes := NULLIF(_recipe_data->>'cooking_notes', '');
  v_serving_amount := COALESCE((_recipe_data->>'serving_or_yield_amount')::numeric, 1);
  v_serving_unit := COALESCE((_recipe_data->>'serving_or_yield_unit')::public.unit, 'x');
  v_serving_item := CASE 
    WHEN v_serving_unit = 'x' THEN NULLIF(_recipe_data->>'serving_item', '')
    ELSE NULL
  END;

  -- ========================================
  -- UPSERT RECIPE
  -- ========================================
  IF _recipe_id IS NOT NULL THEN
    -- UPDATE existing recipe
    -- First lock and verify ownership
    SELECT r.recipe_type INTO v_existing_type
    FROM public.recipes r
    WHERE r.recipe_id = _recipe_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Recipe % not found', _recipe_id;
    END IF;
    
    -- Verify kitchen ownership (RLS backup)
    IF NOT EXISTS (
      SELECT 1 FROM public.recipes r 
      WHERE r.recipe_id = _recipe_id AND r.kitchen_id = _kitchen_id
    ) THEN
      RAISE EXCEPTION 'Recipe % not accessible in kitchen %', _recipe_id, _kitchen_id;
    END IF;
    
    UPDATE public.recipes SET
      recipe_name = v_recipe_name,
      recipe_type = v_recipe_type,
      category_id = v_category_id,
      "time" = v_time,
      directions = v_directions,
      cooking_notes = v_cooking_notes,
      serving_or_yield_amount = v_serving_amount,
      serving_or_yield_unit = v_serving_unit,
      serving_item = v_serving_item
    WHERE recipes.recipe_id = _recipe_id;
    
    v_recipe_id := _recipe_id;
    
    -- Handle type change: Dish -> Preparation needs component creation
    IF v_existing_type = 'Dish' AND v_recipe_type = 'Preparation' THEN
      INSERT INTO public.components (name, component_type, kitchen_id, recipe_id)
      VALUES (v_recipe_name, 'Preparation', _kitchen_id, v_recipe_id)
      RETURNING components.component_id INTO v_component_id;
    ELSIF v_recipe_type = 'Preparation' THEN
      -- Find existing paired component
      SELECT c.component_id INTO v_existing_component_id
      FROM public.components c
      WHERE c.recipe_id = v_recipe_id;
      
      IF FOUND THEN
        -- Update component name to match recipe
        UPDATE public.components SET name = v_recipe_name
        WHERE component_id = v_existing_component_id;
        v_component_id := v_existing_component_id;
      ELSE
        -- Create missing paired component
        INSERT INTO public.components (name, component_type, kitchen_id, recipe_id)
        VALUES (v_recipe_name, 'Preparation', _kitchen_id, v_recipe_id)
        RETURNING components.component_id INTO v_component_id;
      END IF;
    END IF;
    
    -- Handle type change: Preparation -> Dish removes component
    IF v_existing_type = 'Preparation' AND v_recipe_type = 'Dish' THEN
      DELETE FROM public.components WHERE recipe_id = v_recipe_id;
      v_component_id := NULL;
    END IF;
    
  ELSE
    -- INSERT new recipe
    INSERT INTO public.recipes (
      recipe_name, recipe_type, category_id, "time", directions,
      cooking_notes, serving_or_yield_amount, serving_or_yield_unit,
      serving_item, kitchen_id
    ) VALUES (
      v_recipe_name, v_recipe_type, v_category_id, v_time, v_directions,
      v_cooking_notes, v_serving_amount, v_serving_unit,
      v_serving_item, _kitchen_id
    )
    ON CONFLICT (recipe_name, kitchen_id) DO UPDATE SET
      recipe_type = EXCLUDED.recipe_type,
      category_id = EXCLUDED.category_id,
      "time" = EXCLUDED."time",
      directions = EXCLUDED.directions,
      cooking_notes = EXCLUDED.cooking_notes,
      serving_or_yield_amount = EXCLUDED.serving_or_yield_amount,
      serving_or_yield_unit = EXCLUDED.serving_or_yield_unit,
      serving_item = EXCLUDED.serving_item
    RETURNING recipes.recipe_id INTO v_recipe_id;
    
    -- For Preparations, create or update paired component
    IF v_recipe_type = 'Preparation' THEN
      SELECT c.component_id INTO v_existing_component_id
      FROM public.components c
      WHERE c.recipe_id = v_recipe_id;
      
      IF NOT FOUND THEN
        INSERT INTO public.components (name, component_type, kitchen_id, recipe_id)
        VALUES (v_recipe_name, 'Preparation', _kitchen_id, v_recipe_id)
        RETURNING components.component_id INTO v_component_id;
      ELSE
        UPDATE public.components SET name = v_recipe_name
        WHERE component_id = v_existing_component_id;
        v_component_id := v_existing_component_id;
      END IF;
    END IF;
  END IF;

  -- ========================================
  -- REPLACE COMPONENTS (DELETE + INSERT pattern)
  -- ========================================
  IF _components IS NOT NULL AND jsonb_array_length(_components) > 0 THEN
    -- Collect component_ids for validation
    SELECT array_agg((x->>'component_id')::uuid)
    INTO v_component_ids
    FROM jsonb_array_elements(_components) AS x
    WHERE (x ? 'component_id') AND length(COALESCE(x->>'component_id', '')) > 0;

    -- Validate component_ids exist and belong to correct kitchen
    IF v_component_ids IS NOT NULL AND array_length(v_component_ids, 1) > 0 THEN
      SELECT array_agg(id)
      INTO v_missing
      FROM unnest(v_component_ids) AS id
      WHERE NOT EXISTS (SELECT 1 FROM public.components c WHERE c.component_id = id);
      
      IF v_missing IS NOT NULL AND array_length(v_missing, 1) > 0 THEN
        RAISE EXCEPTION 'Components do not exist: %', v_missing;
      END IF;

      IF EXISTS (
        SELECT 1 FROM public.components c
        WHERE c.component_id = ANY(v_component_ids)
          AND c.kitchen_id IS DISTINCT FROM _kitchen_id
      ) THEN
        RAISE EXCEPTION 'Some components are not accessible in this kitchen';
      END IF;
    END IF;

    -- Delete existing and insert new
    DELETE FROM public.recipe_components WHERE recipe_components.recipe_id = v_recipe_id;

    INSERT INTO public.recipe_components (recipe_id, component_id, amount, unit, item)
    SELECT
      v_recipe_id,
      (x->>'component_id')::uuid,
      COALESCE(NULLIF(x->>'amount', '')::numeric, 0),
      (x->>'unit')::public.unit,
      CASE WHEN (x->>'unit') = 'x' THEN NULLIF(x->>'item', '') ELSE NULL END
    FROM jsonb_array_elements(_components) AS x
    WHERE (x ? 'component_id')
      AND length(COALESCE(x->>'component_id', '')) > 0
      AND (x ? 'amount')
      AND (x ? 'unit');
  ELSE
    -- Empty components: clear all
    DELETE FROM public.recipe_components WHERE recipe_components.recipe_id = v_recipe_id;
  END IF;

  RETURN QUERY SELECT v_recipe_id AS recipe_id, v_component_id AS component_id;
END;
$$;

ALTER FUNCTION public.save_recipe(uuid, uuid, jsonb, jsonb) OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.save_recipe(uuid, uuid, jsonb, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.save_recipe(uuid, uuid, jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_recipe(uuid, uuid, jsonb, jsonb) TO service_role;

COMMENT ON FUNCTION public.save_recipe IS 
'Unified atomic recipe save: upserts recipe row, manages paired component for Preparations, 
and replaces all recipe_components in a single transaction.';

-- ============================================================================
-- DROP DEPRECATED FUNCTIONS
-- ============================================================================

DROP FUNCTION IF EXISTS public.replace_recipe_components(uuid, jsonb);
DROP FUNCTION IF EXISTS public.upsert_preparation_components(uuid, uuid, jsonb);
DROP FUNCTION IF EXISTS public.create_preparation_with_component(uuid, text, public.recipe_type, uuid, interval, text[], text, numeric, public.unit, text);
DROP FUNCTION IF EXISTS public.overwrite_preparation_with_components(uuid, uuid, text, public.recipe_type, uuid, interval, text[], text, numeric, public.unit, text, jsonb);
