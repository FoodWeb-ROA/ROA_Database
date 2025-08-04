-- migrate:up
-- Patch for remote databases that were provisioned before the full schema redesign
-- and therefore lack the recipe_id column / correct component_type values.

-- 1. Add recipe_id column if not present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'components' AND column_name = 'recipe_id'
    ) THEN
        ALTER TABLE public.components ADD COLUMN recipe_id uuid;
    END IF;
END $$;

-- 2. Back-fill recipe_id from preparations table (component_id == preparation_id)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'components' AND column_name = 'recipe_id'
    ) THEN
        UPDATE public.components c
        SET    recipe_id = r.recipe_id
        FROM   public.recipes r
        WHERE  r.recipe_id = c.component_id
          AND  r.recipe_type = 'Preparation'
          AND  c.recipe_id IS NULL;
    END IF;
END $$;

-- 3. Ensure component_type = 'Preparation' where recipe_id is set
UPDATE public.components
SET    component_type = 'Preparation'
WHERE  recipe_id IS NOT NULL
  AND  component_type <> 'Preparation';

-- 4. Add/validate FK & check constraints
DO $$
BEGIN
    -- FK
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'components_recipe_id_fk'
    ) THEN
        ALTER TABLE public.components
            ADD CONSTRAINT components_recipe_id_fk
            FOREIGN KEY (recipe_id) REFERENCES public.recipes(recipe_id)
            ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED NOT VALID;
    END IF;

    -- Check constraint
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'components_recipe_id_check'
    ) THEN
        ALTER TABLE public.components
            ADD CONSTRAINT components_recipe_id_check
            CHECK ( (component_type = 'Preparation' AND recipe_id IS NOT NULL) OR
                    (component_type <> 'Preparation' AND recipe_id IS NULL) ) NOT VALID;
    END IF;

    -- Validate both (safe even if already valid)
    ALTER TABLE public.components VALIDATE CONSTRAINT components_recipe_id_fk;
    ALTER TABLE public.components VALIDATE CONSTRAINT components_recipe_id_check;
END $$;

-- migrate:down
-- No down migration (data-repair).
