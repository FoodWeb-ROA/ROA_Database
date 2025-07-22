-- migrate:up
BEGIN;

-- 4.1 ENUMs ---------------------------------------------------------
-- Create new enum types if they do not already exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'recipe_type') THEN
        CREATE TYPE public.recipe_type AS ENUM ('Dish', 'Preparation');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'component_type') THEN
        CREATE TYPE public.component_type AS ENUM ('Raw_Ingredient', 'Preparation');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'unit') THEN
        CREATE TYPE public.unit AS ENUM ('mg', 'g', 'kg', 'ml', 'l', 'oz', 'lb', 'tsp', 'tbsp', 'cup', 'pcs', 'prep');
    END IF;
END $$;

-- 4.2 Table rename & recipe_type column ----------------------------
-- Rename dishes -> recipes
ALTER TABLE IF EXISTS public.dishes RENAME TO recipes;

-- Add recipe_type column (defaults to Dish) if it does not yet exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'recipes' AND column_name = 'recipe_type'
    ) THEN
        ALTER TABLE public.recipes
            ADD COLUMN recipe_type public.recipe_type NOT NULL DEFAULT 'Dish';
    END IF;
END $$;

-- 4.3 Components ----------------------------------------------------
-- Rename ingredients -> components
ALTER TABLE IF EXISTS public.ingredients RENAME TO components;

-- Add component_type column (defaults to Raw_Ingredient)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'components' AND column_name = 'component_type'
    ) THEN
        ALTER TABLE public.components
            ADD COLUMN component_type public.component_type NOT NULL DEFAULT 'Raw_Ingredient';
    END IF;
END $$;

-- 4.4 New join table ------------------------------------------------
CREATE TABLE IF NOT EXISTS public.recipe_components (
    recipe_id     uuid REFERENCES public.recipes(recipe_id) ON DELETE CASCADE,
    component_id  uuid REFERENCES public.components(component_id) ON DELETE RESTRICT,
    amount        numeric NOT NULL,
    unit          public.unit NOT NULL,
    notes         text,
    PRIMARY KEY (recipe_id, component_id)
);

-- 4.5 Backfill data -------------------------------------------------
-- (1) preparations → recipes (only if preparations table exists)
INSERT INTO public.recipes (recipe_id, recipe_name, kitchen_id, created_at, updated_at, recipe_type, total_time, cooking_notes, directions, num_servings, image_updated_at)
SELECT p.preparation_id,
       i.name            AS recipe_name,
       i.kitchen_id,
       p.created_at,
       p.updated_at,
       'Preparation'::public.recipe_type,
       p.total_time,
       p.cooking_notes,
       p.directions,
       1                 AS num_servings,
       p.image_updated_at
FROM public.preparations p
JOIN public.components i ON i.ingredient_id = p.preparation_id
ON CONFLICT (recipe_id) DO NOTHING;

-- (2) Mark existing dish rows (those without recipe_type)
UPDATE public.recipes
SET recipe_type = 'Dish'
WHERE recipe_type IS NULL;

-- (3) Backfill dish_components into recipe_components
INSERT INTO public.recipe_components (recipe_id, component_id, amount, unit, notes)
SELECT dc.dish_id,
       dc.ingredient_id,
       dc.amount,
       u.abbreviation::public.unit,
       NULL
FROM public.dish_components dc
JOIN public.units u ON u.unit_id = dc.unit_id
ON CONFLICT DO NOTHING;

-- (4) Backfill preparation_components into recipe_components
INSERT INTO public.recipe_components (recipe_id, component_id, amount, unit, notes)
SELECT pc.preparation_id,
       pc.ingredient_id,
       pc.amount,
       u.abbreviation::public.unit,
       NULL
FROM public.preparation_components pc
JOIN public.units u ON u.unit_id = pc.unit_id
ON CONFLICT DO NOTHING;

-- 4.6 Cleanup old tables -------------------------------------------
-- Disable dependent triggers temporarily
ALTER TABLE IF EXISTS public.dish_components DISABLE TRIGGER ALL;
ALTER TABLE IF EXISTS public.preparation_components DISABLE TRIGGER ALL;

DROP TABLE IF EXISTS public.preparation_components CASCADE;
DROP TABLE IF EXISTS public.dish_components CASCADE;
DROP TABLE IF EXISTS public.preparations     CASCADE;
DROP TABLE IF EXISTS public.units            CASCADE;

-- 4.7 Indexes -------------------------------------------------------
CREATE INDEX IF NOT EXISTS recipe_components_unique_idx
  ON public.recipe_components (recipe_id, component_id);
CREATE INDEX IF NOT EXISTS recipe_name_trgm_idx
  ON public.recipes USING gin (lower(recipe_name) gin_trgm_ops);

-- 4.8 TODO: RLS & Trigger Updates ----------------------------------
-- Copy and adapt existing policies from dishes -> recipes
-- NOTE: These require manual verification and may need to be adjusted outside of this script.

COMMIT;

-- migrate:down
BEGIN;

-- Reverse operations (basic) ---------------------------------------
DROP TABLE IF EXISTS public.recipe_components;

ALTER TABLE IF EXISTS public.components DROP COLUMN IF EXISTS component_type;
ALTER TABLE IF EXISTS public.components RENAME TO ingredients;

ALTER TABLE IF EXISTS public.recipes DROP COLUMN IF EXISTS recipe_type;
ALTER TABLE IF EXISTS public.recipes RENAME TO dishes;

-- Drop enums (only if safe) ----------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'unit') THEN
        DROP TYPE public.unit;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'component_type') THEN
        DROP TYPE public.component_type;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'recipe_type') THEN
        DROP TYPE public.recipe_type;
    END IF;
END $$;

COMMIT;
