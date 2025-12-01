-- Kitchen Subscriptions: Links Stripe subscriptions to Team kitchens
-- Only written via service_role (roa-api webhook) or manual admin insertion

-- Subscription status enum for type safety
CREATE TYPE public.subscription_status AS ENUM (
  'incomplete',
  'incomplete_expired', 
  'trialing',
  'active',
  'past_due',
  'canceled',
  'unpaid',
  'paused'
);

-- Main subscriptions table
CREATE TABLE public.kitchen_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- The team kitchen this subscription grants access to
  -- UNIQUE: one subscription per kitchen (upsert on re-subscribe)
  kitchen_id uuid NOT NULL UNIQUE
    REFERENCES public.kitchen(kitchen_id)
    ON DELETE CASCADE,

  -- Stripe references (no separate customer table needed)
  stripe_subscription_id text UNIQUE NOT NULL,
  stripe_customer_id text NOT NULL,
  stripe_customer_email text NOT NULL,
  stripe_price_id text NOT NULL,
  stripe_product_id text NOT NULL,

  -- Subscription state
  status public.subscription_status NOT NULL DEFAULT 'incomplete',
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean NOT NULL DEFAULT false,
  canceled_at timestamptz,

  -- Metadata
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX idx_kitchen_subscriptions_status 
  ON public.kitchen_subscriptions(status);
CREATE INDEX idx_kitchen_subscriptions_stripe_customer 
  ON public.kitchen_subscriptions(stripe_customer_id);
CREATE INDEX idx_kitchen_subscriptions_current_period_end 
  ON public.kitchen_subscriptions(current_period_end);

-- Auto-update updated_at
CREATE TRIGGER set_updated_at_kitchen_subscriptions
  BEFORE UPDATE ON public.kitchen_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_times();

-- Helper function: check if a kitchen has an active subscription
CREATE OR REPLACE FUNCTION public.is_kitchen_subscribed(p_kitchen_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.kitchen_subscriptions s
    WHERE s.kitchen_id = p_kitchen_id
      AND s.status IN ('trialing', 'active')
      AND (s.current_period_end IS NULL OR s.current_period_end > now())
  );
$$;

-- Grant execute to authenticated users (for client-side checks)
GRANT EXECUTE ON FUNCTION public.is_kitchen_subscribed(uuid) TO authenticated;

-- RLS: Deny all direct client access (only service_role writes)
ALTER TABLE public.kitchen_subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can read their own kitchen subscriptions (for UI display)
CREATE POLICY "Users can view subscriptions for their kitchens"
  ON public.kitchen_subscriptions
  FOR SELECT
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id 
      FROM public.kitchen_users ku 
      WHERE ku.user_id = auth.uid()
    )
  );

-- No INSERT/UPDATE/DELETE policies = service_role only
-- (service_role bypasses RLS)

-- Comment for documentation
COMMENT ON TABLE public.kitchen_subscriptions IS 
  'Stripe subscription data for Team kitchens. Written by roa-api webhook or admin. One subscription per kitchen.';
COMMENT ON FUNCTION public.is_kitchen_subscribed IS 
  'Returns true if kitchen has active/trialing subscription with valid period.';
