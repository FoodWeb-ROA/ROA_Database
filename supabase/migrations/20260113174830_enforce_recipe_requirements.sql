
-- Delete recipes that do not meet minimum requirements
-- (cascades will clean up recipe_components and any paired components rows)
DELETE FROM public.recipes r
WHERE r.recipe_name IS NULL
   OR r."time" IS NULL
   OR r.serving_or_yield_amount IS NULL
   OR r.serving_or_yield_unit IS NULL
   OR r.directions IS NULL
   OR COALESCE(array_length(r.directions, 1), 0) < 1
   OR NOT EXISTS (
     SELECT 1
     FROM public.recipe_components rc
     WHERE rc.recipe_id = r.recipe_id
   );


-- Enforce required fields (low-overhead column constraints)
ALTER TABLE public.recipes
ALTER COLUMN recipe_name SET NOT NULL;

ALTER TABLE public.recipes
ALTER COLUMN "time" SET NOT NULL;

ALTER TABLE public.recipes
ALTER COLUMN serving_or_yield_amount SET NOT NULL;

ALTER TABLE public.recipes
ALTER COLUMN serving_or_yield_unit SET NOT NULL;


-- Enforce directions must exist and be non-empty
ALTER TABLE public.recipes
ALTER COLUMN directions SET NOT NULL;

ALTER TABLE public.recipes
DROP CONSTRAINT IF EXISTS recipes_directions_nonempty;

ALTER TABLE public.recipes
ADD CONSTRAINT recipes_directions_nonempty
CHECK (COALESCE(array_length(directions, 1), 0) >= 1);


-- Enforce recipes must have at least 1 recipe_components row.
-- Implemented as DEFERRABLE constraint triggers so save_recipe (delete+insert) works.
-- Uses a per-transaction temp table to avoid repeated checks for the same recipe_id.
CREATE OR REPLACE FUNCTION public.enforce_recipe_has_components() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_recipe_id uuid;
BEGIN
  IF TG_TABLE_NAME = 'recipes' THEN
    v_recipe_id := NEW.recipe_id;
  ELSE
    v_recipe_id := COALESCE(NEW.recipe_id, OLD.recipe_id);
  END IF;

  IF v_recipe_id IS NULL THEN
    RETURN NULL;
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS pg_temp._checked_recipe_has_components (
    recipe_id uuid PRIMARY KEY
  ) ON COMMIT DROP;

  INSERT INTO pg_temp._checked_recipe_has_components (recipe_id)
  VALUES (v_recipe_id)
  ON CONFLICT DO NOTHING;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- If the recipe was deleted in this transaction, don't enforce.
  IF NOT EXISTS (
    SELECT 1
    FROM public.recipes r
    WHERE r.recipe_id = v_recipe_id
  ) THEN
    RETURN NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.recipe_components rc
    WHERE rc.recipe_id = v_recipe_id
  ) THEN
    RAISE EXCEPTION 'Recipe % must have at least 1 recipe_components row', v_recipe_id;
  END IF;

  RETURN NULL;
END;
$$;

ALTER FUNCTION public.enforce_recipe_has_components() OWNER TO postgres;


DROP TRIGGER IF EXISTS trg_recipes_require_components ON public.recipes;
CREATE CONSTRAINT TRIGGER trg_recipes_require_components
AFTER INSERT ON public.recipes
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.enforce_recipe_has_components();


DROP TRIGGER IF EXISTS trg_recipe_components_require_parent_recipe ON public.recipe_components;
CREATE CONSTRAINT TRIGGER trg_recipe_components_require_parent_recipe
AFTER INSERT OR DELETE OR UPDATE OF recipe_id ON public.recipe_components
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.enforce_recipe_has_components();

