-- Adapt legacy functions/triggers to unified recipes/components/recipe_components schema
-- Idempotent; safe on repeated runs

BEGIN;

-- 0) Drop legacy triggers/functions from old tables if they still exist ---------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND n.nspname = 'public' AND c.relname = 'dish_components'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS after_dish_component_deleted_trigger ON public.dish_components';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND n.nspname = 'public' AND c.relname = 'preparation_components'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS after_preparation_component_deleted_trigger ON public.preparation_components';
  END IF;
END $$;
DROP FUNCTION IF EXISTS public.after_dish_component_deleted_trigger_fn();
DROP FUNCTION IF EXISTS public.after_preparation_component_deleted_trigger_fn();

-- Legacy delete triggers no longer needed in unified schema
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND n.nspname = 'public' AND c.relname = 'dishes'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS delete_dish_and_orphaned_components_trigger ON public.dishes';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND n.nspname = 'public' AND c.relname = 'preparations'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS delete_preparation_and_orphaned_components_trigger ON public.preparations';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND n.nspname = 'public' AND c.relname = 'recipes'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS delete_dish_and_orphaned_components_trigger ON public.recipes';
    EXECUTE 'DROP TRIGGER IF EXISTS delete_preparation_and_orphaned_components_trigger ON public.recipes';
  END IF;
END $$;
-- Now that all potential trigger attachments have been dropped, remove the legacy functions
DROP FUNCTION IF EXISTS public.delete_dish_and_orphaned_components_trigger_fn();
DROP FUNCTION IF EXISTS public.delete_preparation_and_orphaned_components_trigger_fn();

-- Fingerprint triggers on legacy tables
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND n.nspname = 'public' AND c.relname = 'preparation_components'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_components_update_fingerprint ON public.preparation_components';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND n.nspname = 'public' AND c.relname = 'preparations'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_preparations_set_fingerprint ON public.preparations';
  END IF;
END $$;

-- Legacy helper (RPC) no longer used
DROP FUNCTION IF EXISTS public.get_components_for_preparations(uuid[]);

-- Legacy process-deleted helper (ingredient_id-based)
DROP FUNCTION IF EXISTS public.process_deleted_ingredients();

-- 1) Orphan cleanup helper ------------------------------------------------------
DROP FUNCTION IF EXISTS public.handle_component_deletion_check(uuid);
CREATE OR REPLACE FUNCTION public.handle_component_deletion_check(p_component_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    is_used boolean;
    is_prep boolean;
BEGIN
    -- Is this component a preparation? (preparations have a recipe mapped via components.recipe_id)
    SELECT EXISTS (
        SELECT 1 FROM public.components c WHERE c.component_id = p_component_id AND c.recipe_id IS NOT NULL
    ) INTO is_prep;

    -- Never delete components that are preparations
    IF is_prep THEN
        RETURN;
    END IF;

    -- For raw ingredients, delete only if unused everywhere
    SELECT EXISTS (
        SELECT 1 FROM public.recipe_components rc WHERE rc.component_id = p_component_id
    ) INTO is_used;

    IF NOT is_used THEN
        RAISE NOTICE 'Orphaned raw component (id: %) deleted.', p_component_id;
        DELETE FROM public.components WHERE component_id = p_component_id;
    END IF;
END;
$$;

-- Backward-compat shim for any lingering callers
DROP FUNCTION IF EXISTS public.handle_ingredient_deletion_check(uuid);
CREATE OR REPLACE FUNCTION public.handle_ingredient_deletion_check(p_ingredient_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM public.handle_component_deletion_check(p_ingredient_id);
END;
$$;

-- Ensure any existing trigger using the function is removed before dropping it
DROP TRIGGER IF EXISTS after_recipe_component_deleted ON public.recipe_components;
DROP FUNCTION IF EXISTS public.process_deleted_components();
CREATE OR REPLACE FUNCTION public.process_deleted_components()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    p_component_id uuid;
BEGIN
    -- Session-lifetime scratch table; survives for the tx, disappears on commit.
    CREATE TEMP TABLE IF NOT EXISTS deleted_components_temp
    ( component_id uuid PRIMARY KEY )
    ON COMMIT DROP;

    -- Collect ids from the statement, ignore duplicates.
    INSERT INTO deleted_components_temp(component_id)
    SELECT DISTINCT ot.component_id
    FROM OLD_TABLE AS ot
    ON CONFLICT (component_id) DO NOTHING;

    -- Process every unique id collected so far.
    FOR p_component_id IN
        SELECT dct.component_id FROM deleted_components_temp dct
    LOOP
        PERFORM public.handle_component_deletion_check(p_component_id);
    END LOOP;

    RETURN NULL;
END;
$$;

CREATE TRIGGER after_recipe_component_deleted
AFTER DELETE ON public.recipe_components
REFERENCING OLD TABLE AS old_table
FOR EACH STATEMENT EXECUTE FUNCTION public.process_deleted_components();

-- Drop trigger first to remove dependency, then recreate function and trigger
DROP TRIGGER IF EXISTS enforce_unit_constraint ON public.recipe_components;
DROP FUNCTION IF EXISTS public.check_unit_for_preparations();
CREATE OR REPLACE FUNCTION public.check_unit_for_preparations()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    is_child_prep boolean;
BEGIN
    -- Only enforce when the child component is itself a preparation
    SELECT EXISTS (
        SELECT 1 FROM public.components c WHERE c.component_id = NEW.component_id AND c.recipe_id IS NOT NULL
    ) INTO is_child_prep;

    IF is_child_prep THEN
        IF NEW.unit IS DISTINCT FROM 'prep'::public.unit THEN
            RAISE EXCEPTION 'Components that are preparations must use the "prep" unit. Got: %', NEW.unit;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- Ensure the constraint trigger is attached to unified table
CREATE TRIGGER enforce_unit_constraint
BEFORE INSERT OR UPDATE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.check_unit_for_preparations();

-- Update/compute fingerprints for a preparation identified by its component id
-- Drop dependent trigger before replacing function
DROP TRIGGER IF EXISTS trg_recipe_components_update_fingerprint ON public.recipe_components;
DROP FUNCTION IF EXISTS public.update_preparation_fingerprint(uuid);
CREATE OR REPLACE FUNCTION public.update_preparation_fingerprint(_prep_component_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    _plain text;
    _fp    uuid;
    _recipe_id uuid;
BEGIN
    -- Locate the recipe that corresponds to this preparation component id
    SELECT c.recipe_id INTO _recipe_id
    FROM public.components c
    WHERE c.component_id = _prep_component_id AND c.recipe_id IS NOT NULL
    LIMIT 1;

    IF _recipe_id IS NULL THEN
        RETURN; -- Not a preparation
    END IF;

    /* Canonical plain fingerprint */
    SELECT
        COALESCE(
            string_agg(public.slug_simple(c.name), '-' ORDER BY public.slug_simple(c.name)),
            'empty'
        )
        || '|' ||
        regexp_replace(
            lower(array_to_string(r.directions, ' ')),
            '[^a-z]+', ' ', 'g'
        )
      INTO _plain
      FROM public.recipes r
      LEFT JOIN public.recipe_components rc
             ON rc.recipe_id = r.recipe_id
      LEFT JOIN public.components c
             ON c.component_id = rc.component_id
     WHERE r.recipe_id = _recipe_id
     GROUP BY r.directions;

    _plain := trim(_plain);

    /* UUID-v5 over that exact string */
    _fp := public.uuid_generate_v5(public.fp_namespace(), _plain);

    UPDATE public.recipes
       SET fingerprint       = _fp,
           fingerprint_plain = _plain
     WHERE recipe_id = _recipe_id
       AND (fingerprint IS DISTINCT FROM _fp OR fingerprint_plain IS DISTINCT FROM _plain);
END;
$$;

-- Trigger: when recipe_components change, update parent preparation fingerprint
-- Ensure trigger is dropped before function replacement
DROP TRIGGER IF EXISTS trg_recipe_components_update_fingerprint ON public.recipe_components;
DROP FUNCTION IF EXISTS public.tg_recipe_components_update_fingerprint();
CREATE OR REPLACE FUNCTION public.tg_recipe_components_update_fingerprint()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    _rid uuid;
    _prep_component_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        _rid := OLD.recipe_id;
    ELSE
        _rid := NEW.recipe_id;
    END IF;

    -- Only applies to preparations; map recipe_id -> preparation component id
    SELECT c.component_id INTO _prep_component_id
    FROM public.components c
    WHERE c.recipe_id = _rid AND c.recipe_id IS NOT NULL;

    IF _prep_component_id IS NOT NULL THEN
        PERFORM public.update_preparation_fingerprint(_prep_component_id);
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

CREATE TRIGGER trg_recipe_components_update_fingerprint
AFTER INSERT OR DELETE OR UPDATE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.tg_recipe_components_update_fingerprint();

-- Drop dependent trigger before replacing function
DROP TRIGGER IF EXISTS trg_recipes_set_fingerprint ON public.recipes;
DROP TRIGGER IF EXISTS tg_recipes_set_fingerprint ON public.recipes;
DROP FUNCTION IF EXISTS public.tg_recipes_set_fingerprint();
CREATE OR REPLACE FUNCTION public.tg_recipes_set_fingerprint()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.update_preparation_fingerprint(c.component_id)
  FROM public.components c
  WHERE c.recipe_id = NEW.recipe_id AND c.recipe_id IS NOT NULL
  LIMIT 1;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_recipes_set_fingerprint
AFTER INSERT OR UPDATE ON public.recipes
FOR EACH ROW EXECUTE FUNCTION public.tg_recipes_set_fingerprint();

-- Drop dependent triggers before replacing function
DROP TRIGGER IF EXISTS trg_prevent_prep_cycle ON public.recipe_components;
DROP TRIGGER IF EXISTS prevent_prep_cycle ON public.recipe_components;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND n.nspname = 'public' AND c.relname = 'preparations'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_prevent_prep_cycle ON public.preparations';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND n.nspname = 'public' AND c.relname = 'preparation_components'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_prevent_prep_cycle ON public.preparation_components';
  END IF;
END $$;
DROP FUNCTION IF EXISTS public.prevent_preparation_cycle();
CREATE OR REPLACE FUNCTION public.prevent_preparation_cycle()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    _parent_prep_component_id uuid;
    _child_recipe_id uuid;
    _cycle_found boolean := FALSE;
BEGIN
    -- Ignore deletes
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    -- Only run when the component we’re adding is itself a preparation
    SELECT c.recipe_id INTO _child_recipe_id
    FROM public.components c
    WHERE c.component_id = NEW.component_id AND c.recipe_id IS NOT NULL;

    IF _child_recipe_id IS NULL THEN
        RETURN NEW; -- child is not a preparation
    END IF;

    -- If the parent is not a preparation, cycles cannot occur (dishes are not components)
    SELECT c.component_id INTO _parent_prep_component_id
    FROM public.components c
    WHERE c.recipe_id = NEW.recipe_id AND c.recipe_id IS NOT NULL;

    IF _parent_prep_component_id IS NULL THEN
        RETURN NEW;
    END IF;

    /*
      Walk up the ancestor chain:
      starting from recipes that currently include the parent preparation as a component
      and climbing via recipe_components.recipe_id → recipes.preparation_id.
    */
    WITH RECURSIVE ancestors AS (
        -- Direct parents that include the parent preparation component
        SELECT rc.recipe_id                           AS ancestor_recipe_id,
               ARRAY[rc.recipe_id]                    AS path
        FROM   public.recipe_components rc
        WHERE  rc.component_id = _parent_prep_component_id

        UNION ALL

        SELECT rc2.recipe_id,
               a.path || rc2.recipe_id
        FROM   ancestors a
        JOIN   public.components cp ON cp.recipe_id = a.ancestor_recipe_id AND cp.recipe_id IS NOT NULL
        JOIN   public.recipe_components rc2
               ON rc2.component_id = cp.component_id
        WHERE  NOT rc2.recipe_id = ANY(a.path)
    )
    SELECT TRUE
      INTO _cycle_found
      FROM ancestors
     WHERE ancestor_recipe_id = _child_recipe_id
     LIMIT 1;

    IF _cycle_found THEN
        RAISE EXCEPTION
          'Cycle detected: adding preparation % as a component of recipe % would create a loop',
          NEW.component_id, NEW.recipe_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_prevent_prep_cycle
BEFORE INSERT OR UPDATE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.prevent_preparation_cycle();


