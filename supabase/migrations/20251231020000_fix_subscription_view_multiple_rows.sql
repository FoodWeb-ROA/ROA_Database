-- Migration: Fix kitchen_subscription_status returning multiple rows
-- Created: 2025-12-31
-- Description: 
--   A Stripe customer can have multiple subscriptions (e.g., one active, one canceled).
--   This causes the view to return multiple rows per kitchen, breaking .maybeSingle() queries.
--   
--   Fix: Use DISTINCT ON to return only ONE subscription per kitchen:
--   - Prioritize active/trialing subscriptions
--   - Fall back to most recent subscription if none are active
--   
--   Security: Views use SECURITY INVOKER by default (caller's permissions).
--   This is correct - users query through RLS-protected stripe_customer_links.

-- =============================================================================
-- 1. Recreate view with DISTINCT ON to ensure single row per kitchen
-- =============================================================================

DROP VIEW IF EXISTS "public"."kitchen_subscription_status";

CREATE VIEW "public"."kitchen_subscription_status" 
WITH (security_invoker = true)
AS
SELECT DISTINCT ON (scl.kitchen_id)
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
LEFT JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id
ORDER BY 
    scl.kitchen_id,
    -- Prioritize active/trialing subscriptions first
    CASE 
        WHEN s.status IN ('active', 'trialing') THEN 0
        ELSE 1
    END,
    -- Then by most recent subscription (newest first)
    s.created DESC NULLS LAST;

-- Re-grant permissions after recreating view
GRANT ALL ON TABLE "public"."kitchen_subscription_status" TO "anon";
GRANT ALL ON TABLE "public"."kitchen_subscription_status" TO "authenticated";
GRANT ALL ON TABLE "public"."kitchen_subscription_status" TO "service_role";

COMMENT ON VIEW public.kitchen_subscription_status IS 
    'View combining kitchen and Stripe subscription data. Returns ONE subscription per kitchen (active/trialing preferred, otherwise most recent). Uses SECURITY INVOKER for proper RLS.';
