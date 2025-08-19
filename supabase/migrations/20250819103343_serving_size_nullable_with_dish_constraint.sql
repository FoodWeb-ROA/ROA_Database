-- Make serving_size nullable and add constraint to ensure it's NOT NULL for Dish recipes
-- and NULL for Preparation recipes

BEGIN;

-- Make serving_size column nullable (it's already nullable based on the generated types)
-- But add a constraint to enforce business logic

-- Add constraint: Dish recipes must have serving_size, Preparations must not
ALTER TABLE public.recipes 
ADD CONSTRAINT serving_size_dish_constraint 
CHECK (
  (recipe_type = 'Dish' AND serving_size IS NOT NULL) OR
  (recipe_type = 'Preparation' AND serving_size IS NULL)
);

COMMIT;