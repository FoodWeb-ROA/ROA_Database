-- Migration: Fix subscription cancellation detection
-- Created: 2025-12-31
-- Description: 
--   Stripe has TWO cancellation mechanisms:
--   1. cancel_at_period_end = true (cancel at end of billing period)
--   2. cancel_at = <timestamp> (scheduled cancellation at specific time)
--   
--   The portal uses cancel_at, not cancel_at_period_end.
--   This migration updates the view and functions to check BOTH fields.

-- =============================================================================
-- 1. Update kitchen_subscription_status view to include cancel_at
--    Must DROP and recreate because PostgreSQL doesn't allow column reordering
-- =============================================================================

DROP VIEW IF EXISTS "public"."kitchen_subscription_status";

CREATE VIEW "public"."kitchen_subscription_status" AS
SELECT 
    scl.kitchen_id,
    scl.user_id AS paying_user_id,
    scl.stripe_customer_id,
    scl.team_name,
    s.id AS stripe_subscription_id,
    s.status,
    to_timestamp((s.current_period_start)::double precision) AS current_period_start,
    to_timestamp((s.current_period_end)::double precision) AS current_period_end,
    s.cancel_at_period_end,
    to_timestamp((s.cancel_at)::double precision) AS cancel_at,
    to_timestamp((s.canceled_at)::double precision) AS canceled_at,
    to_timestamp((s.created)::double precision) AS subscription_created_at,
    -- is_active: subscription is usable
    CASE
        WHEN s.status IN ('trialing', 'active') 
             AND (s.current_period_end IS NULL OR to_timestamp((s.current_period_end)::double precision) > now())
        THEN true
        ELSE false
    END AS is_active,
    -- is_canceling: subscription will end (either at period end OR at scheduled time)
    CASE
        WHEN s.cancel_at_period_end = true THEN true
        WHEN s.cancel_at IS NOT NULL THEN true
        ELSE false
    END AS is_canceling
FROM public.stripe_customer_links scl
LEFT JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id;

-- Re-grant permissions after recreating view
GRANT ALL ON TABLE "public"."kitchen_subscription_status" TO "anon";
GRANT ALL ON TABLE "public"."kitchen_subscription_status" TO "authenticated";
GRANT ALL ON TABLE "public"."kitchen_subscription_status" TO "service_role";

COMMENT ON VIEW public.kitchen_subscription_status IS 
    'View combining kitchen and subscription data. Checks both cancel_at_period_end and cancel_at for cancellation status.';

-- =============================================================================
-- 2. Update get_kitchen_subscription_status function to include cancel_at
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_kitchen_subscription_status(p_kitchen_id uuid);

CREATE OR REPLACE FUNCTION public.get_kitchen_subscription_status(p_kitchen_id uuid)
RETURNS TABLE (
    kitchen_id uuid,
    paying_user_id uuid,
    stripe_customer_id text,
    team_name text,
    stripe_subscription_id text,
    status text,
    current_period_start timestamptz,
    current_period_end timestamptz,
    cancel_at_period_end boolean,
    cancel_at timestamptz,
    canceled_at timestamptz,
    subscription_created_at timestamptz,
    is_active boolean,
    is_canceling boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, stripe
AS $$
    SELECT 
        scl.kitchen_id,
        scl.user_id AS paying_user_id,
        scl.stripe_customer_id,
        scl.team_name,
        s.id AS stripe_subscription_id,
        s.status,
        to_timestamp((s.current_period_start)::double precision) AS current_period_start,
        to_timestamp((s.current_period_end)::double precision) AS current_period_end,
        s.cancel_at_period_end,
        to_timestamp((s.cancel_at)::double precision) AS cancel_at,
        to_timestamp((s.canceled_at)::double precision) AS canceled_at,
        to_timestamp((s.created)::double precision) AS subscription_created_at,
        -- is_active
        CASE
            WHEN s.status IN ('trialing', 'active') 
                 AND (s.current_period_end IS NULL OR to_timestamp((s.current_period_end)::double precision) > now())
            THEN true
            ELSE false
        END AS is_active,
        -- is_canceling (check both fields)
        CASE
            WHEN s.cancel_at_period_end = true THEN true
            WHEN s.cancel_at IS NOT NULL THEN true
            ELSE false
        END AS is_canceling
    FROM public.stripe_customer_links scl
    LEFT JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id
    WHERE scl.kitchen_id = p_kitchen_id
    LIMIT 1;
$$;

COMMENT ON FUNCTION public.get_kitchen_subscription_status(uuid) IS 
    'Returns subscription status for a kitchen. Checks both cancel_at_period_end and cancel_at for cancellation detection.';

-- =============================================================================
-- 3. Update is_subscription_canceling function to check both fields
-- =============================================================================

CREATE OR REPLACE FUNCTION public.is_subscription_canceling(p_kitchen_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, stripe
AS $$
    SELECT 
        COALESCE(
            (
                SELECT 
                    CASE
                        WHEN s.cancel_at_period_end = true THEN true
                        WHEN s.cancel_at IS NOT NULL THEN true
                        ELSE false
                    END
                FROM public.stripe_customer_links scl
                JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id
                WHERE scl.kitchen_id = p_kitchen_id
                  AND s.status IN ('trialing', 'active')
                LIMIT 1
            ),
            false
        );
$$;

COMMENT ON FUNCTION public.is_subscription_canceling(uuid) IS 
    'Returns true if the kitchen subscription is set to cancel (via cancel_at_period_end OR cancel_at).';
