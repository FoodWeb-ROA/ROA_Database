-- Fix functions that referenced old schema names after the schema redesign
-- Idempotent: always drop previous versions first, then recreate against new tables
-- NOTE: all DEFINER functions are created with empty search_path for security

BEGIN;

-- Ensure uuid_generate_v5 wrapper exists (extension functions live in extensions schema)
DROP FUNCTION IF EXISTS public.uuid_generate_v5(uuid, text);
CREATE OR REPLACE FUNCTION public.uuid_generate_v5(namespace uuid, name text)
RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
    SELECT extensions.uuid_generate_v5(namespace, name);
$$;

-- =============================================
-- 1. delete_dish  → now deletes recipe + components
-- =============================================
DROP FUNCTION IF EXISTS public.delete_dish(uuid);
CREATE OR REPLACE FUNCTION public.delete_dish(p_recipe_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Remove components belonging to the recipe
    DELETE FROM public.recipe_components rc
     WHERE rc.recipe_id = p_recipe_id;

    -- Delete the main recipe row (expecting it to be of type 'Dish')
    DELETE FROM public.recipes r
     WHERE r.recipe_id = p_recipe_id;
END;
$$;

-- =============================================
-- 2. delete_preparation – mirror behaviour for preparation recipes
-- =============================================
DROP FUNCTION IF EXISTS public.delete_preparation(uuid);
CREATE OR REPLACE FUNCTION public.delete_preparation(p_preparation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    prep_name text;
BEGIN
    SELECT r.recipe_name INTO prep_name
      FROM public.recipes r
     WHERE r.recipe_id = p_preparation_id;

    -- Remove any recipe_components that reference this preparation as a component
    DELETE FROM public.recipe_components rc
     WHERE rc.component_id = p_preparation_id;

    -- Finally delete the preparation itself
    DELETE FROM public.recipes r
     WHERE r.recipe_id = p_preparation_id;

    RAISE NOTICE 'Preparation % deleted', COALESCE(prep_name, p_preparation_id::text);
END;
$$;

-- =============================================
-- 3. Remove obsolete handle_ingredient_deletion_check (replaced by handle_component_deletion_check)
-- =============================================
DROP FUNCTION IF EXISTS public.handle_ingredient_deletion_check(uuid);

-- =============================================
-- 4. update_preparation_fingerprint – fix column reference & ensure correct logic
-- =============================================
DROP FUNCTION IF EXISTS public.update_preparation_fingerprint(uuid);
CREATE OR REPLACE FUNCTION public.update_preparation_fingerprint(_recipe_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    _plain text;
    _fp    uuid;
BEGIN
    -- Only execute for preparation-type recipes
    IF NOT EXISTS (
        SELECT 1 FROM public.recipes r
         WHERE r.recipe_id = _recipe_id
           AND r.recipe_type = 'Preparation'
    ) THEN
        RETURN;
    END IF;

    SELECT COALESCE(
             string_agg(public.slug_simple(c.name), '-' ORDER BY public.slug_simple(c.name)),
             'empty'
           ) || '|' ||
           regexp_replace(lower(array_to_string(r.directions, ' ')), '[^a-z]+', ' ', 'g')
      INTO _plain
      FROM public.recipes r
      LEFT JOIN public.recipe_components rc ON rc.recipe_id = r.recipe_id
      LEFT JOIN public.components        c  ON c.component_id = rc.component_id
     WHERE r.recipe_id = _recipe_id
     GROUP BY r.directions;

    _fp := public.uuid_generate_v5(public.fp_namespace(), _plain);

    UPDATE public.recipes
       SET fingerprint       = _fp,
           fingerprint_plain = _plain
     WHERE recipe_id = _recipe_id
       AND (fingerprint IS DISTINCT FROM _fp OR fingerprint_plain IS DISTINCT FROM _plain);
END;
$$;

COMMIT;
