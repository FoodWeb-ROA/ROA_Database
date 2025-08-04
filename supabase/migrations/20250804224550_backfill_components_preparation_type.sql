-- migrate:up
-- Ensure all components linked to a recipe are marked as 'Preparation'
-- This is required for environments that applied earlier versions of the
-- schema redesign migration before the fix was added.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'components' AND column_name = 'recipe_id'
    ) THEN
        UPDATE public.components
        SET    component_type = 'Preparation'
        WHERE  recipe_id IS NOT NULL
          AND  component_type <> 'Preparation';
    END IF;
END $$;

-- Re-validate the check constraint in case it was left NOT VALID
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage 
        WHERE table_name = 'components' AND constraint_name = 'components_recipe_id_check'
    ) THEN
        ALTER TABLE public.components VALIDATE CONSTRAINT components_recipe_id_check;
    END IF;
END $$;

-- migrate:down
-- No down migration required since this only corrects data.
