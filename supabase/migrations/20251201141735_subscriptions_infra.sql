-- =============================================================================
-- Kitchen Subscriptions Infrastructure
-- =============================================================================
-- Uses Stripe Sync Engine (stripe schema) + FDW for Stripe data
-- This migration creates linking tables and views to connect ROA entities
-- (kitchens, users) with the stripe schema managed by Stripe Sync Engine.
--
-- Prerequisites (installed via Supabase Dashboard):
-- 1. Stripe Sync Engine integration (creates stripe schema with customers,
--    subscriptions, prices, products tables)
-- 2. Enable wrappers extension (for stripe_fdw if needed)
-- 3. Enable pgmq extension (used by Sync Engine for queued syncs)
-- =============================================================================

-- Enable required extensions
-- Note: stripe schema and its tables are created by the Stripe Sync Engine
-- integration installed via Supabase Dashboard
CREATE EXTENSION IF NOT EXISTS wrappers WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgmq WITH SCHEMA extensions;

-- =============================================================================
-- Linking Table: Connect Stripe Customers to ROA Users/Kitchens
-- =============================================================================
-- The stripe.customers table is managed by Sync Engine.
-- This table links Stripe customer IDs to our internal entities.

CREATE TABLE public.stripe_customer_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Link to our internal user (the paying user)
  user_id uuid NOT NULL
    REFERENCES public.users(uuid)
    ON DELETE CASCADE,
  
  -- Link to the Team kitchen this customer's subscription grants access to
  -- UNIQUE: one subscription per kitchen (enforced here)
  kitchen_id uuid UNIQUE
    REFERENCES public.kitchen(kitchen_id)
    ON DELETE CASCADE,
  
  -- Reference to stripe.customers.id (managed by Sync Engine)
  stripe_customer_id text NOT NULL UNIQUE,
  
  -- Team name specified during checkout (for kitchen creation)
  team_name text,
  
  -- Metadata
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX idx_stripe_customer_links_user 
  ON public.stripe_customer_links(user_id);
CREATE INDEX idx_stripe_customer_links_kitchen 
  ON public.stripe_customer_links(kitchen_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION public.update_stripe_customer_links_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER stripe_customer_links_updated_at
  BEFORE UPDATE ON public.stripe_customer_links
  FOR EACH ROW EXECUTE FUNCTION public.update_stripe_customer_links_updated_at();

-- =============================================================================
-- View: Kitchen Subscription Status
-- =============================================================================
-- Joins our linking table with stripe.subscriptions for a unified view.
-- This replaces the old kitchen_subscriptions table.

CREATE OR REPLACE VIEW public.kitchen_subscription_status AS
SELECT 
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
  -- Derived fields
  CASE 
    WHEN s.status IN ('trialing', 'active') 
      AND (s.current_period_end IS NULL OR s.current_period_end > now())
    THEN true
    ELSE false
  END AS is_active
FROM public.stripe_customer_links scl
LEFT JOIN stripe.subscriptions s 
  ON s.customer = scl.stripe_customer_id;

-- Grant access to the view
GRANT SELECT ON public.kitchen_subscription_status TO authenticated;

-- =============================================================================
-- Helper Function: Check if kitchen has active subscription
-- =============================================================================
-- Queries the stripe.subscriptions table via our linking table

CREATE OR REPLACE FUNCTION public.is_kitchen_subscribed(p_kitchen_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, stripe
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.stripe_customer_links scl
    JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id
    WHERE scl.kitchen_id = p_kitchen_id
      AND s.status IN ('trialing', 'active')
      AND (s.current_period_end IS NULL OR s.current_period_end > now())
  );
$$;

-- Grant execute to authenticated users (for client-side checks)
GRANT EXECUTE ON FUNCTION public.is_kitchen_subscribed(uuid) TO authenticated;

-- =============================================================================
-- Function: Create Team Kitchen on Successful Subscription
-- =============================================================================
-- Called by Edge Function or trigger when checkout completes.
-- Creates the Team kitchen and links the paying user as admin.

CREATE OR REPLACE FUNCTION public.handle_subscription_checkout_complete(
  p_stripe_customer_id text,
  p_user_id uuid,
  p_team_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_kitchen_id uuid;
  v_final_team_name text;
  v_user_email text;
BEGIN
  -- Get user email for default team name
  SELECT email INTO v_user_email
  FROM public.users
  WHERE uuid = p_user_id;
  
  v_final_team_name := COALESCE(p_team_name, v_user_email, 'Team');
  
  -- Check if customer link already exists (re-subscribe scenario)
  SELECT kitchen_id INTO v_kitchen_id
  FROM public.stripe_customer_links
  WHERE stripe_customer_id = p_stripe_customer_id;
  
  IF v_kitchen_id IS NOT NULL THEN
    -- Existing subscription, return the kitchen
    RETURN v_kitchen_id;
  END IF;
  
  -- Create new Team kitchen
  INSERT INTO public.kitchen (name, type)
  VALUES (v_final_team_name, 'Team')
  RETURNING kitchen_id INTO v_kitchen_id;
  
  -- Link paying user as admin
  INSERT INTO public.kitchen_users (kitchen_id, user_id, is_admin)
  VALUES (v_kitchen_id, p_user_id, true);
  
  -- Create customer link
  INSERT INTO public.stripe_customer_links (user_id, kitchen_id, stripe_customer_id, team_name)
  VALUES (p_user_id, v_kitchen_id, p_stripe_customer_id, v_final_team_name);
  
  RETURN v_kitchen_id;
END;
$$;

-- Grant execute to service_role only (called by Edge Functions)
REVOKE ALL ON FUNCTION public.handle_subscription_checkout_complete FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_subscription_checkout_complete TO service_role;

-- =============================================================================
-- RLS Policies
-- =============================================================================

ALTER TABLE public.stripe_customer_links ENABLE ROW LEVEL SECURITY;

-- Users can view their own customer links
CREATE POLICY "Users can view their own customer links"
  ON public.stripe_customer_links
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Users can view links for kitchens they belong to
CREATE POLICY "Users can view customer links for their kitchens"
  ON public.stripe_customer_links
  FOR SELECT
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id 
      FROM public.kitchen_users ku 
      WHERE ku.user_id = auth.uid()
    )
  );

-- No direct INSERT/UPDATE/DELETE for authenticated users
-- (service_role bypasses RLS for Edge Function operations)

-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON TABLE public.stripe_customer_links IS 
  'Links Stripe customers (from stripe.subscriptions via Sync Engine) to ROA users and kitchens. One subscription per kitchen enforced via UNIQUE constraint on kitchen_id.';

COMMENT ON VIEW public.kitchen_subscription_status IS 
  'Unified view joining stripe_customer_links with stripe.subscriptions for easy querying of kitchen subscription status.';

COMMENT ON FUNCTION public.is_kitchen_subscribed IS 
  'Returns true if kitchen has active/trialing subscription with valid period. Queries stripe.subscriptions via linking table.';

COMMENT ON FUNCTION public.handle_subscription_checkout_complete IS 
  'Creates Team kitchen and links paying user as admin when Stripe checkout completes. Called by Edge Function. Returns kitchen_id.';
