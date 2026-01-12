-- Fix kitchen_subscription_status view to return only one subscription per kitchen
-- When a customer has multiple subscriptions (e.g., old canceled + new active),
-- explicitly choose the latest active subscription

DROP VIEW IF EXISTS public.kitchen_subscription_status;

CREATE OR REPLACE VIEW public.kitchen_subscription_status 
WITH (security_invoker='true') AS
SELECT DISTINCT ON (scl.kitchen_id)
  scl.kitchen_id,
  scl.user_id AS paying_user_id,
  scl.stripe_customer_id,
  scl.team_name,
  s.id AS stripe_subscription_id,
  s.status,
  s.current_period_start,
  s.current_period_end,
  s.cancel_at_period_end,
  s.canceled_at,
  s.created AS subscription_created_at,
  k.deletion_scheduled_at,
  CASE
    WHEN (s.status IN ('trialing', 'active') 
      AND (s.current_period_end IS NULL OR to_timestamp(s.current_period_end) > now())) 
    THEN true
    ELSE false
  END AS is_active
FROM public.stripe_customer_links scl
LEFT JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id
LEFT JOIN public.kitchen k ON k.kitchen_id = scl.kitchen_id
ORDER BY 
  scl.kitchen_id,
  -- 1. Prioritize active subscriptions first
  CASE 
    WHEN s.status = 'active' THEN 1
    WHEN s.status = 'trialing' THEN 2
    ELSE 3
  END ASC,
  -- 2. Within same status, choose most recent (latest created)
  s.created DESC NULLS LAST;

COMMENT ON VIEW public.kitchen_subscription_status IS 
'Unified view joining stripe_customer_links with stripe.subscriptions. Returns exactly one subscription per kitchen by prioritizing: (1) active status, (2) trialing status, (3) most recently created subscription.';
