-- Fix remaining issues: constraint errors and RLS policy

-- 1. Fix RLS policy for recipe_components to be more permissive
DROP POLICY IF EXISTS "recipe_components_insert" ON "public"."recipe_components";
DROP POLICY IF EXISTS "recipe_components_update" ON "public"."recipe_components";
DROP POLICY IF EXISTS "recipe_components_delete" ON "public"."recipe_components";
DROP POLICY IF EXISTS "recipe_components_select" ON "public"."recipe_components";

-- Create more permissive policies - user just needs access to the recipe's kitchen
CREATE POLICY "recipe_components_insert" ON "public"."recipe_components" 
FOR INSERT TO "authenticated" 
WITH CHECK (
  -- User must be a member of the recipe's kitchen
  EXISTS (
    SELECT 1 FROM "public"."recipes" "r"
    WHERE "r"."recipe_id" = "recipe_components"."recipe_id"
    AND "public"."is_user_kitchen_member"(auth.uid(), "r"."kitchen_id")
  )
);

CREATE POLICY "recipe_components_update" ON "public"."recipe_components" 
FOR UPDATE TO "authenticated" 
USING (
  -- User must be a member of the recipe's kitchen
  EXISTS (
    SELECT 1 FROM "public"."recipes" "r"
    WHERE "r"."recipe_id" = "recipe_components"."recipe_id"
    AND "public"."is_user_kitchen_member"(auth.uid(), "r"."kitchen_id")
  )
)
WITH CHECK (
  -- Same check for the new values
  EXISTS (
    SELECT 1 FROM "public"."recipes" "r"
    WHERE "r"."recipe_id" = "recipe_components"."recipe_id"
    AND "public"."is_user_kitchen_member"(auth.uid(), "r"."kitchen_id")
  )
);

CREATE POLICY "recipe_components_delete" ON "public"."recipe_components" 
FOR DELETE TO "authenticated" 
USING (
  -- User must be a member of the recipe's kitchen
  EXISTS (
    SELECT 1 FROM "public"."recipes" "r"
    WHERE "r"."recipe_id" = "recipe_components"."recipe_id"
    AND "public"."is_user_kitchen_member"(auth.uid(), "r"."kitchen_id")
  )
);

CREATE POLICY "recipe_components_select" ON "public"."recipe_components" 
FOR SELECT TO "authenticated" 
USING (
  -- User must be a member of the recipe's kitchen
  EXISTS (
    SELECT 1 FROM "public"."recipes" "r"
    WHERE "r"."recipe_id" = "recipe_components"."recipe_id"
    AND "public"."is_user_kitchen_member"(auth.uid(), "r"."kitchen_id")
  )
);

-- 2. Make the name enforcement triggers more defensive to prevent cascading updates
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

    -- Only update component if there's actually a difference AND it won't cause conflicts
    -- Skip updates during transactions that might cause cascading issues
    IF TG_OP = 'UPDATE' AND OLD.recipe_name = NEW.recipe_name AND OLD.kitchen_id = NEW.kitchen_id THEN
      -- No change needed
      RETURN NULL;
    END IF;

    -- Defensive update: only if it won't conflict and there's a real change
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

    -- Only update recipe if there's actually a difference AND it won't cause conflicts
    -- Skip updates during transactions that might cause cascading issues
    IF TG_OP = 'UPDATE' AND OLD.name = NEW.name AND OLD.kitchen_id = NEW.kitchen_id THEN
      -- No change needed
      RETURN NULL;
    END IF;

    -- Defensive update: only if it won't conflict and there's a real change
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
