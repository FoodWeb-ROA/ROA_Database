-- Drop default for serving_item on public.recipes
-- Context: recipes.serving_item currently defaults to 'Buns'
-- This migration removes that default, keeping the column nullable.

ALTER TABLE public.recipes
  ALTER COLUMN serving_item DROP DEFAULT;
