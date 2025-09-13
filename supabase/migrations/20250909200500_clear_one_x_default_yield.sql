-- Drop any defaults on yield columns to avoid implicit 1 x
ALTER TABLE public.recipes ALTER COLUMN serving_size_yield DROP DEFAULT;
ALTER TABLE public.recipes ALTER COLUMN serving_yield_unit DROP DEFAULT;

-- drop legacy dish-required yield constraints if they still exist (remote safety)
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS serving_size_yield_dish_required;
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS serving_yield_unit_dish_required;
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS serving_size_dish_constraint;
ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS serving_unit_dish_constraint;

-- Clear default yields of 1 x when no serving_item is provided
-- We want yield fields blank (NULL) unless explicitly defined

UPDATE public.recipes
SET serving_size_yield = NULL,
    serving_yield_unit = NULL
WHERE serving_size_yield = 1
  AND serving_yield_unit = 'x'
  AND serving_item IS NULL;


-- Also clear yields when serving_item is a placeholder like 'Buns' or 'serving'
UPDATE public.recipes
SET serving_size_yield = NULL,
    serving_yield_unit = NULL,
    serving_item = NULL
WHERE serving_item IS NOT NULL
  AND lower(btrim(serving_item)) IN ('buns','serving');


