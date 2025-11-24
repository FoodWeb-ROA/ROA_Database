-- Transactional RPCs to eliminate client-side TOCTTOU races in RecipeSaveService

-- 1) upsert_preparation_components: atomically replace all children for a preparation
--    Validates kitchen access and unit/item guards, locks the prep recipe row,
--    deletes existing recipe_components, inserts new rows.

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

  -- Collect component_ids and validate kitchen access
  SELECT array_agg((x->>'component_id')::uuid)
  INTO v_component_ids
  FROM jsonb_array_elements(_items) AS x
  WHERE (x ? 'component_id') AND length(coalesce(x->>'component_id','')) > 0;

  IF v_component_ids IS NOT NULL AND array_length(v_component_ids, 1) > 0 THEN
    -- Access check: all components must belong to same kitchen (via components table)
    IF EXISTS (
      SELECT 1 FROM public.components c
      WHERE c.component_id = ANY(v_component_ids)
        AND c.kitchen_id IS DISTINCT FROM _kitchen_id
    ) THEN
      RAISE EXCEPTION 'Some nested components are not accessible in this kitchen';
    END IF;
  END IF;

  -- Delete existing children first
  DELETE FROM public.recipe_components rc WHERE rc.recipe_id = _prep_recipe_id;

  -- Insert new rows
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
'Atomically replaces a preparation''s recipe_components with validated items in one transaction.';

GRANT ALL ON FUNCTION public.upsert_preparation_components(uuid, uuid, jsonb) TO anon, authenticated, service_role;

-- 2) overwrite_preparation_with_components: update component name and children in one TX

CREATE OR REPLACE FUNCTION public.overwrite_preparation_with_components(
  _prep_component_id uuid,
  _kitchen_id uuid,
  _new_name text,
  _items jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_recipe_id uuid;
  v_component_kitchen uuid;
BEGIN
  -- Lock the component and associated recipe
  SELECT recipe_id, kitchen_id INTO v_recipe_id, v_component_kitchen
  FROM public.components WHERE component_id = _prep_component_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Preparation component % not found', _prep_component_id; END IF;
  IF v_component_kitchen IS DISTINCT FROM _kitchen_id THEN RAISE EXCEPTION 'Kitchen mismatch for component %', _prep_component_id; END IF;

  -- Update name
  UPDATE public.components SET name = COALESCE(_new_name, name)
  WHERE component_id = _prep_component_id;

  -- Upsert children via helper
  PERFORM public.upsert_preparation_components(v_recipe_id, _kitchen_id, _items);
  RETURN;
END;
$$;

COMMENT ON FUNCTION public.overwrite_preparation_with_components(uuid, uuid, text, jsonb) IS
'Updates a preparation''s name and replaces its children in a single transaction.';

GRANT ALL ON FUNCTION public.overwrite_preparation_with_components(uuid, uuid, text, jsonb) TO anon, authenticated, service_role;

-- 3) replace_recipe_components: transactional replace for any recipe (dish or prep)

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
BEGIN
  -- Lock the recipe row
  PERFORM 1 FROM public.recipes r WHERE r.recipe_id = _recipe_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recipe % not found', _recipe_id; END IF;

  SELECT kitchen_id INTO v_recipe_kitchen FROM public.recipes WHERE recipe_id = _recipe_id;
  IF v_recipe_kitchen IS DISTINCT FROM _kitchen_id THEN RAISE EXCEPTION 'Kitchen mismatch for recipe %', _recipe_id; END IF;

  -- Access checks on component_ids
  SELECT array_agg((x->>'component_id')::uuid)
  INTO v_component_ids
  FROM jsonb_array_elements(_items) AS x
  WHERE (x ? 'component_id') AND length(coalesce(x->>'component_id','')) > 0;

  IF v_component_ids IS NOT NULL AND array_length(v_component_ids, 1) > 0 THEN
    IF EXISTS (
      SELECT 1 FROM public.components c
      WHERE c.component_id = ANY(v_component_ids)
        AND c.kitchen_id IS DISTINCT FROM _kitchen_id
    ) THEN
      RAISE EXCEPTION 'Some components are not accessible in this kitchen';
    END IF;
  END IF;

  -- Replace children
  DELETE FROM public.recipe_components WHERE recipe_id = _recipe_id;

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
'Atomically replaces a recipe''s components in one transaction with access checks.';

GRANT ALL ON FUNCTION public.replace_recipe_components(uuid, uuid, jsonb) TO anon, authenticated, service_role;


