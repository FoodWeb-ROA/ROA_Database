-- migrate:up
BEGIN;

-- 1) Rename columns if still using legacy names
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'serving_size'
  ) THEN
    ALTER TABLE public.recipes RENAME COLUMN serving_size TO serving_size_yield;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'serving_unit'
  ) THEN
    ALTER TABLE public.recipes RENAME COLUMN serving_unit TO serving_yield_unit;
  END IF;
END;
$$;

-- 2.0) Ensure columns are nullable globally (Dish requirement enforced via CHECKs)
DO $$
BEGIN
  -- serving_size or serving_size_yield
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'serving_size_yield'
  ) THEN
    ALTER TABLE public.recipes ALTER COLUMN serving_size_yield DROP NOT NULL;
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'serving_size'
  ) THEN
    ALTER TABLE public.recipes ALTER COLUMN serving_size DROP NOT NULL;
  END IF;

  -- serving_unit or serving_yield_unit
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'serving_yield_unit'
  ) THEN
    ALTER TABLE public.recipes ALTER COLUMN serving_yield_unit DROP NOT NULL;
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'serving_unit'
  ) THEN
    ALTER TABLE public.recipes ALTER COLUMN serving_unit DROP NOT NULL;
  END IF;
END;
$$;

-- 2) Drop old constraints that forced NULL for preparations
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS serving_size_dish_constraint;
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS serving_unit_dish_constraint;

-- Also drop any previous attempts with new names to keep idempotency
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS serving_size_yield_dish_required;
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS serving_yield_unit_dish_required;

-- Ensure serving_item -> 'x' constraint references the new column name
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS recipes_serving_item_requires_x;
ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_serving_item_requires_x
  CHECK (serving_item IS NULL OR serving_yield_unit = 'x');

COMMIT;

-- (no down migration)

