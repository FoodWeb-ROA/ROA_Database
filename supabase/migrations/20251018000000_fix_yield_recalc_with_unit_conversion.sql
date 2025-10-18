-- Migration: Fix yield unit recalculation to respect base yield units during division
-- Uses postgresql-unit extension for proper unit conversions
-- Example: If old amount is 1000g and old yield is 1kg, ratio should be 1.0, not 1000.0

-- Enable postgresql-unit extension for unit conversion support
CREATE EXTENSION IF NOT EXISTS unit;

-- Helper function to convert amount from one unit to another using postgresql-unit
-- Returns NULL if units are incompatible (different measurement types)
CREATE OR REPLACE FUNCTION convert_amount_safe(
  amount_val NUMERIC,
  from_unit TEXT,
  to_unit TEXT
)
RETURNS NUMERIC AS $$
DECLARE
  from_kind TEXT;
  to_kind TEXT;
  converted_val NUMERIC;
BEGIN
  -- Check if units are of the same measurement type
  from_kind := public.unit_kind(from_unit);
  to_kind := public.unit_kind(to_unit);
  
  IF from_kind IS NULL OR to_kind IS NULL THEN
    RAISE WARNING 'Unknown unit type: % or %', from_unit, to_unit;
    RETURN NULL;
  END IF;
  
  -- Only convert if same measurement type
  IF from_kind != to_kind THEN
    RAISE WARNING 'Cannot convert between different measurement types: % (%) -> % (%)', 
      from_unit, from_kind, to_unit, to_kind;
    RETURN NULL;
  END IF;
  
  -- Handle count units specially (no conversion needed if same type)
  IF from_kind = 'count' THEN
    -- Count units don't convert, just return original amount
    RETURN amount_val;
  END IF;
  
  -- Try to convert using postgresql-unit extension
  BEGIN
    -- Format: "amount from_unit" and convert to "to_unit"
    -- Example: "1000 g" to "kg" -> 1
    EXECUTE format('SELECT (''%s %s''::unit @ ''%s'')::numeric', 
                   amount_val, from_unit, to_unit)
    INTO converted_val;
    RETURN converted_val;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Unit conversion failed: % % -> %. Error: %', 
      amount_val, from_unit, to_unit, SQLERRM;
    -- Fallback: return original amount (no conversion)
    RETURN amount_val;
  END;
END;
$$ LANGUAGE plpgsql STABLE;

-- Updated function to recalculate parent amounts with proper unit conversion
CREATE OR REPLACE FUNCTION recalculate_parent_amounts_on_yield_change()
RETURNS TRIGGER AS $$
DECLARE
  old_measurement_type TEXT;
  new_measurement_type TEXT;
  parent_record RECORD;
  old_yield_amount NUMERIC;
  new_yield_amount NUMERIC;
  old_component_amount NUMERIC;
  old_component_amount_converted NUMERIC;
  new_component_amount NUMERIC;
  ratio NUMERIC;
BEGIN
  -- Only process if this is a preparation (not a dish)
  IF NEW.recipe_type != 'Preparation' THEN
    RETURN NEW;
  END IF;

  -- Only process if yield unit or yield amount changed
  IF OLD.serving_yield_unit = NEW.serving_yield_unit 
     AND OLD.serving_size_yield = NEW.serving_size_yield THEN
    RETURN NEW;
  END IF;

  -- Get measurement types for old and new units
  old_measurement_type := public.unit_kind(OLD.serving_yield_unit);
  new_measurement_type := public.unit_kind(NEW.serving_yield_unit);

  -- Only recalculate if measurement types differ (weight vs volume vs count)
  IF old_measurement_type IS NULL OR new_measurement_type IS NULL THEN
    RAISE WARNING 'Could not determine measurement types for units: % -> %', 
      OLD.serving_yield_unit, NEW.serving_yield_unit;
    RETURN NEW;
  END IF;

  IF old_measurement_type = new_measurement_type THEN
    -- Same measurement type, no recalculation needed (just unit conversion)
    RETURN NEW;
  END IF;

  -- Get yield amounts
  old_yield_amount := OLD.serving_size_yield;
  new_yield_amount := NEW.serving_size_yield;

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
    OLD.serving_yield_unit,
    new_yield_amount,
    NEW.serving_yield_unit;

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
    
    -- Convert old component amount to old yield unit for proper ratio calculation
    -- This ensures we're comparing apples to apples (e.g., 1000g -> 1kg before dividing by 1kg)
    old_component_amount_converted := convert_amount_safe(
      old_component_amount,
      parent_record.current_unit,
      OLD.serving_yield_unit
    );
    
    IF old_component_amount_converted IS NULL THEN
      -- Conversion failed, use original amount (may be inaccurate but better than blocking)
      RAISE WARNING 'Could not convert % % to % for ratio calculation, using original amount',
        old_component_amount, parent_record.current_unit, OLD.serving_yield_unit;
      old_component_amount_converted := old_component_amount;
    END IF;
    
    -- Calculate ratio: (converted_amount_in_parent / old_yield) * new_yield
    -- This maintains the same proportion of the preparation
    ratio := old_component_amount_converted / old_yield_amount;
    new_component_amount := ratio * new_yield_amount;

    RAISE NOTICE '  Updating % in %: % % (converted: % %) -> % % (ratio: %)',
      NEW.recipe_name,
      parent_record.parent_name,
      old_component_amount,
      parent_record.current_unit,
      old_component_amount_converted,
      OLD.serving_yield_unit,
      new_component_amount,
      NEW.serving_yield_unit,
      ratio;

    -- Update the parent recipe component
    UPDATE recipe_components
    SET 
      amount = new_component_amount,
      unit = NEW.serving_yield_unit,
      updated_at = NOW()
    WHERE recipe_id = parent_record.recipe_id
      AND component_id = parent_record.component_id;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add comment explaining the fix
COMMENT ON FUNCTION recalculate_parent_amounts_on_yield_change() IS 
  'Recalculates parent recipe component amounts when a preparation''s yield unit measurement type changes. 
  Now properly converts component amounts to yield units before calculating ratios using postgresql-unit extension.
  Example: 1000g component with 1kg yield correctly calculates ratio as 1.0, not 1000.0';

COMMENT ON FUNCTION convert_amount_safe(NUMERIC, TEXT, TEXT) IS
  'Safely converts an amount from one unit to another using postgresql-unit extension.
  Returns NULL if units are incompatible (different measurement types).
  Handles count units specially by returning the original amount.';
