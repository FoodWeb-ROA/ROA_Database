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
        CREATE TYPE public.unit AS ENUM ('mg', 'g', 'kg', 'ml', 'l', 'oz', 'lb', 'tsp', 'tbsp', 'cup', 'x', 'prep');
    END IF;
END $$;

-- 4.2 Table rename & recipe_type column ----------------------------
-- Rename dishes -> recipes
ALTER TABLE IF EXISTS public.dishes RENAME TO recipes;

-- Rename primary & name columns for clarity
DO $$
BEGIN
    -- Only attempt to rename if the column exists (first run)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'recipes' AND column_name = 'dish_id'
    ) THEN
        ALTER TABLE public.recipes RENAME COLUMN dish_id TO recipe_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'recipes' AND column_name = 'dish_name'
    ) THEN
        ALTER TABLE public.recipes RENAME COLUMN dish_name TO recipe_name;
    END IF;
END $$;
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

-- 4.25 Serving metadata ---------------------------------------------
-- Add serving_unit enum column (default 'x') and backfill from old units table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'recipes' AND column_name = 'serving_unit'
    ) THEN
        ALTER TABLE public.recipes ADD COLUMN serving_unit public.unit NOT NULL DEFAULT 'x';
    END IF;
END $$;

-- Relax NOT NULL constraints on legacy serving_* columns so inserts from preparations succeed
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='recipes' AND column_name='serving_unit_id') THEN
        ALTER TABLE public.recipes ALTER COLUMN serving_unit_id DROP NOT NULL;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='recipes' AND column_name='serving_size') THEN
        ALTER TABLE public.recipes ALTER COLUMN serving_size DROP NOT NULL;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='recipes' AND column_name='serving_item') THEN
        ALTER TABLE public.recipes ALTER COLUMN serving_item DROP NOT NULL;
    END IF;
END $$;

-- Backfill serving_unit from old foreign key before we drop units table
UPDATE public.recipes r
SET    serving_unit = lower(u.abbreviation)::public.unit
FROM   public.units u
WHERE  r.serving_unit_id = u.unit_id;

-- Add check: serving_item only populated when serving_unit = 'x'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name = 'recipes_serving_item_requires_x'
    ) THEN
        ALTER TABLE public.recipes
            ADD CONSTRAINT recipes_serving_item_requires_x
            CHECK (serving_item IS NULL OR serving_unit = 'x');
    END IF;
END $$;

-- 4.3 Components ----------------------------------------------------
-- Rename ingredients -> components
ALTER TABLE IF EXISTS public.ingredients RENAME TO components;

-- Rename primary key column to component_id for consistency
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'components' AND column_name = 'ingredient_id'
    ) THEN
        ALTER TABLE public.components RENAME COLUMN ingredient_id TO component_id;
    END IF;
END $$;
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

-- Sanity check – ensure recipe_id column now exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns WHERE table_name = 'recipes' AND column_name = 'recipe_id'
    ) THEN
        -- If rename failed for any reason, fall back to creating the column and copying values
        ALTER TABLE public.recipes ADD COLUMN recipe_id uuid;
        UPDATE public.recipes SET recipe_id = dish_id WHERE recipe_id IS NULL;
        ALTER TABLE public.recipes ALTER COLUMN recipe_id SET NOT NULL;
        -- Re-point primary key
        ALTER TABLE public.recipes DROP CONSTRAINT IF EXISTS recipes_pkey;
        ALTER TABLE public.recipes ADD PRIMARY KEY (recipe_id);
        -- Optional: drop old dish_id if desired
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
       (COALESCE(p.total_time, 30) * INTERVAL '1 minute') AS total_time,
       p.cooking_notes,
       p.directions,
       1                 AS num_servings,
       p.image_updated_at
FROM public.preparations p
JOIN public.components i ON i.component_id = p.preparation_id
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
       lower(u.abbreviation)::public.unit,
       NULL
FROM public.dish_components dc
JOIN public.units u ON u.unit_id = dc.unit_id
ON CONFLICT DO NOTHING;

-- (4) Backfill preparation_components into recipe_components
INSERT INTO public.recipe_components (recipe_id, component_id, amount, unit, notes)
SELECT pc.preparation_id,
       pc.ingredient_id,
       pc.amount,
       lower(u.abbreviation)::public.unit,
       NULL
FROM public.preparation_components pc
JOIN public.units u ON u.unit_id = pc.unit_id
ON CONFLICT DO NOTHING;

-- 4.55 Drop deprecated serving columns ------------------------------
-- Remove FK column and size/count columns now that data is migrated
ALTER TABLE IF EXISTS public.recipes DROP COLUMN IF EXISTS serving_unit_id;
ALTER TABLE IF EXISTS public.recipes DROP COLUMN IF EXISTS serving_size;
ALTER TABLE IF EXISTS public.recipes DROP COLUMN IF EXISTS num_servings;

-- 4.6 Cleanup old tables -------------------------------------------
-- Disable dependent triggers temporarily
ALTER TABLE IF EXISTS public.dish_components DISABLE TRIGGER USER;
ALTER TABLE IF EXISTS public.preparation_components DISABLE TRIGGER USER;

DROP TABLE IF EXISTS public.preparation_components CASCADE;
DROP TABLE IF EXISTS public.dish_components CASCADE;
DROP TABLE IF EXISTS public.preparations     CASCADE;
DROP TABLE IF EXISTS public.units            CASCADE;

-- 4.7 Indexes -------------------------------------------------------
CREATE INDEX IF NOT EXISTS recipe_components_unique_idx
  ON public.recipe_components (recipe_id, component_id);
CREATE INDEX IF NOT EXISTS recipe_name_trgm_idx
  ON public.recipes USING gin (lower(recipe_name) gin_trgm_ops);

-- 4.8 RLS Policies -------------------------------------------------
-- Enable RLS on new/unified tables
ALTER TABLE IF EXISTS public.recipes          ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.components        ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.recipe_components ENABLE ROW LEVEL SECURITY;

-- Recipes (formerly dishes / preparations)
DROP POLICY IF EXISTS recipes_select ON public.recipes;
CREATE POLICY recipes_select ON public.recipes
FOR SELECT TO authenticated
USING ((auth.uid() IS NOT NULL) AND (EXISTS (SELECT 1 FROM public.kitchen_users ku WHERE ku.user_id = auth.uid() AND ku.kitchen_id = recipes.kitchen_id)));

DROP POLICY IF EXISTS recipes_insert ON public.recipes;
CREATE POLICY recipes_insert ON public.recipes
FOR INSERT TO authenticated
WITH CHECK ((auth.uid() IS NOT NULL) AND (EXISTS (SELECT 1 FROM public.kitchen_users ku WHERE ku.user_id = auth.uid() AND ku.kitchen_id = recipes.kitchen_id)));

DROP POLICY IF EXISTS recipes_update ON public.recipes;
CREATE POLICY recipes_update ON public.recipes
FOR UPDATE TO authenticated
USING  ((auth.uid() IS NOT NULL) AND (EXISTS (SELECT 1 FROM public.kitchen_users ku WHERE ku.user_id = auth.uid() AND ku.kitchen_id = recipes.kitchen_id)))
WITH CHECK ((auth.uid() IS NOT NULL) AND (EXISTS (SELECT 1 FROM public.kitchen_users ku WHERE ku.user_id = auth.uid() AND ku.kitchen_id = recipes.kitchen_id)));

DROP POLICY IF EXISTS recipes_delete ON public.recipes;
CREATE POLICY recipes_delete ON public.recipes
FOR DELETE TO authenticated
USING ((auth.uid() IS NOT NULL) AND (EXISTS (SELECT 1 FROM public.kitchen_users ku WHERE ku.user_id = auth.uid() AND ku.kitchen_id = recipes.kitchen_id)));

-- Components (formerly ingredients)
DROP POLICY IF EXISTS components_select ON public.components;
CREATE POLICY components_select ON public.components
FOR SELECT TO authenticated
USING ((auth.uid() IS NOT NULL) AND (EXISTS (SELECT 1 FROM public.kitchen_users ku WHERE ku.user_id = auth.uid() AND ku.kitchen_id = components.kitchen_id)));

DROP POLICY IF EXISTS components_insert ON public.components;
CREATE POLICY components_insert ON public.components
FOR INSERT TO authenticated
WITH CHECK ((auth.uid() IS NOT NULL) AND (EXISTS (SELECT 1 FROM public.kitchen_users ku WHERE ku.user_id = auth.uid() AND ku.kitchen_id = components.kitchen_id)));

DROP POLICY IF EXISTS components_update ON public.components;
CREATE POLICY components_update ON public.components
FOR UPDATE TO authenticated
USING  ((auth.uid() IS NOT NULL) AND (EXISTS (SELECT 1 FROM public.kitchen_users ku WHERE ku.user_id = auth.uid() AND ku.kitchen_id = components.kitchen_id)))
WITH CHECK ((auth.uid() IS NOT NULL) AND (EXISTS (SELECT 1 FROM public.kitchen_users ku WHERE ku.user_id = auth.uid() AND ku.kitchen_id = components.kitchen_id)));

DROP POLICY IF EXISTS components_delete ON public.components;
CREATE POLICY components_delete ON public.components
FOR DELETE TO authenticated
USING ((auth.uid() IS NOT NULL) AND (EXISTS (SELECT 1 FROM public.kitchen_users ku WHERE ku.user_id = auth.uid() AND ku.kitchen_id = components.kitchen_id)));

-- Recipe Components (formerly dish/preparation_components)
DROP POLICY IF EXISTS recipe_components_select ON public.recipe_components;
CREATE POLICY recipe_components_select ON public.recipe_components
FOR SELECT TO authenticated
USING ((auth.uid() IS NOT NULL) AND (EXISTS (
  SELECT 1 FROM public.kitchen_users ku
  JOIN public.components c ON c.component_id = recipe_components.component_id
  WHERE ku.user_id = auth.uid() AND ku.kitchen_id = c.kitchen_id)));

DROP POLICY IF EXISTS recipe_components_insert ON public.recipe_components;
CREATE POLICY recipe_components_insert ON public.recipe_components
FOR INSERT TO authenticated
WITH CHECK ((auth.uid() IS NOT NULL) AND (EXISTS (
  SELECT 1 FROM public.kitchen_users ku
  JOIN public.components c ON c.component_id = recipe_components.component_id
  WHERE ku.user_id = auth.uid() AND ku.kitchen_id = c.kitchen_id)));

DROP POLICY IF EXISTS recipe_components_update ON public.recipe_components;
CREATE POLICY recipe_components_update ON public.recipe_components
FOR UPDATE TO authenticated
USING ((auth.uid() IS NOT NULL) AND (EXISTS (
  SELECT 1 FROM public.kitchen_users ku
  JOIN public.components c ON c.component_id = recipe_components.component_id
  WHERE ku.user_id = auth.uid() AND ku.kitchen_id = c.kitchen_id)))
WITH CHECK ((auth.uid() IS NOT NULL) AND (EXISTS (
  SELECT 1 FROM public.kitchen_users ku
  JOIN public.components c ON c.component_id = recipe_components.component_id
  WHERE ku.user_id = auth.uid() AND ku.kitchen_id = c.kitchen_id)));

DROP POLICY IF EXISTS recipe_components_delete ON public.recipe_components;
CREATE POLICY recipe_components_delete ON public.recipe_components
FOR DELETE TO authenticated
USING ((auth.uid() IS NOT NULL) AND (EXISTS (
  SELECT 1 FROM public.kitchen_users ku
  JOIN public.components c ON c.component_id = recipe_components.component_id
  WHERE ku.user_id = auth.uid() AND ku.kitchen_id = c.kitchen_id)));

-- 4.9 Triggers ------------------------------------------------------
-- Attach handle_times triggers to new tables where needed
-- Only add if function exists and trigger absent
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_times') THEN
        PERFORM 1 FROM pg_trigger WHERE tgname = 'handle_times_tg' AND tgrelid = 'recipe_components'::regclass;
        IF NOT FOUND THEN
            CREATE TRIGGER handle_times_tg BEFORE INSERT OR UPDATE ON public.recipe_components
              FOR EACH ROW EXECUTE FUNCTION public.handle_times();
        END IF;
    END IF;
END $$;

-- 4.10 Functions & Additional Triggers ----------------------------
-- Helper to delete recipes gracefully and remove links
CREATE OR REPLACE FUNCTION public.delete_recipe(p_recipe_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    DELETE FROM public.recipe_components rc WHERE rc.recipe_id = p_recipe_id;
    DELETE FROM public.recipes r WHERE r.recipe_id = p_recipe_id;
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Error deleting recipe %: %', p_recipe_id, SQLERRM;
END;
$$;

-- Handle component orphaning (was handle_ingredient_deletion_check)
CREATE OR REPLACE FUNCTION public.handle_component_deletion_check(p_component_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    is_used_in_recipes boolean;
    is_preparation     boolean;
BEGIN
    SET search_path = public, pg_temp;

    SELECT EXISTS (SELECT 1 FROM public.recipe_components rc WHERE rc.component_id = p_component_id)
    INTO is_used_in_recipes;

    SELECT (component_type = 'Preparation') FROM public.components c WHERE c.component_id = p_component_id
    INTO is_preparation;

    IF is_preparation THEN
        RETURN; -- keep preparations even if orphaned
    END IF;

    IF NOT is_used_in_recipes THEN
        DELETE FROM public.components WHERE component_id = p_component_id;
    END IF;
END;
$$;

-- Process deleted components in bulk (was process_deleted_ingredients)
CREATE OR REPLACE FUNCTION public.process_deleted_components()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    p_component_id uuid;
BEGIN
    SET search_path = public, pg_temp;

    CREATE TEMP TABLE IF NOT EXISTS deleted_components_temp(component_id uuid PRIMARY KEY) ON COMMIT DROP;

    INSERT INTO deleted_components_temp(component_id)
    SELECT DISTINCT ot.component_id FROM OLD_TABLE ot ON CONFLICT (component_id) DO NOTHING;

    FOR p_component_id IN SELECT component_id FROM deleted_components_temp LOOP
        PERFORM public.handle_component_deletion_check(p_component_id);
    END LOOP;
    RETURN NULL;
END;
$$;

-- Prevent cycles: component cannot reference itself transitively (adapt prevent_preparation_cycle)
CREATE OR REPLACE FUNCTION public.prevent_preparation_cycle()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    _cycle_found boolean := false;
BEGIN
    -- Skip deletes
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    -- Only run when the component we are adding is itself a preparation
    IF NOT EXISTS (
        SELECT 1
        FROM public.components c
        WHERE c.component_id = NEW.component_id
          AND c.component_type = 'Preparation'
    ) THEN
        RETURN NEW; -- raw ingredients cannot create cycles
    END IF;

    /*
       Walk up the ancestor chain starting from the parent recipe (NEW.recipe_id).
       If we ever reach NEW.component_id we would create a loop.
    */
    WITH RECURSIVE ancestors AS (
        SELECT rc.recipe_id AS ancestor_id,
               ARRAY[rc.recipe_id] AS path
        FROM   public.recipe_components rc
        WHERE  rc.component_id = NEW.recipe_id

        UNION ALL

        SELECT rc.recipe_id,
               path || rc.recipe_id
        FROM   ancestors a
        JOIN   public.recipe_components rc
               ON rc.component_id = a.ancestor_id
        WHERE  NOT rc.recipe_id = ANY(path)
    )
    SELECT TRUE INTO _cycle_found
      FROM ancestors
     WHERE ancestor_id = NEW.component_id
     LIMIT 1;

    IF _cycle_found THEN
        RAISE EXCEPTION 'Cycle detected: adding preparation % as a component of % would create a loop', NEW.component_id, NEW.recipe_id;
    END IF;

    RETURN NEW;
END;
$$; -- cycle-prevention logic migrated from legacy

-- Unit enforcement for preparations (adapt check_unit_for_preparations)
CREATE OR REPLACE FUNCTION public.check_unit_for_preparations()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    comp_type public.component_type;
BEGIN
    SELECT component_type INTO comp_type FROM public.components WHERE component_id = NEW.component_id;
    IF comp_type = 'Preparation' AND NEW.unit <> 'prep' THEN
        RAISE EXCEPTION 'Components that are preparations must use unit = "prep". Provided %', NEW.unit;
    END IF;
    RETURN NEW;
END;
$$;

-- Triggers ----------------------------------------------------------
-- Bulk-orphan handling after component links deleted
DROP TRIGGER IF EXISTS after_recipe_component_deleted ON public.recipe_components;
CREATE TRIGGER after_recipe_component_deleted
AFTER DELETE ON public.recipe_components
REFERENCING OLD TABLE AS old_table
FOR EACH STATEMENT EXECUTE FUNCTION public.process_deleted_components();

-- Enforce unit enum for preparations
DROP TRIGGER IF EXISTS enforce_unit_constraint ON public.recipe_components;
CREATE TRIGGER enforce_unit_constraint
BEFORE INSERT OR UPDATE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.check_unit_for_preparations();

-- Prevent cycles for preparations
DROP TRIGGER IF EXISTS prevent_prep_cycle ON public.recipe_components;
CREATE TRIGGER prevent_prep_cycle
BEFORE INSERT OR UPDATE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.prevent_preparation_cycle();

-- 4.11 Fingerprint Helpers ----------------------------------------
-- UUID namespace constant (if not already present)
CREATE OR REPLACE FUNCTION public.fp_namespace()
RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
    SELECT '8e296b46-37c9-4a89-a5b7-000000000000'::uuid;
$$;

-- Simple slug helper (kept from legacy)
CREATE OR REPLACE FUNCTION public.slug_simple(p_input text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT regexp_replace(
           regexp_replace(lower(trim(p_input)), '[^a-z0-9]+', '-', 'g'),
           '(es|s)$', '', 'g'
         );
$$;

-- Update preparation fingerprint (now operates on recipes where recipe_type = 'Preparation')
DROP FUNCTION IF EXISTS public.update_preparation_fingerprint(uuid);
CREATE OR REPLACE FUNCTION public.update_preparation_fingerprint(_recipe_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    _plain text;
    _fp    uuid;
BEGIN
    -- Only run for preparations
    IF NOT EXISTS (SELECT 1 FROM public.recipes r WHERE r.recipe_id = _recipe_id AND r.recipe_type = 'Preparation') THEN
        RETURN;
    END IF;

    SELECT COALESCE(
             string_agg(slug_simple(c.component_name), '-' ORDER BY slug_simple(c.component_name)),
             'empty'
           ) || '|' ||
           regexp_replace(lower(array_to_string(r.directions, ' ')), '[^a-z]+', ' ', 'g')
      INTO _plain
      FROM public.recipes r
      LEFT JOIN public.recipe_components rc  ON rc.recipe_id   = r.recipe_id
      LEFT JOIN public.components        c   ON c.component_id = rc.component_id
     WHERE r.recipe_id = _recipe_id
     GROUP BY r.directions;

    _plain := trim(_plain);
    _fp := uuid_generate_v5(public.fp_namespace(), _plain);

    UPDATE public.recipes
       SET fingerprint       = _fp,
           fingerprint_plain = _plain
     WHERE recipe_id = _recipe_id
       AND (fingerprint IS DISTINCT FROM _fp OR fingerprint_plain IS DISTINCT FROM _plain);
END;
$$;

-- Trigger helper to refresh fingerprint when components change
CREATE OR REPLACE FUNCTION public.tg_components_update_fingerprint()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    _prep_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        _prep_id := OLD.recipe_id;
    ELSE
        _prep_id := NEW.recipe_id;
    END IF;

    PERFORM public.update_preparation_fingerprint(_prep_id);

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Trigger helper to refresh fingerprint when preparation itself changes (e.g., directions)
CREATE OR REPLACE FUNCTION public.tg_recipes_set_fingerprint()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    PERFORM public.update_preparation_fingerprint(NEW.recipe_id);
    RETURN NEW;
END;
$$;

-- Attach triggers ---------------------------------------------------
-- Components trigger
DROP TRIGGER IF EXISTS tg_recipe_components_update_fingerprint ON public.recipe_components;
CREATE TRIGGER tg_recipe_components_update_fingerprint
AFTER INSERT OR UPDATE OR DELETE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.tg_components_update_fingerprint();

-- Recipes trigger (only for preparations)
DROP TRIGGER IF EXISTS tg_recipes_set_fingerprint ON public.recipes;
CREATE TRIGGER tg_recipes_set_fingerprint
AFTER INSERT OR UPDATE OF directions ON public.recipes
FOR EACH ROW WHEN (NEW.recipe_type = 'Preparation')
EXECUTE FUNCTION public.tg_recipes_set_fingerprint();

COMMIT;

