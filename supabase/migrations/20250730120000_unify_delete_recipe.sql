-- Unify dish / preparation deletion into delete_recipe that safely removes orphaned components
-- Idempotent: drop existing funcs, recreate
-- SECURITY: search_path set to ''

BEGIN;

-- Wrapper for uuid_generate_v5 pointing to extensions schema (if missing)
DROP FUNCTION IF EXISTS public.uuid_generate_v5(uuid, text);
CREATE OR REPLACE FUNCTION public.uuid_generate_v5(namespace uuid, name text)
RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
    SELECT extensions.uuid_generate_v5(namespace, name);
$$;

-- 1. Core delete_recipe function ------------------------------------------------
DROP FUNCTION IF EXISTS public.delete_recipe(uuid);
CREATE OR REPLACE FUNCTION public.delete_recipe(p_recipe_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _comp uuid;
    _components uuid[];
BEGIN
    -- Prevent deletion if recipe is referenced as a component in other recipes
    IF EXISTS (
        SELECT 1 FROM public.recipe_components rc WHERE rc.component_id = p_recipe_id
    ) THEN
        RAISE EXCEPTION 'Cannot delete recipe %, it is used in other recipes', p_recipe_id;
    END IF;

    -- Capture component ids belonging to this recipe
    SELECT array_agg(DISTINCT component_id) INTO _components
      FROM public.recipe_components rc
     WHERE rc.recipe_id = p_recipe_id;

    -- Remove links from recipe_components
    DELETE FROM public.recipe_components rc WHERE rc.recipe_id = p_recipe_id;

    -- Remove the recipe row itself
    DELETE FROM public.recipes r WHERE r.recipe_id = p_recipe_id;

    -- Iterate over components and delete if truly orphaned
    FOREACH _comp IN ARRAY _components LOOP
        PERFORM public.handle_component_deletion_check(_comp);
    END LOOP;
END;
$$;

-- 2. Thin wrappers for backward-compat functions --------------------
DROP FUNCTION IF EXISTS public.delete_dish(uuid);
CREATE OR REPLACE FUNCTION public.delete_dish(p_recipe_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM public.delete_recipe(p_recipe_id);
END;
$$;

DROP FUNCTION IF EXISTS public.delete_preparation(uuid);
CREATE OR REPLACE FUNCTION public.delete_preparation(p_recipe_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM public.delete_recipe(p_recipe_id);
END;
$$;

COMMIT;
