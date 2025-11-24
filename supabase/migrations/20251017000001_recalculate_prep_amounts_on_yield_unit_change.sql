-- Migration: Recalculate parent recipe amounts when preparation yield unit measurement type changes
-- This handles the case where a preparation's yield unit is changed from one measurement type to another
-- (e.g., weight to volume, count to weight), requiring parent recipe component amounts to be recalculated
--
-- IMPORTANT: This migration REPLACES the prep_yield_change_guard that previously blocked yield unit changes.
-- Instead of blocking, we now recalculate parent amounts to maintain correct proportions.

-- Function to get measurement type for a unit
-- Uses the existing unit_kind function from the schema
CREATE OR REPLACE FUNCTION get_unit_measurement_type(unit_abbr public.unit)
RETURNS TEXT AS $$
BEGIN
  -- Use the existing unit_kind function that's already defined in the schema
  RETURN public.unit_kind(unit_abbr);
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to recalculate parent amounts when prep yield unit changes
CREATE OR REPLACE FUNCTION recalculate_parent_amounts_on_yield_change()
RETURNS TRIGGER AS $$
DECLARE
  old_measurement_type TEXT;
  new_measurement_type TEXT;
  parent_record RECORD;
  old_yield_amount NUMERIC;
  new_yield_amount NUMERIC;
  old_component_amount NUMERIC;
  new_component_amount NUMERIC;
  ratio NUMERIC;
BEGIN
  -- Only process if this is a preparation (not a dish)
  IF NEW.recipe_type != 'Preparation' THEN
    RETURN NEW;
  END IF;

  -- Only process if yield unit or yield amount changed
  IF OLD.serving_or_yield_unit = NEW.serving_or_yield_unit 
     AND OLD.serving_or_yield_amount = NEW.serving_or_yield_amount THEN
    RETURN NEW;
  END IF;

  -- Get measurement types for old and new units
  old_measurement_type := get_unit_measurement_type(OLD.serving_or_yield_unit);
  new_measurement_type := get_unit_measurement_type(NEW.serving_or_yield_unit);

  -- Only recalculate if measurement types differ (weight vs volume vs count)
  IF old_measurement_type IS NULL OR new_measurement_type IS NULL THEN
    RAISE WARNING 'Could not determine measurement types for units: % -> %', 
      OLD.serving_or_yield_unit, NEW.serving_or_yield_unit;
    RETURN NEW;
  END IF;

  IF old_measurement_type = new_measurement_type THEN
    -- Same measurement type, no recalculation needed (just unit conversion)
    RETURN NEW;
  END IF;

  -- Get yield amounts
  old_yield_amount := OLD.serving_or_yield_amount;
  new_yield_amount := NEW.serving_or_yield_amount;

  IF old_yield_amount IS NULL OR old_yield_amount = 0 
     OR new_yield_amount IS NULL OR new_yield_amount = 0 THEN
    RAISE WARNING 'Invalid yield amounts for recipe %: old=%, new=%', 
      NEW.recipe_id, old_yield_amount, new_yield_amount;
    RETURN NEW;
  END IF;

  RAISE NOTICE 'Recalculating parent amounts for prep % (% -> %): yield % % -> % %',
    NEW.recipe_name,
    old_measurement_type,
    new_measurement_type,
    old_yield_amount,
    OLD.serving_or_yield_unit,
    new_yield_amount,
    NEW.serving_or_yield_unit;

  -- Find all parent recipes that use this preparation
  FOR parent_record IN
    SELECT 
      rc.recipe_id,
      rc.component_id,
      rc.amount as current_amount,
      rc.unit as current_unit,
      r.recipe_name as parent_name
    FROM recipe_components rc
    JOIN components c ON c.component_id = rc.component_id
    JOIN recipes r ON r.recipe_id = rc.recipe_id
    WHERE c.recipe_id = NEW.recipe_id  -- This component references our prep
      AND rc.amount IS NOT NULL
      AND rc.amount > 0
  LOOP
    old_component_amount := parent_record.current_amount;
    
    -- Calculate ratio: (old_amount_in_parent / old_yield) * new_yield
    -- This maintains the same proportion of the preparation
    ratio := old_component_amount / old_yield_amount;
    new_component_amount := ratio * new_yield_amount;

    RAISE NOTICE '  Updating % in %: % % -> % % (ratio: %)',
      NEW.recipe_name,
      parent_record.parent_name,
      old_component_amount,
      parent_record.current_unit,
      new_component_amount,
      NEW.serving_or_yield_unit,
      ratio;

    -- Update the parent recipe component
    UPDATE recipe_components
    SET 
      amount = new_component_amount,
      unit = NEW.serving_or_yield_unit,
      updated_at = NOW()
    WHERE recipe_id = parent_record.recipe_id
      AND component_id = parent_record.component_id;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop the old guard trigger that blocked yield unit changes
DROP TRIGGER IF EXISTS trg_prep_yield_change_guard ON public.recipes;

-- Create new BEFORE UPDATE trigger to recalculate parent amounts
-- This runs BEFORE the update, allowing us to modify parent recipes before the change is committed
DROP TRIGGER IF EXISTS trg_recalculate_parent_amounts_on_yield_change ON public.recipes;
CREATE TRIGGER trg_recalculate_parent_amounts_on_yield_change
  BEFORE UPDATE OF serving_or_yield_unit, serving_or_yield_amount ON public.recipes
  FOR EACH ROW
  WHEN (OLD.serving_or_yield_unit IS DISTINCT FROM NEW.serving_or_yield_unit 
        OR OLD.serving_or_yield_amount IS DISTINCT FROM NEW.serving_or_yield_amount)
  EXECUTE FUNCTION recalculate_parent_amounts_on_yield_change();

-- Add comment explaining the trigger
COMMENT ON TRIGGER trg_recalculate_parent_amounts_on_yield_change ON public.recipes IS 
  'Automatically recalculates parent recipe component amounts when a preparation''s yield unit measurement type changes (e.g., weight to volume). This REPLACES the old prep_yield_change_guard that blocked such changes. Instead of blocking, we now recalculate to maintain correct proportions.';
