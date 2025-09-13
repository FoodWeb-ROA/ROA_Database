
-- 6) RPC: create_preparation_with_component – transactional create of recipe + component
CREATE OR REPLACE FUNCTION public.create_preparation_with_component(
  _kitchen uuid,
  _name text,
  _category uuid,
  _directions text[],
  _time interval,
  _cooking_notes text
)
RETURNS TABLE(recipe_id uuid, component_id uuid)
LANGUAGE plpgsql
AS $$
DECLARE
  v_recipe_id uuid;
  v_component_id uuid;
BEGIN
  INSERT INTO public.recipes (
    recipe_name, category_id, directions, "time",
    serving_yield_unit, serving_item, recipe_type, cooking_notes, kitchen_id, serving_size_yield
  ) VALUES (
    COALESCE(_name, ''), _category, _directions, COALESCE(_time, '00:00:00'::interval),
    NULL, NULL, 'Preparation', _cooking_notes, _kitchen, NULL
  ) RETURNING recipes.recipe_id INTO v_recipe_id;

  INSERT INTO public.components (name, component_type, kitchen_id, recipe_id)
  VALUES (COALESCE(_name, ''), 'Preparation', _kitchen, v_recipe_id)
  RETURNING components.component_id INTO v_component_id;

  recipe_id := v_recipe_id;
  component_id := v_component_id;
  RETURN NEXT;
  RETURN;
END;
$$;

ALTER FUNCTION public.create_preparation_with_component(uuid, text, uuid, text[], interval, text) SET search_path TO '';
GRANT EXECUTE ON FUNCTION public.create_preparation_with_component(uuid, text, uuid, text[], interval, text) TO authenticated;


