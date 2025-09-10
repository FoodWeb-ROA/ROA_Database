-- Enforce 1:1 pairing between recipes(Preparation) and components(Preparation)
-- And ensure dishes do not have a components row, and raw ingredients do not have a recipes row

-- 1) Partial unique index: at most one Preparation component per recipe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_components_unique_prep_recipe'
  ) THEN
    EXECUTE 'CREATE UNIQUE INDEX idx_components_unique_prep_recipe
             ON public.components (recipe_id)
             WHERE component_type = ''Preparation''';
  END IF;
END $$;

-- 2) Components-level CHECK: enforce recipe_id nullability by component_type
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'components_recipe_id_nullable_by_type'
  ) THEN
    ALTER TABLE public.components
      ADD CONSTRAINT components_recipe_id_nullable_by_type
      CHECK (
        (component_type = 'Preparation' AND recipe_id IS NOT NULL)
        OR
        (component_type = 'Raw_Ingredient' AND recipe_id IS NULL)
      );
  END IF;
END $$;

-- 3) Constraint trigger functions to validate cross-table invariants
CREATE OR REPLACE FUNCTION public.components_enforce_recipe_pairing()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.component_type = 'Preparation' THEN
    IF NEW.recipe_id IS NULL THEN
      RAISE EXCEPTION 'Preparation component must have recipe_id';
    END IF;
    PERFORM 1 FROM public.recipes r
      WHERE r.recipe_id = NEW.recipe_id AND r.recipe_type = 'Preparation';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Preparation component must reference a recipe of type Preparation';
    END IF;
  ELSE
    -- Raw_Ingredient must not reference any recipe
    IF NEW.recipe_id IS NOT NULL THEN
      RAISE EXCEPTION 'Raw_Ingredient component cannot have a recipe_id';
    END IF;
  END IF;
  RETURN NULL; -- for constraint triggers
END;
$$;

CREATE OR REPLACE FUNCTION public.recipes_enforce_component_pairing()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.recipe_type = 'Preparation' THEN
    PERFORM 1 FROM public.components c
      WHERE c.recipe_id = NEW.recipe_id AND c.component_type = 'Preparation';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Preparation recipe must have a matching components row';
    END IF;
  ELSE
    -- Dish must not have any components row pointing to it
    PERFORM 1 FROM public.components c
      WHERE c.recipe_id = NEW.recipe_id;
    IF FOUND THEN
      RAISE EXCEPTION 'Dish recipe cannot have a components row (component_type should be Preparation only)';
    END IF;
  END IF;
  RETURN NULL; -- for constraint triggers
END;
$$;

-- 4) Create DEFERRABLE constraint triggers so both sides can be satisfied atomically
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_components_enforce_recipe_pairing'
  ) THEN
    CREATE CONSTRAINT TRIGGER trg_components_enforce_recipe_pairing
    AFTER INSERT OR UPDATE OF component_type, recipe_id ON public.components
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION public.components_enforce_recipe_pairing();
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_recipes_enforce_component_pairing'
  ) THEN
    CREATE CONSTRAINT TRIGGER trg_recipes_enforce_component_pairing
    AFTER INSERT OR UPDATE OF recipe_type ON public.recipes
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION public.recipes_enforce_component_pairing();
  END IF;
END $$;

-- 5) RPC: set_recipe_type() to atomically convert a recipe type and create/delete component
CREATE OR REPLACE FUNCTION public.set_recipe_type(p_recipe_id uuid, p_new_type public.recipe_type)
RETURNS void
LANGUAGE plpgsql
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
          serving_yield_unit = NULL,
          serving_size_yield = NULL,
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

-- Harden search_path for all new functions
ALTER FUNCTION public.components_enforce_recipe_pairing() SET search_path TO '';
ALTER FUNCTION public.recipes_enforce_component_pairing() SET search_path TO '';
ALTER FUNCTION public.set_recipe_type(uuid, public.recipe_type) SET search_path TO '';

-- Grant execute on RPC to authenticated clients
GRANT EXECUTE ON FUNCTION public.set_recipe_type(uuid, public.recipe_type) TO authenticated;

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
  RETURN;
END;
$$;

ALTER FUNCTION public.create_preparation_with_component(uuid, text, uuid, text[], interval, text) SET search_path TO '';
GRANT EXECUTE ON FUNCTION public.create_preparation_with_component(uuid, text, uuid, text[], interval, text) TO authenticated;


