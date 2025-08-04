-- Add `item` column to `recipe_components` and constrain its usage

-- The column is intended ONLY for raw ingredient components measured in counts (unit = 'x').
-- Constraint: if `unit` = 'x' then `item` must be NOT NULL, otherwise `item` must be NULL.
-- We cannot reference component_type from `components` table directly in a CHECK constraint, so
-- that validation will be enforced at the application level (frontend / API layer).

ALTER TABLE public.recipe_components
ADD COLUMN item text;

-- Trigger to enforce: only unit 'x' may have item set (item optional); other units must have NULL item

-- Helper function
CREATE OR REPLACE FUNCTION public.recipe_components_item_unit_guard()
RETURNS trigger AS $$
BEGIN
  IF NEW.unit <> 'x' AND NEW.item IS NOT NULL THEN
    RAISE EXCEPTION 'item can only be set when unit = ''x''.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger
CREATE TRIGGER trg_recipe_components_item_unit
BEFORE INSERT OR UPDATE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.recipe_components_item_unit_guard();
