-- Consolidate multiple permissive policies into single policies
-- This addresses the multiple_permissive_policies linter warnings
-- by combining multiple policies for the same role+action with OR logic

-- ============================================================================
-- KITCHEN TABLE: Consolidate UPDATE policies
-- ============================================================================
-- Merge "Only kitchen owner can update kitchen" + "Admins can update kitchen names"

DROP POLICY IF EXISTS "Only kitchen owner can update kitchen" ON public.kitchen;
DROP POLICY IF EXISTS "Admins can update kitchen names" ON public.kitchen;

CREATE POLICY kitchen_authenticated_update
  ON public.kitchen
  FOR UPDATE
  TO authenticated
  USING (
    -- Owner can update
    owner_user_id = (SELECT auth.uid())
    OR
    -- Admins can update
    EXISTS (
      SELECT 1
      FROM public.kitchen_users ku
      WHERE ku.user_id = (SELECT auth.uid())
        AND ku.is_admin = true
        AND ku.kitchen_id = kitchen.kitchen_id
    )
  )
  WITH CHECK (
    -- Owner can update
    owner_user_id = (SELECT auth.uid())
    OR
    -- Admins can update (but only kitchen_name, enforced at application level)
    EXISTS (
      SELECT 1
      FROM public.kitchen_users ku
      WHERE ku.user_id = (SELECT auth.uid())
        AND ku.is_admin = true
        AND ku.kitchen_id = kitchen.kitchen_id
    )
  );

-- ============================================================================
-- KITCHEN_USERS TABLE: Consolidate DELETE policies
-- ============================================================================
-- Merge "Only kitchen owner can remove users" + "kitchen_users_delete_authenticated"

DROP POLICY IF EXISTS "Only kitchen owner can remove users" ON public.kitchen_users;
DROP POLICY IF EXISTS "kitchen_users_delete_authenticated" ON public.kitchen_users;

CREATE POLICY kitchen_users_authenticated_delete
  ON public.kitchen_users
  FOR DELETE
  TO authenticated
  USING (
    -- Kitchen owner can remove any user
    EXISTS (
      SELECT 1
      FROM public.kitchen k
      WHERE k.kitchen_id = kitchen_users.kitchen_id
        AND k.owner_user_id = (SELECT auth.uid())
    )
    OR
    -- User can remove themselves (unless they're the last admin)
    (
      user_id = (SELECT auth.uid())
      AND NOT (is_admin = true AND public.count_kitchen_admins(kitchen_id) = 1)
    )
    OR
    -- Kitchen admins can remove users
    public.is_user_kitchen_admin((SELECT auth.uid()), kitchen_id)
  );

-- ============================================================================
-- KITCHEN_USERS TABLE: Consolidate UPDATE policies
-- ============================================================================
-- Merge "Only kitchen owner can update admin status" + "Enable update for kitchen admins or self"

DROP POLICY IF EXISTS "Only kitchen owner can update admin status" ON public.kitchen_users;
DROP POLICY IF EXISTS "Enable update for kitchen admins or self (safeguarded against n" ON public.kitchen_users;

CREATE POLICY kitchen_users_authenticated_update
  ON public.kitchen_users
  FOR UPDATE
  TO authenticated
  USING (
    -- Kitchen owner can update any user
    EXISTS (
      SELECT 1
      FROM public.kitchen k
      WHERE k.kitchen_id = kitchen_users.kitchen_id
        AND k.owner_user_id = (SELECT auth.uid())
    )
    OR
    -- User can update themselves (but not admin status)
    (user_id = (SELECT auth.uid()) AND NOT is_admin)
    OR
    -- Kitchen admins can update users
    public.is_user_kitchen_admin((SELECT auth.uid()), kitchen_id)
  );

-- ============================================================================
-- STRIPE_CUSTOMER_LINKS TABLE: Consolidate SELECT policies
-- ============================================================================
-- Merge "Users can view customer links for their kitchens" + "Users can view their own customer links"

DROP POLICY IF EXISTS "Users can view customer links for their kitchens" ON public.stripe_customer_links;
DROP POLICY IF EXISTS "Users can view their own customer links" ON public.stripe_customer_links;

CREATE POLICY stripe_customer_links_authenticated_select
  ON public.stripe_customer_links
  FOR SELECT
  TO authenticated
  USING (
    -- User can view their own customer links
    user_id = (SELECT auth.uid())
    OR
    -- User can view customer links for kitchens they belong to
    EXISTS (
      SELECT 1
      FROM public.kitchen_users ku
      WHERE ku.kitchen_id = stripe_customer_links.kitchen_id
        AND ku.user_id = (SELECT auth.uid())
    )
  );
