-- Migration: Rename serving_size_yield and serving_yield_unit in recipes to serving_or_yield_amount and serving_or_yield_unit
-- Date: 2025-09-25

-- 1. Drop constraints that reference the old columns
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS recipes_serving_item_requires_x;
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS recipes_x_yield_is_1;
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS recipes_yield_pair_check;

-- 2. Rename the columns
ALTER TABLE public.recipes RENAME COLUMN serving_size_yield TO serving_or_yield_amount;
ALTER TABLE public.recipes RENAME COLUMN serving_yield_unit TO serving_or_yield_unit;

-- 3. Update constraints to use new column names
ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_serving_item_requires_x 
  CHECK ((serving_item IS NULL) OR (serving_or_yield_unit = 'x'));


ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_x_yield_is_1
  CHECK (
    recipe_type IS DISTINCT FROM 'Preparation' OR
    serving_or_yield_unit IS DISTINCT FROM 'x' OR 
    serving_or_yield_amount = 1
  );

ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_yield_pair_check
  CHECK (
    (serving_or_yield_unit IS NULL AND serving_or_yield_amount IS NULL) OR
    (serving_or_yield_unit IS NOT NULL AND serving_or_yield_amount IS NOT NULL)
  );

-- 4. Update default values
ALTER TABLE public.recipes 
  ALTER COLUMN serving_or_yield_unit SET DEFAULT 'x',
  ALTER COLUMN serving_or_yield_amount SET DEFAULT 1;

-- 5. Update any functions/triggers referencing the old columns (if needed, do this in follow-up migrations)
-- (Manual review required for plpgsql functions, but most use COALESCE or reference by name)

-- 6. Update comments if present
COMMENT ON COLUMN public.recipes.serving_or_yield_amount IS 'Yield or serving amount for the recipe (was serving_size_yield)';
COMMENT ON COLUMN public.recipes.serving_or_yield_unit IS 'Yield or serving unit for the recipe (was serving_yield_unit)';
