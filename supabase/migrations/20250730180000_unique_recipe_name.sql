-- Ensure unique recipe names per kitchen (dishes & preparations)
-- Migration generated 2025-07-30

BEGIN;

-- Add a unique constraint on (recipe_name, kitchen_id) if it doesn't already exist.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'recipes_name_kitchen_id_unique') THEN
        ALTER TABLE public.recipes
            ADD CONSTRAINT recipes_name_kitchen_id_unique
            UNIQUE (recipe_name, kitchen_id);
    END IF;
END $$;

COMMIT;
