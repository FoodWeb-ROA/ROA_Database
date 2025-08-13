-- Drop default for serving_item on public.recipes
-- Context: recipes.serving_item currently defaults to 'Buns'
-- This migration removes that default, keeping the column nullable.

ALTER TABLE public.recipes
  ALTER COLUMN serving_item DROP DEFAULT;

-- Make serving_size optional globally (only required for Dish via CHECK below)
ALTER TABLE public.recipes
  ALTER COLUMN serving_size DROP NOT NULL,
  ALTER COLUMN serving_size DROP DEFAULT;

-- Make serving_unit optional globally (only required for Dish via CHECK below)
ALTER TABLE public.recipes
  ALTER COLUMN serving_unit DROP NOT NULL,
  ALTER COLUMN serving_unit DROP DEFAULT;

-- Enforce that only Dish-type recipes can use serving_size/serving_item/serving_unit
-- For non-Dish recipes, serving_size, serving_item, and serving_unit must be NULL
ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_servings_only_for_dishes
  CHECK (
    (recipe_type = 'Dish'::recipe_type AND serving_size IS NOT NULL AND serving_unit IS NOT NULL)
    OR (recipe_type <> 'Dish'::recipe_type AND serving_size IS NULL AND serving_item IS NULL AND serving_unit IS NULL)
  );
