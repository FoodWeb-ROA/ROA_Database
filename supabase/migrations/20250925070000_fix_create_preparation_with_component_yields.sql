-- Fix: Persist yields for new preparations created via RPC
-- Updates create_preparation_with_component to accept yield fields and set safe defaults

CREATE OR REPLACE FUNCTION public.create_preparation_with_component(
  _kitchen uuid,
  _name text,
  _category uuid,
  _directions text[],
  _time interval,
  _cooking_notes text,
  _yield_unit public.unit DEFAULT NULL,
  _yield_amount numeric DEFAULT NULL
)
RETURNS TABLE(recipe_id uuid, component_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_recipe_id uuid;
  v_component_id uuid;
  v_unit public.unit;
  v_amount numeric;
BEGIN
  -- Use provided yields when available; otherwise default to count-style 1 x for preparations
  v_unit := COALESCE(_yield_unit, 'x');
  v_amount := CASE WHEN v_unit = 'x' THEN 1 ELSE COALESCE(_yield_amount, 1) END;

  INSERT INTO public.recipes (
    recipe_name, category_id, directions, "time",
    serving_or_yield_unit, serving_item, recipe_type, cooking_notes, kitchen_id, serving_or_yield_amount
  ) VALUES (
    COALESCE(_name, ''), _category, _directions, COALESCE(_time, '00:00:00'::interval),
    v_unit, NULL, 'Preparation', _cooking_notes, _kitchen, v_amount
  ) RETURNING recipes.recipe_id INTO v_recipe_id;

  INSERT INTO public.components (name, component_type, kitchen_id, recipe_id)
  VALUES (COALESCE(_name, ''), 'Preparation', _kitchen, v_recipe_id)
  RETURNING components.component_id INTO v_component_id;

  -- Explicitly return a single row to the caller
  RETURN QUERY SELECT v_recipe_id::uuid AS recipe_id, v_component_id::uuid AS component_id;
END;
$$;

ALTER FUNCTION public.create_preparation_with_component(
  _kitchen uuid,
  _name text,
  _category uuid,
  _directions text[],
  _time interval,
  _cooking_notes text,
  _yield_unit public.unit,
  _yield_amount numeric
) OWNER TO postgres;


