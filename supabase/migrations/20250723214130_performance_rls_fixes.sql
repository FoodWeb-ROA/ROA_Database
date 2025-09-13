-- Performance: Wrap auth function calls in RLS policies with sub-selects
-- and consolidate duplicate permissive authenticated policies.
-- Migration generated 2025-07-23.

BEGIN;

-- Kitchen table -------------------------------------------------------
ALTER POLICY "Admins can update kitchen names"
    ON public.kitchen
    USING (
        EXISTS (
            SELECT 1
            FROM public.kitchen_users ku
            WHERE ku.user_id = (select auth.uid())
              AND ku.is_admin = true
              AND ku.kitchen_id = kitchen.kitchen_id
        )
    );

ALTER POLICY "Allow authenticated users to delete their kitchens where name m"
    ON public.kitchen
    USING (
        public.is_user_kitchen_member((select auth.uid()), kitchen_id)
        AND name = (select auth.email())
    );

ALTER POLICY "Allow authenticated users to update their kitchens where name m"
    ON public.kitchen
    USING (
        public.is_user_kitchen_member((select auth.uid()), kitchen_id)
        AND name = (select auth.email())
    );

-- Select policy already uses sub-select correctly, no change needed.

-- Kitchen_users table --------------------------------------------------
ALTER POLICY "Allow admin to add users to their kitchen"
    ON public.kitchen_users
    WITH CHECK ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

ALTER POLICY "Allow admin to remove other users from their kitchen"
    ON public.kitchen_users
    USING ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) AND user_id <> (select auth.uid()) );

ALTER POLICY "Allow user to leave a kitchen (safeguarded against last admin l"
    ON public.kitchen_users
    USING ( user_id = (select auth.uid()) AND NOT (is_admin = true AND public.count_kitchen_admins(kitchen_id) = 1) );

-- Kitchen_invites ------------------------------------------------------
ALTER POLICY "Kitchen admins can create invites for their kitchens"
    ON public.kitchen_invites
    WITH CHECK ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

ALTER POLICY "Kitchen admins can update invites for their kitchens"
    ON public.kitchen_invites
    USING ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

ALTER POLICY "Kitchen admins can view invites for their kitchens"
    ON public.kitchen_invites
    USING ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

-- Menu_section ---------------------------------------------------------
ALTER POLICY menu_section_delete ON public.menu_section
    USING ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

ALTER POLICY menu_section_insert ON public.menu_section
    WITH CHECK ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

ALTER POLICY menu_section_update ON public.menu_section
    USING ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

-- Users table ----------------------------------------------------------
ALTER POLICY "Enable delete access for the user based on their id"
    ON public.users
    USING ( user_id = (select auth.uid()) );

ALTER POLICY "Enable update access for the user based on their id"
    ON public.users
    USING ( user_id = (select auth.uid()) );

-- Recipes & Components -------------------------------------------------
-- wrapper helper
ALTER POLICY dishes_delete ON public.recipes
    USING ( public.is_user_kitchen_member((select auth.uid()), kitchen_id) );
ALTER POLICY dishes_insert ON public.recipes
    WITH CHECK ( public.is_user_kitchen_member((select auth.uid()), kitchen_id) );
ALTER POLICY dishes_update ON public.recipes
    USING ( public.is_user_kitchen_member((select auth.uid()), kitchen_id) );

ALTER POLICY components_delete ON public.components
    USING ( public.is_user_kitchen_member((select auth.uid()), kitchen_id) );
ALTER POLICY components_insert ON public.components
    WITH CHECK ( public.is_user_kitchen_member((select auth.uid()), kitchen_id) );
ALTER POLICY components_update ON public.components
    USING ( public.is_user_kitchen_member((select auth.uid()), kitchen_id) );

-- Recipe_components ----------------------------------------------------
ALTER POLICY recipe_components_delete ON public.recipe_components
    USING (
        EXISTS (
            SELECT 1 FROM public.components c
            WHERE c.component_id = recipe_components.component_id
              AND public.is_user_kitchen_member((select auth.uid()), c.kitchen_id)
        )
    );
ALTER POLICY recipe_components_insert ON public.recipe_components
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.components c
            WHERE c.component_id = recipe_components.component_id
              AND public.is_user_kitchen_member((select auth.uid()), c.kitchen_id)
        )
    );
ALTER POLICY recipe_components_update ON public.recipe_components
    USING (
        EXISTS (
            SELECT 1 FROM public.components c
            WHERE c.component_id = recipe_components.component_id
              AND public.is_user_kitchen_member((select auth.uid()), c.kitchen_id)
        )
    );

-- ------------------------------------------------------------------
-- Additional RLS fixes per advisor 2025-07-29
-- ------------------------------------------------------------------

-- Kitchen_users SELECT policy
ALTER POLICY "Allow users to see all members in their kitchens"
    ON public.kitchen_users
    USING ( public.is_user_kitchen_member((select auth.uid()), kitchen_id) );

-- Users INSERT policy
ALTER POLICY "Enable insert access for authenticated users"
    ON public.users
    WITH CHECK ( (select auth.uid()) = user_id );

-- Kitchen_users UPDATE admin/self policy
ALTER POLICY "Enable update for kitchen admins or self (safeguarded against n"
    ON public.kitchen_users
    USING ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) OR user_id = (select auth.uid()) )
    WITH CHECK ( public.count_kitchen_admins(kitchen_id) >= 1 );

-- Recipes policies -----------------------------------------------------
ALTER POLICY recipes_select  ON public.recipes
    USING ( (select auth.uid()) IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.kitchen_users ku
        WHERE ku.user_id = (select auth.uid())
          AND ku.kitchen_id = recipes.kitchen_id));
ALTER POLICY recipes_insert  ON public.recipes
    WITH CHECK ( (select auth.uid()) IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.kitchen_users ku
        WHERE ku.user_id = (select auth.uid())
          AND ku.kitchen_id = recipes.kitchen_id));
ALTER POLICY recipes_update  ON public.recipes
    USING ( (select auth.uid()) IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.kitchen_users ku
        WHERE ku.user_id = (select auth.uid())
          AND ku.kitchen_id = recipes.kitchen_id));
ALTER POLICY recipes_delete  ON public.recipes
    USING ( (select auth.uid()) IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.kitchen_users ku
        WHERE ku.user_id = (select auth.uid())
          AND ku.kitchen_id = recipes.kitchen_id));

-- Components policies (ingredients alias) -----------------------------
ALTER POLICY components_select  ON public.components
    USING ( (select auth.uid()) IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.kitchen_users ku
        WHERE ku.user_id = (select auth.uid())
          AND ku.kitchen_id = components.kitchen_id));
ALTER POLICY components_insert  ON public.components
    WITH CHECK ( (select auth.uid()) IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.kitchen_users ku
        WHERE ku.user_id = (select auth.uid())
          AND ku.kitchen_id = components.kitchen_id));
ALTER POLICY components_update  ON public.components
    USING ( (select auth.uid()) IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.kitchen_users ku
        WHERE ku.user_id = (select auth.uid())
          AND ku.kitchen_id = components.kitchen_id));
ALTER POLICY components_delete  ON public.components
    USING ( (select auth.uid()) IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.kitchen_users ku
        WHERE ku.user_id = (select auth.uid())
          AND ku.kitchen_id = components.kitchen_id));

-- Menu_section select/update
ALTER POLICY menu_section_select ON public.menu_section
    USING ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

-- Kitchen_invites update policy
ALTER POLICY "Kitchen admins can update invites for their kitchens"
    ON public.kitchen_invites
    USING ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

-- Recipe_components select policy
ALTER POLICY recipe_components_select ON public.recipe_components
    USING (
        EXISTS (
            SELECT 1 FROM public.components c
            WHERE c.component_id = recipe_components.component_id
              AND public.is_user_kitchen_member((select auth.uid()), c.kitchen_id)
        )
    );

-- ------------------------------------------------------------------
-- Consolidate duplicate permissive policies: drop legacy ingredients_* policies
-- ------------------------------------------------------------------
DROP POLICY IF EXISTS ingredients_select  ON public.components;
DROP POLICY IF EXISTS ingredients_insert  ON public.components;
DROP POLICY IF EXISTS ingredients_update  ON public.components;
DROP POLICY IF EXISTS ingredients_delete  ON public.components;

-- Duplicate permissive policies on kitchen/kitchen_users/recipes handled by keeping stronger variants.

-- ------------------------------------------------------------------
-- ------------------------------------------------------------------
-- Additional lint-driven clean-up (2025-07-30)
--   • Consolidate permissive RLS policies (kitchen, kitchen_users, recipes)
--   • Drop truly duplicate indexes on public.components
-- ------------------------------------------------------------------

-- Kitchen table – remove redundant authenticated UPDATE/DELETE policies
DROP POLICY IF EXISTS "Allow authenticated users to update their kitchens where name m" ON public.kitchen;
DROP POLICY IF EXISTS "Allow authenticated users to delete their kitchens where name m" ON public.kitchen;

-- Kitchen_users – merge DELETE logic into one policy
DROP POLICY IF EXISTS "Allow admin to remove other users from their kitchen" ON public.kitchen_users;
DROP POLICY IF EXISTS "Allow user to leave a kitchen (safeguarded against last admin l" ON public.kitchen_users;
CREATE POLICY kitchen_users_delete_authenticated
    ON public.kitchen_users
    FOR DELETE TO authenticated
    USING (
        -- user can remove self so long as they are not the last admin
        (user_id = (select auth.uid()) AND NOT (is_admin = true AND public.count_kitchen_admins(kitchen_id) = 1))
        -- or kitchen admin can remove any non-self member
        OR public.is_user_kitchen_admin((select auth.uid()), kitchen_id)
    );

-- Recipes table – prefer recipes_* policies and drop dishes_* duplicates
DROP POLICY IF EXISTS dishes_select  ON public.recipes;
DROP POLICY IF EXISTS dishes_insert  ON public.recipes;
DROP POLICY IF EXISTS dishes_update  ON public.recipes;
DROP POLICY IF EXISTS dishes_delete  ON public.recipes;

-- ------------------------------------------------------------------
-- Remove duplicate indexes from public.components
-- ------------------------------------------------------------------
-- ingredient_id already covered by PRIMARY KEY (ingredients_pkey)

-- Drop duplicate name/kitchen unique constraints (their backing indexes drop implicitly)
ALTER TABLE public.components DROP CONSTRAINT IF EXISTS ingredients_name_kitchen_id_key;
ALTER TABLE public.components DROP CONSTRAINT IF EXISTS ingredients_name_kitchen_id_unique;

-- ------------------------------------------------------------------
-- End of additional clean-up
-- ------------------------------------------------------------------

COMMIT;
