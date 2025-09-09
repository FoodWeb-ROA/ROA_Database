-- Drop any defaults on yield columns to avoid implicit 1 x
ALTER TABLE public.recipes ALTER COLUMN serving_size_yield DROP DEFAULT;
ALTER TABLE public.recipes ALTER COLUMN serving_yield_unit DROP DEFAULT;

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


