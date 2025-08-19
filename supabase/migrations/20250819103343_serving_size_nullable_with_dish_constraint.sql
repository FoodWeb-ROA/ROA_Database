-- Make serving_size nullable and add constraint to ensure it's NOT NULL for Dish recipes
-- and NULL for Preparation recipes

BEGIN;

-- First, clean up existing data to comply with new constraint
-- Set serving_size = NULL for all Preparation recipes
UPDATE public.recipes 
SET serving_size = NULL 
WHERE recipe_type = 'Preparation';

-- Set serving_size = 1 for Dish recipes that have NULL serving_size
UPDATE public.recipes 
SET serving_size = 1 
WHERE recipe_type = 'Dish' AND serving_size IS NULL;

-- Now add constraint: Dish recipes must have serving_size, Preparations must not
ALTER TABLE public.recipes 
ADD CONSTRAINT serving_size_dish_constraint 
CHECK (
  (recipe_type = 'Dish' AND serving_size IS NOT NULL) OR
  (recipe_type = 'Preparation' AND serving_size IS NULL)
);

COMMIT;