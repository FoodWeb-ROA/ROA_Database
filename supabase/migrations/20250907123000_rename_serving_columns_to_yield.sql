-- migrate:up
BEGIN;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'recipes' AND column_name = 'serving_size'
  ) THEN
    ALTER TABLE public.recipes RENAME COLUMN serving_size TO serving_size_yield;
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'recipes' AND column_name = 'serving_unit'
  ) THEN
    ALTER TABLE public.recipes RENAME COLUMN serving_unit TO serving_yield_unit;
  END IF;
END;
$$;
COMMIT;

-- (no down migration)

