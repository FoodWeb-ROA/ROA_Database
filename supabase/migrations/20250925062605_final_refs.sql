CREATE OR REPLACE FUNCTION public.rc_prep_unit_guard()
RETURNS trigger 
LANGUAGE plpgsql 
SET "search_path" TO ''
AS $$
DECLARE
  child_recipe_id uuid;
  yield_unit public.unit;
BEGIN
  -- Only enforce if component is a preparation (has a recipe_id)
  SELECT c.recipe_id INTO child_recipe_id
  FROM public.components c
  WHERE c.component_id = NEW.component_id AND c.recipe_id IS NOT NULL;

  IF child_recipe_id IS NULL THEN
    RETURN NEW; -- raw ingredient
  END IF;

  SELECT r.serving_or_yield_unit INTO yield_unit
  FROM public.recipes r WHERE r.recipe_id = child_recipe_id;

  IF yield_unit IS NULL THEN
    -- Should be normalized to 'x' via defaults; double-guard
    RAISE EXCEPTION 'Preparation yield must be defined';
  END IF;

  -- If yield is count, parent usage must be count
  IF yield_unit = 'x' AND NEW.unit <> 'x' THEN
    RAISE EXCEPTION 'When preparation yield is count (x), parent unit must be x';
  END IF;

  -- If yield is mass/volume, parent usage must match measurement kind
  IF yield_unit <> 'x' THEN
    IF public.unit_kind(NEW.unit) IS DISTINCT FROM public.unit_kind(yield_unit) THEN
      RAISE EXCEPTION 'Parent unit % incompatible with preparation yield %', NEW.unit, yield_unit;
    END IF;
  END IF;

  -- item is only allowed with count
  IF NEW.unit <> 'x' AND NEW.item IS NOT NULL THEN
    RAISE EXCEPTION 'item can only be set when unit = x';
  END IF;

  RETURN NEW;
END;$$;

-- 3c) Guard against yield unit measurement-type changes when preparation is in use
CREATE OR REPLACE FUNCTION public.prep_yield_change_guard()
RETURNS trigger 
LANGUAGE plpgsql 
SET "search_path" TO ''
AS $$
DECLARE
  existing_kind text;
  new_kind text;
  in_use boolean;
BEGIN
  IF NEW.recipe_type <> 'Preparation' THEN
    RETURN NEW;
  END IF;

  IF NEW.serving_or_yield_unit IS DISTINCT FROM OLD.serving_or_yield_unit THEN
    -- Force amount to 1 when unit is x
    IF NEW.serving_or_yield_unit = 'x' AND NEW.serving_or_yield_amount <> 1 THEN
      NEW.serving_or_yield_amount := 1;
    END IF;

    existing_kind := public.unit_kind(OLD.serving_or_yield_unit);
    new_kind := public.unit_kind(NEW.serving_or_yield_unit);

    SELECT EXISTS (
      SELECT 1 FROM public.recipe_components rc
      JOIN public.components c ON c.component_id = rc.component_id
      WHERE c.recipe_id = NEW.recipe_id
    ) INTO in_use;

    IF in_use AND existing_kind IS DISTINCT FROM new_kind THEN
      RAISE EXCEPTION 'Cannot change preparation yield measurement type while it is used in other recipes';
    END IF;
  END IF;
  RETURN NEW;
END;$$;
