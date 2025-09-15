-- Fix RLS policy for recipe_components to check both component and recipe kitchen access

-- Drop existing policies
DROP POLICY IF EXISTS "recipe_components_insert" ON "public"."recipe_components";
DROP POLICY IF EXISTS "recipe_components_update" ON "public"."recipe_components";
DROP POLICY IF EXISTS "recipe_components_delete" ON "public"."recipe_components";
DROP POLICY IF EXISTS "recipe_components_select" ON "public"."recipe_components";

-- Create new policies that check both component and recipe kitchen membership
CREATE POLICY "recipe_components_insert" ON "public"."recipe_components" 
FOR INSERT TO "authenticated" 
WITH CHECK (
  -- User must be a member of both the component's kitchen AND the recipe's kitchen
  (EXISTS (
    SELECT 1 FROM "public"."components" "c"
    WHERE "c"."component_id" = "recipe_components"."component_id" 
    AND "public"."is_user_kitchen_member"(auth.uid(), "c"."kitchen_id")
  ))
  AND
  (EXISTS (
    SELECT 1 FROM "public"."recipes" "r"
    WHERE "r"."recipe_id" = "recipe_components"."recipe_id"
    AND "public"."is_user_kitchen_member"(auth.uid(), "r"."kitchen_id")
  ))
);

CREATE POLICY "recipe_components_update" ON "public"."recipe_components" 
FOR UPDATE TO "authenticated" 
USING (
  -- User must be a member of both the component's kitchen AND the recipe's kitchen
  (EXISTS (
    SELECT 1 FROM "public"."components" "c"
    WHERE "c"."component_id" = "recipe_components"."component_id" 
    AND "public"."is_user_kitchen_member"(auth.uid(), "c"."kitchen_id")
  ))
  AND
  (EXISTS (
    SELECT 1 FROM "public"."recipes" "r"
    WHERE "r"."recipe_id" = "recipe_components"."recipe_id"
    AND "public"."is_user_kitchen_member"(auth.uid(), "r"."kitchen_id")
  ))
)
WITH CHECK (
  -- Same check for the new values
  (EXISTS (
    SELECT 1 FROM "public"."components" "c"
    WHERE "c"."component_id" = "recipe_components"."component_id" 
    AND "public"."is_user_kitchen_member"(auth.uid(), "c"."kitchen_id")
  ))
  AND
  (EXISTS (
    SELECT 1 FROM "public"."recipes" "r"
    WHERE "r"."recipe_id" = "recipe_components"."recipe_id"
    AND "public"."is_user_kitchen_member"(auth.uid(), "r"."kitchen_id")
  ))
);

CREATE POLICY "recipe_components_delete" ON "public"."recipe_components" 
FOR DELETE TO "authenticated" 
USING (
  -- User must be a member of both the component's kitchen AND the recipe's kitchen
  (EXISTS (
    SELECT 1 FROM "public"."components" "c"
    WHERE "c"."component_id" = "recipe_components"."component_id" 
    AND "public"."is_user_kitchen_member"(auth.uid(), "c"."kitchen_id")
  ))
  AND
  (EXISTS (
    SELECT 1 FROM "public"."recipes" "r"
    WHERE "r"."recipe_id" = "recipe_components"."recipe_id"
    AND "public"."is_user_kitchen_member"(auth.uid(), "r"."kitchen_id")
  ))
);

CREATE POLICY "recipe_components_select" ON "public"."recipe_components" 
FOR SELECT TO "authenticated" 
USING (
  -- User must be a member of both the component's kitchen AND the recipe's kitchen
  (EXISTS (
    SELECT 1 FROM "public"."components" "c"
    WHERE "c"."component_id" = "recipe_components"."component_id" 
    AND "public"."is_user_kitchen_member"(auth.uid(), "c"."kitchen_id")
  ))
  AND
  (EXISTS (
    SELECT 1 FROM "public"."recipes" "r"
    WHERE "r"."recipe_id" = "recipe_components"."recipe_id"
    AND "public"."is_user_kitchen_member"(auth.uid(), "r"."kitchen_id")
  ))
);
