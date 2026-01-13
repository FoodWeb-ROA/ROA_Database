-- Fix prevent_preparation_cycle to catch direct self-references
-- Bug: Original trigger only checked ancestor chain, missing the simplest case where a prep includes itself directly

CREATE OR REPLACE FUNCTION "public"."prevent_preparation_cycle"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
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

    -- Only run when the component we're adding is itself a preparation
    SELECT c.recipe_id INTO _child_recipe_id
    FROM public.components c
    WHERE c.component_id = NEW.component_id AND c.recipe_id IS NOT NULL;

    IF _child_recipe_id IS NULL THEN
        RETURN NEW; -- child is not a preparation
    END IF;

    -- CRITICAL FIX: Check for direct self-reference first (prep includes itself)
    IF NEW.recipe_id = _child_recipe_id THEN
        RAISE EXCEPTION
          'Cycle detected: preparation cannot include itself (recipe_id=%, component_id=%)',
          NEW.recipe_id, NEW.component_id;
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
