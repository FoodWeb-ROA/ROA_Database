-- Revert existence check workaround now that cleanup trigger is deferred
--
-- With the cleanup trigger now DEFERRED (runs at transaction end),
-- we can move the existence validation back to BEFORE the DELETE operation
-- where it logically belongs. This provides better error messages and
-- fails fast if invalid component_ids are provided.

-- Fix upsert_preparation_components - move validation back before DELETE
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
  -- Defer component cleanup until transaction end to avoid race conditions
  PERFORM public.set_component_cleanup_deferred(true);

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

  -- Validate component_ids BEFORE delete (safe now that cleanup is deferred)
  IF v_component_ids IS NOT NULL AND array_length(v_component_ids, 1) > 0 THEN
    -- Existence check: all provided component_ids must exist
    SELECT array_agg(id)
    INTO v_missing
    FROM unnest(v_component_ids) AS id
    WHERE NOT EXISTS (SELECT 1 FROM public.components c WHERE c.component_id = id);
    IF v_missing IS NOT NULL AND array_length(v_missing, 1) > 0 THEN
      RAISE EXCEPTION 'Some components in payload do not exist: %', v_missing;
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

  -- Delete existing children (cleanup trigger is now deferred)
  DELETE FROM public.recipe_components rc WHERE rc.recipe_id = _prep_recipe_id;

  -- Insert new rows (safe from race condition due to deferred cleanup)
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

  -- Process any deferred component cleanup at transaction end
  PERFORM public.process_deferred_component_cleanup();

  RETURN;
END;
$$;

COMMENT ON FUNCTION public.upsert_preparation_components(uuid, uuid, jsonb) IS
'Atomically replaces a preparation''s recipe_components with validated items in one transaction. Defers cleanup until transaction end to avoid race conditions.';

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
  -- Defer component cleanup until transaction end to avoid race conditions
  PERFORM public.set_component_cleanup_deferred(true);

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

  -- Validate component_ids BEFORE delete (safe now that cleanup is deferred)
  IF v_component_ids IS NOT NULL AND array_length(v_component_ids, 1) > 0 THEN
    -- Existence check
    SELECT array_agg(id)
    INTO v_missing
    FROM unnest(v_component_ids) AS id
    WHERE NOT EXISTS (SELECT 1 FROM public.components c WHERE c.component_id = id);
    IF v_missing IS NOT NULL AND array_length(v_missing, 1) > 0 THEN
      RAISE EXCEPTION 'Some components in payload do not exist: %', v_missing;
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

  -- Delete existing children (cleanup trigger is now deferred)
  DELETE FROM public.recipe_components WHERE recipe_id = _recipe_id;

  -- Insert new rows (safe from race condition due to deferred cleanup)
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

  -- Process any deferred component cleanup at transaction end
  PERFORM public.process_deferred_component_cleanup();

  RETURN;
END;
$$;

COMMENT ON FUNCTION public.replace_recipe_components(uuid, uuid, jsonb) IS
'Atomically replaces a recipe''s components in one transaction with access checks. Defers cleanup until transaction end to avoid race conditions.';

-- Grant permissions
GRANT ALL ON FUNCTION public.upsert_preparation_components(uuid, uuid, jsonb) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.replace_recipe_components(uuid, uuid, jsonb) TO anon, authenticated, service_role;
