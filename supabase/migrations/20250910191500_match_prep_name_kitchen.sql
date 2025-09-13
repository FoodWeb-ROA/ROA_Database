-- Ensure preparation recipes match their paired components on name and kitchen_id
-- Idempotent migration with backfill + DEFERRABLE constraint triggers

BEGIN;

-- 1) Backfill existing mismatches: align both sides to a single source of truth
--    We choose components as source for name/kitchen if present; if components.name is NULL use recipes.recipe_name.

-- 1a) Backfill recipes from components where they differ (preparations only)
WITH diffs AS (
  SELECT r.recipe_id,
         c.name           AS component_name,
         r.recipe_name    AS recipe_name,
         c.kitchen_id     AS component_kitchen_id,
         r.kitchen_id     AS recipe_kitchen_id
  FROM   public.recipes r
  JOIN   public.components c ON c.recipe_id = r.recipe_id AND c.component_type = 'Preparation'
  WHERE  r.recipe_type = 'Preparation'
    AND  (
           (c.name IS NOT NULL AND c.name IS DISTINCT FROM r.recipe_name)
           OR (c.kitchen_id IS DISTINCT FROM r.kitchen_id)
         )
)
UPDATE public.recipes r
SET    recipe_name = COALESCE(d.component_name, r.recipe_name),
       kitchen_id  = COALESCE(d.component_kitchen_id, r.kitchen_id)
FROM   diffs d
WHERE  r.recipe_id = d.recipe_id;

-- 1b) Backfill components from recipes where they differ (preparations only)
WITH diffs AS (
  SELECT c.component_id,
         r.recipe_name    AS recipe_name,
         c.name           AS component_name,
         r.kitchen_id     AS recipe_kitchen_id,
         c.kitchen_id     AS component_kitchen_id
  FROM   public.components c
  JOIN   public.recipes r ON r.recipe_id = c.recipe_id AND r.recipe_type = 'Preparation'
  WHERE  c.component_type = 'Preparation'
    AND  (
           (r.recipe_name IS NOT NULL AND r.recipe_name IS DISTINCT FROM c.name)
           OR (r.kitchen_id IS DISTINCT FROM c.kitchen_id)
         )
)
UPDATE public.components c
SET    name       = COALESCE(d.recipe_name, c.name),
       kitchen_id = COALESCE(d.recipe_kitchen_id, c.kitchen_id)
FROM   diffs d
WHERE  c.component_id = d.component_id;

-- 2) Create constraint trigger functions to enforce equality going forward

CREATE OR REPLACE FUNCTION public.enforce_prep_name_kitchen_match_from_components()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.component_type = 'Preparation' THEN
    IF NEW.recipe_id IS NULL THEN
      RAISE EXCEPTION 'Preparation component must have recipe_id';
    END IF;
    -- Ensure target recipe exists and is a Preparation
    PERFORM 1 FROM public.recipes r WHERE r.recipe_id = NEW.recipe_id AND r.recipe_type = 'Preparation';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Preparation component must reference a Preparation recipe';
    END IF;

    -- Enforce equality by updating recipe to match component
    UPDATE public.recipes r
       SET recipe_name = COALESCE(NEW.name, r.recipe_name),
           kitchen_id  = COALESCE(NEW.kitchen_id, r.kitchen_id)
     WHERE r.recipe_id = NEW.recipe_id
       AND r.recipe_type = 'Preparation'
       AND (r.recipe_name IS DISTINCT FROM COALESCE(NEW.name, r.recipe_name)
            OR r.kitchen_id IS DISTINCT FROM COALESCE(NEW.kitchen_id, r.kitchen_id));
  END IF;
  RETURN NULL; -- for constraint triggers
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_prep_name_kitchen_match_from_recipes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.recipe_type = 'Preparation' THEN
    -- Ensure a matching preparation component exists
    PERFORM 1 FROM public.components c WHERE c.recipe_id = NEW.recipe_id AND c.component_type = 'Preparation';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Preparation recipe must have a matching component (name/kitchen match enforcement)';
    END IF;

    -- Enforce equality by updating component to match recipe
    UPDATE public.components c
       SET name       = COALESCE(NEW.recipe_name, c.name),
           kitchen_id = COALESCE(NEW.kitchen_id, c.kitchen_id)
     WHERE c.recipe_id = NEW.recipe_id
       AND c.component_type = 'Preparation'
       AND (c.name IS DISTINCT FROM COALESCE(NEW.recipe_name, c.name)
            OR c.kitchen_id IS DISTINCT FROM COALESCE(NEW.kitchen_id, c.kitchen_id));
  END IF;
  RETURN NULL; -- for constraint triggers
END;
$$;

-- Harden search_path for security
ALTER FUNCTION public.enforce_prep_name_kitchen_match_from_components() SET search_path TO '';
ALTER FUNCTION public.enforce_prep_name_kitchen_match_from_recipes() SET search_path TO '';

-- 3) Add DEFERRABLE constraint triggers so multi-row transactions can succeed atomically
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_components_match_name_kitchen'
  ) THEN
    CREATE CONSTRAINT TRIGGER trg_components_match_name_kitchen
    AFTER INSERT OR UPDATE OF name, kitchen_id, component_type, recipe_id ON public.components
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_prep_name_kitchen_match_from_components();
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_recipes_match_name_kitchen'
  ) THEN
    CREATE CONSTRAINT TRIGGER trg_recipes_match_name_kitchen
    AFTER INSERT OR UPDATE OF recipe_name, kitchen_id, recipe_type ON public.recipes
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_prep_name_kitchen_match_from_recipes();
  END IF;
END $$;

COMMIT;


