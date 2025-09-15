-- Fix trigger cascade issues that cause duplicate constraint violations during recipe updates

-- The bidirectional name enforcement triggers can cause cascading updates and race conditions.
-- Modify them to be more defensive and avoid unnecessary updates.

CREATE OR REPLACE FUNCTION "public"."enforce_prep_name_kitchen_match_from_recipes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW.recipe_type = 'Preparation' THEN
    -- Ensure a matching preparation component exists
    PERFORM 1 FROM public.components c WHERE c.recipe_id = NEW.recipe_id AND c.component_type = 'Preparation';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Preparation recipe must have a matching component (name/kitchen match enforcement)';
    END IF;

    -- Only update component if there's actually a difference to avoid cascading updates
    -- Also add a check to prevent constraint violations
    UPDATE public.components c
       SET name       = NEW.recipe_name,
           kitchen_id = NEW.kitchen_id
     WHERE c.recipe_id = NEW.recipe_id
       AND c.component_type = 'Preparation'
       AND (c.name IS DISTINCT FROM NEW.recipe_name OR c.kitchen_id IS DISTINCT FROM NEW.kitchen_id)
       -- Defensive check: only update if the new name won't conflict
       AND NOT EXISTS (
         SELECT 1 FROM public.recipes r2 
         WHERE r2.recipe_name = NEW.recipe_name 
         AND r2.kitchen_id = NEW.kitchen_id 
         AND r2.recipe_id != NEW.recipe_id
       );
  END IF;
  RETURN NULL; -- for constraint triggers
END;
$$;

CREATE OR REPLACE FUNCTION "public"."enforce_prep_name_kitchen_match_from_components"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW.component_type = 'Preparation' THEN
    IF NEW.recipe_id IS NULL THEN
      RAISE EXCEPTION 'Preparation component must have recipe_id';
    END IF;
    -- Ensure target recipe exists and is a Preparation
    PERFORM 1 FROM public.recipes r WHERE r.recipe_id = NEW.recipe_id AND r.recipe_type = 'Preparation';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Preparation component must reference a Preparation recipe';
    END IF;

    -- Only update recipe if there's actually a difference to avoid cascading updates
    -- Also add a check to prevent constraint violations
    UPDATE public.recipes r
       SET recipe_name = NEW.name,
           kitchen_id  = NEW.kitchen_id
     WHERE r.recipe_id = NEW.recipe_id
       AND r.recipe_type = 'Preparation'
       AND (r.recipe_name IS DISTINCT FROM NEW.name OR r.kitchen_id IS DISTINCT FROM NEW.kitchen_id)
       -- Defensive check: only update if the new name won't conflict
       AND NOT EXISTS (
         SELECT 1 FROM public.recipes r2 
         WHERE r2.recipe_name = NEW.name 
         AND r2.kitchen_id = NEW.kitchen_id 
         AND r2.recipe_id != r.recipe_id
       );
  END IF;
  RETURN NULL; -- for constraint triggers
END;
$$;
