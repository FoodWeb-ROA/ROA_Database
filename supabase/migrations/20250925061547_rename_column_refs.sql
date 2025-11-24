CREATE OR REPLACE FUNCTION public.create_preparation_with_component(_kitchen uuid, _name text, _category uuid, _directions text[], _time interval, _cooking_notes text)
RETURNS TABLE(recipe_id uuid, component_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_recipe_id uuid;
  v_component_id uuid;
BEGIN
  INSERT INTO public.recipes (
    recipe_name, category_id, directions, "time",
    serving_or_yield_unit, serving_item, recipe_type, cooking_notes, kitchen_id, serving_or_yield_amount
  ) VALUES (
    COALESCE(_name, ''), _category, _directions, COALESCE(_time, '00:00:00'::interval),
    NULL, NULL, 'Preparation', _cooking_notes, _kitchen, NULL
  ) RETURNING recipes.recipe_id INTO v_recipe_id;

  INSERT INTO public.components (name, component_type, kitchen_id, recipe_id)
  VALUES (COALESCE(_name, ''), 'Preparation', _kitchen, v_recipe_id)
  RETURNING components.component_id INTO v_component_id;

  -- Explicitly return a single row to the caller
  RETURN QUERY SELECT v_recipe_id::uuid AS recipe_id, v_component_id::uuid AS component_id;
END;
$$;

ALTER FUNCTION public.create_preparation_with_component(_kitchen uuid, _name text, _category uuid, _directions text[], _time interval, _cooking_notes text)
OWNER TO postgres;

CREATE OR REPLACE FUNCTION "public"."set_recipe_type"("p_recipe_id" "uuid", "p_new_type" "public"."recipe_type") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  v_old_type public.recipe_type;
  v_kitchen_id uuid;
  v_name text;
BEGIN
  -- Lock row to avoid races
  SELECT recipe_type, kitchen_id, recipe_name INTO v_old_type, v_kitchen_id, v_name
  FROM public.recipes WHERE recipe_id = p_recipe_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Recipe % not found', p_recipe_id;
  END IF;

  IF v_old_type = p_new_type THEN
    RETURN;
  END IF;

  IF p_new_type = 'Preparation' THEN
    -- Update recipe first, then ensure matching component
    UPDATE public.recipes
      SET recipe_type = 'Preparation',
          serving_or_yield_unit = NULL,
          serving_or_yield_amount = NULL,
          serving_item = NULL
      WHERE recipe_id = p_recipe_id;

    -- Insert component if missing
    IF NOT EXISTS (
      SELECT 1 FROM public.components c WHERE c.recipe_id = p_recipe_id AND c.component_type = 'Preparation'
    ) THEN
      INSERT INTO public.components (name, component_type, kitchen_id, recipe_id)
      VALUES (COALESCE(v_name, ''), 'Preparation', v_kitchen_id, p_recipe_id);
    END IF;

  ELSIF p_new_type = 'Dish' THEN
    -- Remove any component row pointing to this recipe
    DELETE FROM public.components WHERE recipe_id = p_recipe_id;
    -- Update recipe type
    UPDATE public.recipes
      SET recipe_type = 'Dish'
      WHERE recipe_id = p_recipe_id;
  END IF;
END;
$$;

ALTER FUNCTION public.set_recipe_type("p_recipe_id" "uuid", "p_new_type" "public"."recipe_type") OWNER TO postgres;