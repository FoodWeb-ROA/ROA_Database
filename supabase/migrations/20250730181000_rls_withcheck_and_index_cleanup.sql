-- Fix remaining linter warnings (auth_rls_initplan + duplicate_index)
-- Migration generated 2025-07-30

BEGIN;

-- ------------------------------------------------------------------
-- 1. Replace auth.uid() with sub-select in WITH CHECK clauses
-- ------------------------------------------------------------------

-- menu_section_update (USING already fixed)
ALTER POLICY menu_section_update
    ON public.menu_section
    USING ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) )
    WITH CHECK ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

-- users update policy
ALTER POLICY "Enable update access for the user based on their id"
    ON public.users
    USING ( user_id = (select auth.uid()) )
    WITH CHECK ( user_id = (select auth.uid()) );

-- ------------------------------------------------------------------
-- 2. Remove duplicate indexes / constraints
-- ------------------------------------------------------------------

-- components: drop duplicate unique constraint ingredients_ingredient_id_key
--   • first drop FK that relies on it
ALTER TABLE public.recipe_components
    DROP CONSTRAINT IF EXISTS recipe_components_component_id_fkey;

--   • drop the redundant unique constraint (index drops implicitly)
ALTER TABLE public.components
    DROP CONSTRAINT IF EXISTS ingredients_ingredient_id_key;

--   • recreate FK referencing primary key
ALTER TABLE public.recipe_components
    ADD CONSTRAINT recipe_components_component_id_fkey
        FOREIGN KEY (component_id)
        REFERENCES public.components(component_id)
        ON DELETE CASCADE;

-- recipes: drop old dishes_name_kitchen_id_unique in favour of recipes_name_kitchen_id_unique
ALTER TABLE public.recipes
    DROP CONSTRAINT IF EXISTS dishes_name_kitchen_id_unique;

-- ------------------------------------------------------------------
-- 3. Update remaining policies to use sub-select auth.uid()
-- ------------------------------------------------------------------

-- recipes_update
ALTER POLICY recipes_update
    ON public.recipes
    USING ( (select auth.uid()) IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.kitchen_users ku
        WHERE ku.user_id = (select auth.uid())
          AND ku.kitchen_id = recipes.kitchen_id) )
    WITH CHECK ( (select auth.uid()) IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.kitchen_users ku
        WHERE ku.user_id = (select auth.uid())
          AND ku.kitchen_id = recipes.kitchen_id) );

-- components_update
ALTER POLICY components_update
    ON public.components
    USING ( public.is_user_kitchen_member((select auth.uid()), kitchen_id) )
    WITH CHECK ( public.is_user_kitchen_member((select auth.uid()), kitchen_id) );

-- recipe_components_update
ALTER POLICY recipe_components_update
    ON public.recipe_components
    USING ( EXISTS (
        SELECT 1 FROM public.components c
        WHERE c.component_id = recipe_components.component_id
          AND public.is_user_kitchen_member((select auth.uid()), c.kitchen_id) ) )
    WITH CHECK ( EXISTS (
        SELECT 1 FROM public.components c
        WHERE c.component_id = recipe_components.component_id
          AND public.is_user_kitchen_member((select auth.uid()), c.kitchen_id) ) );

-- kitchen_invites update
ALTER POLICY "Kitchen admins can update invites for their kitchens"
    ON public.kitchen_invites
    USING ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) )
    WITH CHECK ( public.is_user_kitchen_admin((select auth.uid()), kitchen_id) );

COMMIT;
