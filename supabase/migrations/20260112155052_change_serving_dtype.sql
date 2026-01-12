-- Change serving_or_yield_amount from integer to numeric to support fractional servings
-- This fixes the "invalid input syntax for type integer" error when inserting decimal values like "2.5"

-- Step 1: Drop the trigger that depends on this column
DROP TRIGGER IF EXISTS trg_recalculate_parent_amounts_on_yield_change ON public.recipes;

-- Step 2: Change the column type to support decimals
ALTER TABLE public.recipes 
ALTER COLUMN serving_or_yield_amount TYPE numeric(10,2) USING serving_or_yield_amount::numeric;

-- Step 3: Recreate the trigger (function already supports numeric types)
CREATE TRIGGER trg_recalculate_parent_amounts_on_yield_change 
  BEFORE UPDATE OF serving_or_yield_unit, serving_or_yield_amount 
  ON public.recipes 
  FOR EACH ROW 
  WHEN (
    (OLD.serving_or_yield_unit IS DISTINCT FROM NEW.serving_or_yield_unit) OR 
    (OLD.serving_or_yield_amount IS DISTINCT FROM NEW.serving_or_yield_amount)
  )
  EXECUTE FUNCTION public.recalculate_parent_amounts_on_yield_change();

-- Add comment to document the change
COMMENT ON COLUMN public.recipes.serving_or_yield_amount IS 'Serving size or yield amount (supports decimal values for fractional servings)';