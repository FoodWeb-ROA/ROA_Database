-- Ensure serving_yield_unit and serving_size_yield are either both NULL or both NOT NULL
-- 1) Normalize existing data: if either is NULL, set both to NULL
UPDATE public.recipes
SET serving_yield_unit = NULL,
    serving_size_yield = NULL
WHERE serving_yield_unit IS NULL
   OR serving_size_yield IS NULL;

-- 2) Add CHECK constraint enforcing paired presence
ALTER TABLE public.recipes
DROP CONSTRAINT IF EXISTS recipes_yield_pair_check;

ALTER TABLE public.recipes
ADD CONSTRAINT recipes_yield_pair_check
CHECK (
  (serving_yield_unit IS NULL AND serving_size_yield IS NULL)
  OR
  (serving_yield_unit IS NOT NULL AND serving_size_yield IS NOT NULL)
);


