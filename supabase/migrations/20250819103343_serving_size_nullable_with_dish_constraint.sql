-- Make serving_size and serving_unit nullable and add constraints to ensure they're NOT NULL for Dish recipes
-- and NULL for Preparation recipes

BEGIN;

-- First, make serving_size and serving_unit nullable by dropping NOT NULL constraints
ALTER TABLE public.recipes ALTER COLUMN serving_size DROP NOT NULL;
ALTER TABLE public.recipes ALTER COLUMN serving_unit DROP NOT NULL;

-- Clean up existing data to comply with new constraints
-- Set serving_size = NULL and serving_unit = NULL for all Preparation recipes
UPDATE public.recipes 
SET serving_size = NULL, serving_unit = NULL 
WHERE recipe_type = 'Preparation';

-- Set serving_size = 1 for Dish recipes that have NULL serving_size
UPDATE public.recipes 
SET serving_size = 1 
WHERE recipe_type = 'Dish' AND serving_size IS NULL;

-- Set serving_unit = 'x' for Dish recipes that have NULL serving_unit
UPDATE public.recipes 
SET serving_unit = 'x' 
WHERE recipe_type = 'Dish' AND serving_unit IS NULL;

-- Now add constraints: Dish recipes must have serving_size and serving_unit, Preparations must not
ALTER TABLE public.recipes 
ADD CONSTRAINT serving_size_dish_constraint 
CHECK (
  (recipe_type = 'Dish' AND serving_size IS NOT NULL) OR
  (recipe_type = 'Preparation' AND serving_size IS NULL)
);

ALTER TABLE public.recipes 
ADD CONSTRAINT serving_unit_dish_constraint 
CHECK (
  (recipe_type = 'Dish' AND serving_unit IS NOT NULL) OR
  (recipe_type = 'Preparation' AND serving_unit IS NULL)
);

COMMIT;