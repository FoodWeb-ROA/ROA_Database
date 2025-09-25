-- Preparation Amounts Refactor: Remove 'prep' unit and use real amounts
-- This migration implements the changes outlined in PreparationAmountsRefactor.md

-- =============================================================================
-- STEP 1: Data Migration - convert 'prep' to real amounts
-- =============================================================================

-- CRITICAL: Drop the old trigger first before data migration
-- Otherwise it will prevent us from changing 'prep' units to real units
DROP TRIGGER IF EXISTS enforce_unit_constraint ON public.recipe_components;
DROP FUNCTION IF EXISTS public.check_unit_for_preparations();

-- 1a) Normalize prep yields: set defaults where missing AND fix existing x yields
UPDATE public.recipes r
SET serving_yield_unit = 'x', serving_size_yield = 1
WHERE r.recipe_type = 'Preparation'
  AND (r.serving_yield_unit IS NULL OR r.serving_size_yield IS NULL);

-- 1a.1) Fix existing rows where serving_yield_unit = 'x' but serving_size_yield != 1
UPDATE public.recipes r
SET serving_size_yield = 1
WHERE r.recipe_type = 'Preparation'
  AND r.serving_yield_unit = 'x'
  AND r.serving_size_yield != 1;

-- 1b) Transform existing recipe_components rows that used 'prep'
WITH prep_mappings AS (
  SELECT rc.recipe_id,
         rc.component_id,
         rc.amount                AS multiplier,
         r.serving_size_yield     AS base_yield,
         r.serving_yield_unit     AS yield_unit
  FROM public.recipe_components rc
  JOIN public.components c ON c.component_id = rc.component_id AND c.recipe_id IS NOT NULL
  JOIN public.recipes r   ON r.recipe_id = c.recipe_id
  WHERE rc.unit = 'prep'
)
UPDATE public.recipe_components rc
SET amount = GREATEST(0, COALESCE(pm.multiplier, 0) * COALESCE(pm.base_yield, 1)),
    unit   = COALESCE(pm.yield_unit, 'x'),
    item   = CASE
               WHEN COALESCE(pm.yield_unit, 'x') = 'x' THEN rc.item
               ELSE NULL -- non-count uses must not carry an item label
             END
FROM prep_mappings pm
WHERE rc.recipe_id = pm.recipe_id AND rc.component_id = pm.component_id;

-- =============================================================================
-- STEP 2: Create new enum without 'prep' and migrate columns
-- =============================================================================

-- 2a) Create a new type without 'prep'
CREATE TYPE public.unit_new AS ENUM (
  'mg','g','kg','ml','l','oz','lb','tsp','tbsp','cup','pt','qt','gal','x'
);

-- 2b) Drop remaining dependent triggers, functions, and constraints that reference the old enum
-- Recipe components triggers (enforce_unit_constraint already dropped in step 1)
DROP TRIGGER IF EXISTS trg_recipe_components_item_unit ON public.recipe_components;

-- Drop constraint that might reference the enum
ALTER TABLE public.recipe_components DROP CONSTRAINT IF EXISTS recipe_components_item_unit_guard;

-- Drop remaining functions that reference the enum (check_unit_for_preparations already dropped in step 1)
DROP FUNCTION IF EXISTS public.recipe_components_item_unit_guard();
DROP FUNCTION IF EXISTS public.get_components_for_recipes(uuid[]);

-- Drop any other constraints on recipes table that might reference the enum
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS recipes_serving_item_requires_x;

-- 2c) Migrate columns to unit_new (explicit cast through text)
ALTER TABLE public.recipe_components
  ALTER COLUMN unit TYPE public.unit_new USING unit::text::public.unit_new;

ALTER TABLE public.recipes
  ALTER COLUMN serving_yield_unit TYPE public.unit_new USING serving_yield_unit::text::public.unit_new;

-- 2d) Drop old type and rename
DROP TYPE public.unit;
ALTER TYPE public.unit_new RENAME TO unit;

-- 2e) Recreate the item_unit constraint that was dropped
ALTER TABLE public.recipe_components 
  ADD CONSTRAINT recipe_components_item_unit_check 
  CHECK (unit = 'x' OR item IS NULL);

-- 2f) Recreate the serving_item constraint
ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_serving_item_requires_x 
  CHECK ((serving_item IS NULL) OR (serving_yield_unit = 'x'));

-- 2g) Recreate the recipe_components item unit guard function and trigger
CREATE OR REPLACE FUNCTION public.recipe_components_item_unit_guard()
RETURNS trigger LANGUAGE plpgsql
SET search_path TO ''
AS $$
BEGIN
  IF NEW.unit <> 'x' AND NEW.item IS NOT NULL THEN
    RAISE EXCEPTION 'item can only be set when unit = ''x''.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_recipe_components_item_unit
BEFORE INSERT OR UPDATE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.recipe_components_item_unit_guard();

-- =============================================================================
-- STEP 3: Create new helper functions and constraints
-- =============================================================================

-- 3a) New helper: measurement type resolver (DB-side)
CREATE OR REPLACE FUNCTION public.unit_kind(u public.unit)
RETURNS text 
LANGUAGE sql IMMUTABLE 
SET "search_path" TO ''
AS $$
  SELECT CASE u
           WHEN 'mg' THEN 'mass' WHEN 'g' THEN 'mass' WHEN 'kg' THEN 'mass'
           WHEN 'oz' THEN 'mass' WHEN 'lb' THEN 'mass'
           WHEN 'ml' THEN 'volume' WHEN 'l' THEN 'volume'
           WHEN 'tsp' THEN 'volume' WHEN 'tbsp' THEN 'volume' WHEN 'cup' THEN 'volume'
           WHEN 'pt' THEN 'volume' WHEN 'qt' THEN 'volume' WHEN 'gal' THEN 'volume'
           WHEN 'x' THEN 'count'
           ELSE NULL
         END;
$$;

-- 3b) New preparation component unit compatibility guard
CREATE OR REPLACE FUNCTION public.rc_prep_unit_guard()
RETURNS trigger 
LANGUAGE plpgsql 
SET "search_path" TO ''
AS $$
DECLARE
  child_recipe_id uuid;
  yield_unit public.unit;
BEGIN
  -- Only enforce if component is a preparation (has a recipe_id)
  SELECT c.recipe_id INTO child_recipe_id
  FROM public.components c
  WHERE c.component_id = NEW.component_id AND c.recipe_id IS NOT NULL;

  IF child_recipe_id IS NULL THEN
    RETURN NEW; -- raw ingredient
  END IF;

  SELECT r.serving_yield_unit INTO yield_unit
  FROM public.recipes r WHERE r.recipe_id = child_recipe_id;

  IF yield_unit IS NULL THEN
    -- Should be normalized to 'x' via defaults; double-guard
    RAISE EXCEPTION 'Preparation yield must be defined';
  END IF;

  -- If yield is count, parent usage must be count
  IF yield_unit = 'x' AND NEW.unit <> 'x' THEN
    RAISE EXCEPTION 'When preparation yield is count (x), parent unit must be x';
  END IF;

  -- If yield is mass/volume, parent usage must match measurement kind
  IF yield_unit <> 'x' THEN
    IF public.unit_kind(NEW.unit) IS DISTINCT FROM public.unit_kind(yield_unit) THEN
      RAISE EXCEPTION 'Parent unit % incompatible with preparation yield %', NEW.unit, yield_unit;
    END IF;
  END IF;

  -- item is only allowed with count
  IF NEW.unit <> 'x' AND NEW.item IS NOT NULL THEN
    RAISE EXCEPTION 'item can only be set when unit = x';
  END IF;

  RETURN NEW;
END;$$;

-- 3c) Guard against yield unit measurement-type changes when preparation is in use
CREATE OR REPLACE FUNCTION public.prep_yield_change_guard()
RETURNS trigger 
LANGUAGE plpgsql 
SET "search_path" TO ''
AS $$
DECLARE
  existing_kind text;
  new_kind text;
  in_use boolean;
BEGIN
  IF NEW.recipe_type <> 'Preparation' THEN
    RETURN NEW;
  END IF;

  IF NEW.serving_yield_unit IS DISTINCT FROM OLD.serving_yield_unit THEN
    -- Force amount to 1 when unit is x
    IF NEW.serving_yield_unit = 'x' AND NEW.serving_size_yield <> 1 THEN
      NEW.serving_size_yield := 1;
    END IF;

    existing_kind := public.unit_kind(OLD.serving_yield_unit);
    new_kind := public.unit_kind(NEW.serving_yield_unit);

    SELECT EXISTS (
      SELECT 1 FROM public.recipe_components rc
      JOIN public.components c ON c.component_id = rc.component_id
      WHERE c.recipe_id = NEW.recipe_id
    ) INTO in_use;

    IF in_use AND existing_kind IS DISTINCT FROM new_kind THEN
      RAISE EXCEPTION 'Cannot change preparation yield measurement type while it is used in other recipes';
    END IF;
  END IF;
  RETURN NEW;
END;$$;

-- =============================================================================
-- STEP 4: Create new triggers and constraints
-- =============================================================================

-- 4a) Replace the old unit constraint trigger with the new guard
CREATE TRIGGER trg_rc_prep_unit_guard
BEFORE INSERT OR UPDATE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.rc_prep_unit_guard();

-- 4b) Add trigger to guard yield changes
CREATE TRIGGER trg_prep_yield_change_guard
BEFORE UPDATE OF serving_yield_unit, serving_size_yield ON public.recipes
FOR EACH ROW EXECUTE FUNCTION public.prep_yield_change_guard();

-- 4c) Add constraint: If yield unit is x, yield amount must be 1 (ONLY for Preparations)
ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_x_yield_is_1
  CHECK (
    recipe_type IS DISTINCT FROM 'Preparation' OR
    serving_yield_unit IS DISTINCT FROM 'x' OR 
    serving_size_yield = 1
  );

-- =============================================================================
-- STEP 5: Set defaults for preparation yields
-- =============================================================================

-- 5a) Set default values for new preparation recipes
ALTER TABLE public.recipes 
  ALTER COLUMN serving_yield_unit SET DEFAULT 'x',
  ALTER COLUMN serving_size_yield SET DEFAULT 1;

-- Note: The constraint and trigger above already enforce serving_size_yield = 1 when serving_yield_unit = 'x'

-- =============================================================================
-- STEP 6: Re-create any dependent functions that were dropped
-- =============================================================================

-- Update the function signatures for functions that referenced the old enum
-- (Most functions should still work, but let's ensure compatibility)

-- Update the get_components_for_recipes function signature
DROP FUNCTION IF EXISTS public.get_components_for_recipes(uuid[]);
CREATE OR REPLACE FUNCTION public.get_components_for_recipes(_recipe_ids uuid[])
RETURNS TABLE(
  recipe_id uuid,
  component_id uuid,
  amount numeric,
  unit public.unit,
  is_preparation boolean
)
LANGUAGE sql STABLE SECURITY DEFINER
SET "search_path" TO ''
AS $$
  SELECT
    rc.recipe_id,
    rc.component_id,
    rc.amount,
    rc.unit AS unit,
    (c.component_type = 'Preparation') AS is_preparation
  FROM public.recipe_components rc
  JOIN public.components c ON c.component_id = rc.component_id
  WHERE rc.recipe_id = ANY(_recipe_ids);
$$;

-- =============================================================================
-- STEP 7: Grant permissions on new functions
-- =============================================================================

GRANT ALL ON FUNCTION public.unit_kind(public.unit) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.rc_prep_unit_guard() TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.prep_yield_change_guard() TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.recipe_components_item_unit_guard() TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.get_components_for_recipes(uuid[]) TO anon, authenticated, service_role;
