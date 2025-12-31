-- Migration: Subscription Access Control
-- Created: 2025-12-31
-- Description: 
--   1. Fix RLS permission for kitchen_subscription_status view
--   2. Add is_kitchen_access_allowed() function for access control
--   3. Add get_kitchen_subscription_status() function with SECURITY DEFINER

-- =============================================================================
-- 1. Grant SELECT on stripe.subscriptions to authenticated users
--    This is needed because the kitchen_subscription_status view joins stripe tables
-- =============================================================================

GRANT SELECT ON stripe.subscriptions TO authenticated;

-- =============================================================================
-- 2. Create SECURITY DEFINER function to get subscription status
--    This provides a safe way to access subscription data without exposing stripe tables
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_kitchen_subscription_status(p_kitchen_id uuid)
RETURNS TABLE (
  kitchen_id uuid,
  paying_user_id uuid,
  stripe_customer_id text,
  stripe_subscription_id text,
  team_name text,
  status text,
  is_active boolean,
  cancel_at_period_end boolean,
  canceled_at bigint,
  current_period_start bigint,
  current_period_end bigint,
  subscription_created_at bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, stripe
AS $$
  SELECT 
    scl.kitchen_id,
    scl.user_id as paying_user_id,
    scl.stripe_customer_id,
    s.id as stripe_subscription_id,
    scl.team_name,
    s.status,
    CASE 
      WHEN s.status IN ('trialing', 'active') 
        AND (s.current_period_end IS NULL OR to_timestamp(s.current_period_end) > now())
      THEN true
      ELSE false
    END as is_active,
    s.cancel_at_period_end,
    s.canceled_at,
    s.current_period_start,
    s.current_period_end,
    s.created as subscription_created_at
  FROM public.stripe_customer_links scl
  LEFT JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id
  WHERE scl.kitchen_id = p_kitchen_id
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_kitchen_subscription_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_kitchen_subscription_status(uuid) TO service_role;

COMMENT ON FUNCTION public.get_kitchen_subscription_status(uuid) IS 
  'Returns subscription status for a kitchen. Uses SECURITY DEFINER to safely access stripe tables.';

-- =============================================================================
-- 3. Create is_kitchen_access_allowed() function
--    Used to check if a kitchen has valid subscription access
-- =============================================================================

CREATE OR REPLACE FUNCTION public.is_kitchen_access_allowed(p_kitchen_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, stripe
AS $$
  SELECT 
    -- Personal kitchens always have access (no subscription needed)
    EXISTS (
      SELECT 1 FROM public.kitchen k
      WHERE k.kitchen_id = p_kitchen_id 
        AND k.type = 'Personal'
    )
    OR
    -- Team kitchens need active subscription
    EXISTS (
      SELECT 1
      FROM public.stripe_customer_links scl
      JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id
      WHERE scl.kitchen_id = p_kitchen_id
        AND s.status IN ('trialing', 'active')
        AND (s.current_period_end IS NULL OR to_timestamp(s.current_period_end) > now())
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_kitchen_access_allowed(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_kitchen_access_allowed(uuid) TO service_role;

COMMENT ON FUNCTION public.is_kitchen_access_allowed(uuid) IS 
  'Returns true if kitchen has valid access (Personal kitchen or active Team subscription).
   Used for access control in RLS policies.';

-- =============================================================================
-- 4. Create is_subscription_canceling() helper function
--    Quick check if subscription is set to cancel at period end
-- =============================================================================

CREATE OR REPLACE FUNCTION public.is_subscription_canceling(p_kitchen_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, stripe
AS $$
  SELECT COALESCE(
    (
      SELECT s.cancel_at_period_end
      FROM public.stripe_customer_links scl
      JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id
      WHERE scl.kitchen_id = p_kitchen_id
        AND s.status IN ('trialing', 'active')
      LIMIT 1
    ),
    false
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_subscription_canceling(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_subscription_canceling(uuid) TO service_role;

COMMENT ON FUNCTION public.is_subscription_canceling(uuid) IS 
  'Returns true if kitchen subscription is set to cancel at period end.';

-- =============================================================================
-- 5. WRITE-BLOCKING RLS POLICIES
--    Block INSERT, UPDATE, DELETE on recipe-related tables when subscription expired
--    READ access remains unchanged (users can still view their data)
-- =============================================================================

-- Helper: Check if kitchen allows writes (active subscription OR personal kitchen)
CREATE OR REPLACE FUNCTION public.is_kitchen_write_allowed(p_kitchen_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, stripe
AS $$
  SELECT 
    -- Personal kitchens always allow writes
    EXISTS (
      SELECT 1 FROM public.kitchen k
      WHERE k.kitchen_id = p_kitchen_id 
        AND k.type = 'Personal'
    )
    OR
    -- Team kitchens need active subscription for writes
    EXISTS (
      SELECT 1
      FROM public.stripe_customer_links scl
      JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id
      WHERE scl.kitchen_id = p_kitchen_id
        AND s.status IN ('trialing', 'active')
        AND (s.current_period_end IS NULL OR to_timestamp(s.current_period_end) > now())
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_kitchen_write_allowed(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_kitchen_write_allowed(uuid) TO service_role;

COMMENT ON FUNCTION public.is_kitchen_write_allowed(uuid) IS 
  'Returns true if kitchen allows write operations (Personal kitchen or active Team subscription).';

-- -----------------------------------------------------------------------------
-- RECIPES: Block writes when subscription expired
-- -----------------------------------------------------------------------------

-- Drop existing INSERT policy and recreate with subscription check
DROP POLICY IF EXISTS "recipes_insert" ON public.recipes;
CREATE POLICY "recipes_insert" ON public.recipes
FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() IS NOT NULL
  AND is_user_kitchen_member(auth.uid(), kitchen_id)
  AND is_kitchen_write_allowed(kitchen_id)
);

-- Drop existing UPDATE policy and recreate with subscription check
DROP POLICY IF EXISTS "recipes_update" ON public.recipes;
CREATE POLICY "recipes_update" ON public.recipes
FOR UPDATE TO authenticated
USING (
  auth.uid() IS NOT NULL
  AND is_user_kitchen_member(auth.uid(), kitchen_id)
)
WITH CHECK (
  auth.uid() IS NOT NULL
  AND is_user_kitchen_member(auth.uid(), kitchen_id)
  AND is_kitchen_write_allowed(kitchen_id)
);

-- Drop existing DELETE policy and recreate with subscription check
DROP POLICY IF EXISTS "recipes_delete" ON public.recipes;
CREATE POLICY "recipes_delete" ON public.recipes
FOR DELETE TO authenticated
USING (
  auth.uid() IS NOT NULL
  AND is_user_kitchen_member(auth.uid(), kitchen_id)
  AND is_kitchen_write_allowed(kitchen_id)
);

-- -----------------------------------------------------------------------------
-- COMPONENTS: Block writes when subscription expired
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "components_insert" ON public.components;
CREATE POLICY "components_insert" ON public.components
FOR INSERT TO authenticated
WITH CHECK (
  auth.uid() IS NOT NULL
  AND is_user_kitchen_member(auth.uid(), kitchen_id)
  AND is_kitchen_write_allowed(kitchen_id)
);

DROP POLICY IF EXISTS "components_update" ON public.components;
CREATE POLICY "components_update" ON public.components
FOR UPDATE TO authenticated
USING (
  is_user_kitchen_member(auth.uid(), kitchen_id)
)
WITH CHECK (
  is_user_kitchen_member(auth.uid(), kitchen_id)
  AND is_kitchen_write_allowed(kitchen_id)
);

DROP POLICY IF EXISTS "components_delete" ON public.components;
CREATE POLICY "components_delete" ON public.components
FOR DELETE TO authenticated
USING (
  auth.uid() IS NOT NULL
  AND is_user_kitchen_member(auth.uid(), kitchen_id)
  AND is_kitchen_write_allowed(kitchen_id)
);

-- -----------------------------------------------------------------------------
-- CATEGORIES: Block writes when subscription expired
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "categories_insert" ON public.categories;
CREATE POLICY "categories_insert" ON public.categories
FOR INSERT
WITH CHECK (
  auth.uid() IS NOT NULL
  AND is_user_kitchen_member(auth.uid(), kitchen_id)
  AND is_kitchen_write_allowed(kitchen_id)
);

DROP POLICY IF EXISTS "categories_update" ON public.categories;
CREATE POLICY "categories_update" ON public.categories
FOR UPDATE
USING (
  auth.uid() IS NOT NULL
  AND is_user_kitchen_member(auth.uid(), kitchen_id)
)
WITH CHECK (
  auth.uid() IS NOT NULL
  AND is_user_kitchen_member(auth.uid(), kitchen_id)
  AND is_kitchen_write_allowed(kitchen_id)
);

DROP POLICY IF EXISTS "categories_delete" ON public.categories;
CREATE POLICY "categories_delete" ON public.categories
FOR DELETE
USING (
  auth.uid() IS NOT NULL
  AND is_user_kitchen_member(auth.uid(), kitchen_id)
  AND is_kitchen_write_allowed(kitchen_id)
);

-- -----------------------------------------------------------------------------
-- RECIPE_COMPONENTS: Block writes when subscription expired
-- Recipe_components doesn't have kitchen_id directly, so we check via recipe
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "recipe_components_insert" ON public.recipe_components;
CREATE POLICY "recipe_components_insert" ON public.recipe_components
FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.recipes r
    WHERE r.recipe_id = recipe_components.recipe_id
      AND is_user_kitchen_member(auth.uid(), r.kitchen_id)
      AND is_kitchen_write_allowed(r.kitchen_id)
  )
);

DROP POLICY IF EXISTS "recipe_components_update" ON public.recipe_components;
CREATE POLICY "recipe_components_update" ON public.recipe_components
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.recipes r
    WHERE r.recipe_id = recipe_components.recipe_id
      AND is_user_kitchen_member(auth.uid(), r.kitchen_id)
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.recipes r
    WHERE r.recipe_id = recipe_components.recipe_id
      AND is_user_kitchen_member(auth.uid(), r.kitchen_id)
      AND is_kitchen_write_allowed(r.kitchen_id)
  )
);

DROP POLICY IF EXISTS "recipe_components_delete" ON public.recipe_components;
CREATE POLICY "recipe_components_delete" ON public.recipe_components
FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.recipes r
    WHERE r.recipe_id = recipe_components.recipe_id
      AND is_user_kitchen_member(auth.uid(), r.kitchen_id)
      AND is_kitchen_write_allowed(r.kitchen_id)
  )
);
