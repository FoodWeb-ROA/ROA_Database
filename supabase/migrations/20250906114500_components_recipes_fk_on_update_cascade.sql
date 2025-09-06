-- Ensure FK between components.recipe_id -> recipes.recipe_id cascades on delete and update
-- Scope: preparations linkage (components with recipe_id set)
-- Idempotent: finds existing FK and replaces it with ON DELETE/UPDATE CASCADE

BEGIN;

-- 1) Drop existing FK (if any) from components.recipe_id to recipes.recipe_id
DO $$
DECLARE
    fk_name text;
BEGIN
    SELECT c.conname INTO fk_name
    FROM   pg_constraint c
    WHERE  c.conrelid = 'public.components'::regclass
      AND  c.contype  = 'f'
      AND  c.confrelid = 'public.recipes'::regclass
      AND  EXISTS (
             SELECT 1
             FROM   pg_attribute a
             WHERE  a.attrelid = c.conrelid
               AND  a.attname  = 'recipe_id'
           );

    IF fk_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE public.components DROP CONSTRAINT %I', fk_name);
    END IF;
END $$;

-- 2) Recreate FK with ON DELETE CASCADE and ON UPDATE CASCADE
ALTER TABLE public.components
    ADD CONSTRAINT components_recipe_id_fk
    FOREIGN KEY (recipe_id)
    REFERENCES public.recipes(recipe_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
    DEFERRABLE INITIALLY DEFERRED;

COMMIT;


