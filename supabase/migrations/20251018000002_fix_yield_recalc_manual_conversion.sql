-- Migration: Fix yield unit recalculation with manual unit conversion helpers
-- Replaces postgresql-unit extension with custom conversion logic
-- Example: If old amount is 1000g and old yield is 1kg, ratio should be 1.0, not 1000.0

-- Helper function to determine unit measurement type
CREATE OR REPLACE FUNCTION get_unit_kind(unit_val public.unit)
RETURNS TEXT AS $$
BEGIN
  CASE unit_val
    WHEN 'mg', 'g', 'kg', 'oz', 'lb' THEN
      RETURN 'mass';
    WHEN 'ml', 'l', 'tsp', 'tbsp', 'cup', 'pt', 'qt', 'gal' THEN
      RETURN 'volume';
    WHEN 'x' THEN
      RETURN 'count';
    WHEN 'prep' THEN
      RETURN 'preparation';
    ELSE
      RETURN NULL;
  END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Helper function to convert amount from one unit to another
-- Returns NULL if units are incompatible (different measurement types)
CREATE OR REPLACE FUNCTION convert_amount_safe(
  amount_val NUMERIC,
  from_unit public.unit,
  to_unit public.unit
)
RETURNS NUMERIC AS $$
DECLARE
  from_kind TEXT;
  to_kind TEXT;
  -- Conversion factors to base units (g for mass, ml for volume)
  from_to_base NUMERIC;
  to_to_base NUMERIC;
  base_amount NUMERIC;
BEGIN
  -- Get measurement types
  from_kind := get_unit_kind(from_unit);
  to_kind := get_unit_kind(to_unit);
  
  -- Check if units are valid
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
  
  -- If same unit, no conversion needed
  IF from_unit = to_unit THEN
    RETURN amount_val;
  END IF;
  
  -- Handle count units (no conversion)
  IF from_kind = 'count' THEN
    RETURN amount_val;
  END IF;
  
  -- Handle preparation units (no conversion)
  IF from_kind = 'preparation' THEN
    RETURN amount_val;
  END IF;
  
  -- Mass conversions (base unit: g)
  IF from_kind = 'mass' THEN
    from_to_base := CASE from_unit
      WHEN 'mg' THEN 0.001
      WHEN 'g' THEN 1.0
      WHEN 'kg' THEN 1000.0
      WHEN 'oz' THEN 28.3495
      WHEN 'lb' THEN 453.592
      ELSE NULL
    END;
    
    to_to_base := CASE to_unit
      WHEN 'mg' THEN 0.001
      WHEN 'g' THEN 1.0
      WHEN 'kg' THEN 1000.0
      WHEN 'oz' THEN 28.3495
      WHEN 'lb' THEN 453.592
      ELSE NULL
    END;
    
    IF from_to_base IS NULL OR to_to_base IS NULL THEN
      RAISE WARNING 'Unsupported mass unit: % or %', from_unit, to_unit;
      RETURN amount_val;
    END IF;
    
    -- Convert: amount * from_factor / to_factor
    base_amount := amount_val * from_to_base;
    RETURN ROUND(base_amount / to_to_base, 4);
  END IF;
  
  -- Volume conversions (base unit: ml)
  IF from_kind = 'volume' THEN
    from_to_base := CASE from_unit
      WHEN 'ml' THEN 1.0
      WHEN 'l' THEN 1000.0
      WHEN 'tsp' THEN 4.92892
      WHEN 'tbsp' THEN 14.7868
      WHEN 'cup' THEN 236.588
      WHEN 'pt' THEN 473.176
      WHEN 'qt' THEN 946.353
      WHEN 'gal' THEN 3785.41
      ELSE NULL
    END;
    
    to_to_base := CASE to_unit
      WHEN 'ml' THEN 1.0
      WHEN 'l' THEN 1000.0
      WHEN 'tsp' THEN 4.92892
      WHEN 'tbsp' THEN 14.7868
      WHEN 'cup' THEN 236.588
      WHEN 'pt' THEN 473.176
      WHEN 'qt' THEN 946.353
      WHEN 'gal' THEN 3785.41
      ELSE NULL
    END;
    
    IF from_to_base IS NULL OR to_to_base IS NULL THEN
      RAISE WARNING 'Unsupported volume unit: % or %', from_unit, to_unit;
      RETURN amount_val;
    END IF;
    
    -- Convert: amount * from_factor / to_factor
    base_amount := amount_val * from_to_base;
    RETURN ROUND(base_amount / to_to_base, 4);
  END IF;
  
  -- Fallback: return original amount
  RAISE WARNING 'Unit conversion not implemented for kind: %', from_kind;
  RETURN amount_val;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

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
  old_measurement_type := get_unit_kind(OLD.serving_yield_unit);
  new_measurement_type := get_unit_kind(NEW.serving_yield_unit);

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

-- Add comments explaining the functions
COMMENT ON FUNCTION get_unit_kind(public.unit) IS
  'Returns the measurement type (mass, volume, count, preparation) for a given unit enum value.';

COMMENT ON FUNCTION convert_amount_safe(NUMERIC, public.unit, public.unit) IS
  'Safely converts an amount from one unit to another using manual conversion factors.
  Returns NULL if units are incompatible (different measurement types).
  Handles count and preparation units by returning the original amount.
  Uses g as base unit for mass, ml as base unit for volume.';

COMMENT ON FUNCTION recalculate_parent_amounts_on_yield_change() IS 
  'Recalculates parent recipe component amounts when a preparation''s yield unit measurement type changes. 
  Now properly converts component amounts to yield units before calculating ratios using manual conversion helpers.
  Example: 1000g component with 1kg yield correctly calculates ratio as 1.0, not 1000.0';
