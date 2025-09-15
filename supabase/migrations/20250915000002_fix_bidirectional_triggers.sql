-- Fix bidirectional trigger cascade that causes constraint violations during recipe updates
-- The issue occurs when updating a recipe name triggers the bidirectional name enforcement triggers

-- The root cause: when user chooses "Replace", we update the existing recipe with the same name it already has
-- This triggers the prep name enforcement triggers, which attempt cascading updates and cause constraint violations

-- 1. Improve the recipes->components trigger to be more defensive
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

    -- Only update component if there's actually a difference
    -- More defensive: check if the component already has the correct name and kitchen
    IF TG_OP = 'UPDATE' THEN
      -- Check if any component actually needs updating
      PERFORM 1 FROM public.components c 
      WHERE c.recipe_id = NEW.recipe_id 
      AND c.component_type = 'Preparation'
      AND (c.name IS DISTINCT FROM NEW.recipe_name OR c.kitchen_id IS DISTINCT FROM NEW.kitchen_id);
      
      -- If no component needs updating, skip entirely
      IF NOT FOUND THEN
        RETURN NULL;
      END IF;
    END IF;

    -- Defensive update: only update components that actually need it
    UPDATE public.components c
       SET name       = NEW.recipe_name,
           kitchen_id = NEW.kitchen_id
     WHERE c.recipe_id = NEW.recipe_id
       AND c.component_type = 'Preparation'
       AND (c.name IS DISTINCT FROM NEW.recipe_name OR c.kitchen_id IS DISTINCT FROM NEW.kitchen_id);
  END IF;
  
  RETURN NULL; -- for constraint triggers
END;
$$;

-- 2. Improve the components->recipes trigger to be more defensive
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

    -- Only update recipe if there's actually a difference
    -- More defensive: check if the recipe already has the correct name and kitchen
    IF TG_OP = 'UPDATE' THEN
      -- Check if the recipe actually needs updating
      PERFORM 1 FROM public.recipes r 
      WHERE r.recipe_id = NEW.recipe_id 
      AND r.recipe_type = 'Preparation'
      AND (r.recipe_name IS DISTINCT FROM NEW.name OR r.kitchen_id IS DISTINCT FROM NEW.kitchen_id);
      
      -- If recipe doesn't need updating, skip entirely
      IF NOT FOUND THEN
        RETURN NULL;
      END IF;
    END IF;

    -- Defensive update: only update recipe if it actually needs it
    UPDATE public.recipes r
       SET recipe_name = NEW.name,
           kitchen_id  = NEW.kitchen_id
     WHERE r.recipe_id = NEW.recipe_id
       AND r.recipe_type = 'Preparation'
       AND (r.recipe_name IS DISTINCT FROM NEW.name OR r.kitchen_id IS DISTINCT FROM NEW.kitchen_id);
  END IF;
  
  RETURN NULL; -- for constraint triggers
END;
$$;
