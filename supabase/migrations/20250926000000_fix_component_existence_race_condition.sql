-- Fix race condition in component existence checks
-- 
-- Problem: The component existence validation happens BEFORE the DELETE operation,
-- but the cleanup trigger runs immediately after DELETE and can delete components
-- that were validated as existing. This creates a TOCTTOU race condition where:
-- 1. Existence check passes ✅
-- 2. DELETE triggers component cleanup 
-- 3. Components get deleted by cleanup trigger
-- 4. INSERT fails with FK violation ❌
--
-- Solution: Move existence validation to AFTER the DELETE operation.

-- Fix upsert_preparation_components
CREATE OR REPLACE FUNCTION public.upsert_preparation_components(
  _prep_recipe_id uuid,
  _kitchen_id uuid,
  _items jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_recipe_kitchen uuid;
  v_component_ids uuid[];
  v_missing uuid[];
BEGIN
  -- Lock the prep recipe row to serialize concurrent updates
  PERFORM 1 FROM public.recipes r WHERE r.recipe_id = _prep_recipe_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Preparation recipe % not found', _prep_recipe_id;
  END IF;

  SELECT kitchen_id INTO v_recipe_kitchen FROM public.recipes WHERE recipe_id = _prep_recipe_id;
  IF v_recipe_kitchen IS DISTINCT FROM _kitchen_id THEN
    RAISE EXCEPTION 'Kitchen mismatch for preparation %', _prep_recipe_id;
  END IF;

  -- Collect component_ids for validation
  SELECT array_agg((x->>'component_id')::uuid)
  INTO v_component_ids
  FROM jsonb_array_elements(_items) AS x
  WHERE (x ? 'component_id') AND length(coalesce(x->>'component_id','')) > 0;

  -- CRITICAL: Delete existing children FIRST (this may trigger component cleanup)
  DELETE FROM public.recipe_components rc WHERE rc.recipe_id = _prep_recipe_id;

  -- THEN validate component_ids still exist (after potential cleanup)
  IF v_component_ids IS NOT NULL AND array_length(v_component_ids, 1) > 0 THEN
    -- Existence check: all provided component_ids must exist
    SELECT array_agg(id)
    INTO v_missing
    FROM unnest(v_component_ids) AS id
    WHERE NOT EXISTS (SELECT 1 FROM public.components c WHERE c.component_id = id);
    IF v_missing IS NOT NULL AND array_length(v_missing, 1) > 0 THEN
      RAISE EXCEPTION 'Some components in payload do not exist (may have been cleaned up): %', v_missing;
    END IF;

    -- Access check: all components must belong to same kitchen (via components table)
    IF EXISTS (
      SELECT 1 FROM public.components c
      WHERE c.component_id = ANY(v_component_ids)
        AND c.kitchen_id IS DISTINCT FROM _kitchen_id
    ) THEN
      RAISE EXCEPTION 'Some nested components are not accessible in this kitchen';
    END IF;
  END IF;

  -- Insert new rows (now safe from race condition)
  INSERT INTO public.recipe_components (recipe_id, component_id, amount, unit, item)
  SELECT
    _prep_recipe_id,
    (x->>'component_id')::uuid,
    COALESCE(NULLIF(x->>'amount','')::numeric, 0),
    (x->>'unit')::public.unit,
    CASE WHEN (x->>'unit') = 'x' THEN NULLIF(x->>'item','') ELSE NULL END
  FROM jsonb_array_elements(_items) AS x
  WHERE (x ? 'component_id')
    AND length(coalesce(x->>'component_id','')) > 0
    AND (x ? 'amount')
    AND (x ? 'unit');

  RETURN;
END;
$$;

COMMENT ON FUNCTION public.upsert_preparation_components(uuid, uuid, jsonb) IS
'Atomically replaces a preparation''s recipe_components with validated items in one transaction. Validates existence AFTER delete to avoid race conditions with cleanup triggers.';

-- Fix replace_recipe_components with same pattern
CREATE OR REPLACE FUNCTION public.replace_recipe_components(
  _recipe_id uuid,
  _kitchen_id uuid,
  _items jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_recipe_kitchen uuid;
  v_component_ids uuid[];
  v_missing uuid[];
BEGIN
  -- Lock the recipe row
  PERFORM 1 FROM public.recipes r WHERE r.recipe_id = _recipe_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recipe % not found', _recipe_id; END IF;

  SELECT kitchen_id INTO v_recipe_kitchen FROM public.recipes WHERE recipe_id = _recipe_id;
  IF v_recipe_kitchen IS DISTINCT FROM _kitchen_id THEN RAISE EXCEPTION 'Kitchen mismatch for recipe %', _recipe_id; END IF;

  -- Collect component_ids for validation
  SELECT array_agg((x->>'component_id')::uuid)
  INTO v_component_ids
  FROM jsonb_array_elements(_items) AS x
  WHERE (x ? 'component_id') AND length(coalesce(x->>'component_id','')) > 0;

  -- CRITICAL: Delete existing children FIRST (this may trigger component cleanup)
  DELETE FROM public.recipe_components WHERE recipe_id = _recipe_id;

  -- THEN validate component_ids still exist (after potential cleanup)
  IF v_component_ids IS NOT NULL AND array_length(v_component_ids, 1) > 0 THEN
    -- Existence check
    SELECT array_agg(id)
    INTO v_missing
    FROM unnest(v_component_ids) AS id
    WHERE NOT EXISTS (SELECT 1 FROM public.components c WHERE c.component_id = id);
    IF v_missing IS NOT NULL AND array_length(v_missing, 1) > 0 THEN
      RAISE EXCEPTION 'Some components in payload do not exist (may have been cleaned up): %', v_missing;
    END IF;

    -- Access check
    IF EXISTS (
      SELECT 1 FROM public.components c
      WHERE c.component_id = ANY(v_component_ids)
        AND c.kitchen_id IS DISTINCT FROM _kitchen_id
    ) THEN
      RAISE EXCEPTION 'Some components are not accessible in this kitchen';
    END IF;
  END IF;

  -- Insert new rows (now safe from race condition)
  INSERT INTO public.recipe_components (recipe_id, component_id, amount, unit, item)
  SELECT
    _recipe_id,
    (x->>'component_id')::uuid,
    COALESCE(NULLIF(x->>'amount','')::numeric, 0),
    (x->>'unit')::public.unit,
    CASE WHEN (x->>'unit') = 'x' THEN NULLIF(x->>'item','') ELSE NULL END
  FROM jsonb_array_elements(_items) AS x
  WHERE (x ? 'component_id')
    AND length(coalesce(x->>'component_id','')) > 0
    AND (x ? 'amount')
    AND (x ? 'unit');

  RETURN;
END;
$$;

COMMENT ON FUNCTION public.replace_recipe_components(uuid, uuid, jsonb) IS
'Atomically replaces a recipe''s components in one transaction with access checks. Validates existence AFTER delete to avoid race conditions with cleanup triggers.';

-- Grant permissions
GRANT ALL ON FUNCTION public.upsert_preparation_components(uuid, uuid, jsonb) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.replace_recipe_components(uuid, uuid, jsonb) TO anon, authenticated, service_role;
