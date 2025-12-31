-- Migration: Kitchen Auto-Deletion System
-- Created: 2025-12-31
-- Description:
--   Implements 30-day retention period after subscription ends.
--   - Adds deletion_scheduled_at to kitchen table
--   - Creates function for owners to delete kitchen immediately
--   - Creates cron job to auto-delete expired kitchens
--   - Updates subscription end handler to schedule deletion

-- =============================================================================
-- 1. Add deletion_scheduled_at column to kitchen table
-- =============================================================================

ALTER TABLE public.kitchen
ADD COLUMN IF NOT EXISTS deletion_scheduled_at timestamptz;

COMMENT ON COLUMN public.kitchen.deletion_scheduled_at IS 
  'When this team kitchen is scheduled for automatic deletion (30 days after subscription ends). NULL means no deletion scheduled.';

-- =============================================================================
-- 2. Function to delete a team kitchen (cascades to all related data)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.delete_team_kitchen(p_kitchen_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_kitchen_type public."KitchenType";
  v_owner_id uuid;
  v_current_user_id uuid;
BEGIN
  v_current_user_id := auth.uid();
  
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get kitchen type and owner
  SELECT type, owner_user_id INTO v_kitchen_type, v_owner_id
  FROM public.kitchen
  WHERE kitchen_id = p_kitchen_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kitchen not found';
  END IF;

  -- Only Team kitchens can be deleted this way (Personal kitchens deleted via user deletion)
  IF v_kitchen_type != 'Team' THEN
    RAISE EXCEPTION 'Can only delete Team kitchens using this function';
  END IF;

  -- Only owner can delete
  IF v_owner_id != v_current_user_id THEN
    RAISE EXCEPTION 'Only the kitchen owner can delete the kitchen';
  END IF;

  RAISE NOTICE 'Deleting team kitchen: %', p_kitchen_id;

  -- Delete the kitchen (CASCADE will handle related data)
  -- This includes: kitchen_users, recipes, components, recipe_components, kitchen_invites, stripe_customer_links
  DELETE FROM public.kitchen WHERE kitchen_id = p_kitchen_id;

  RAISE NOTICE 'Kitchen deletion completed: %', p_kitchen_id;
END;
$$;

COMMENT ON FUNCTION public.delete_team_kitchen(uuid) IS 
  'Allows kitchen owner to immediately delete their team kitchen. Cascades to all related data (recipes, components, memberships, etc.).';

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.delete_team_kitchen(uuid) TO authenticated;

-- =============================================================================
-- 3. Function to schedule kitchen deletion (called when subscription ends)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.schedule_kitchen_deletion(p_kitchen_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_deletion_date timestamptz;
BEGIN
  -- Schedule deletion 30 days from now
  v_deletion_date := now() + interval '30 days';

  UPDATE public.kitchen
  SET deletion_scheduled_at = v_deletion_date
  WHERE kitchen_id = p_kitchen_id
    AND type = 'Team'; -- Only schedule deletion for Team kitchens

  RAISE NOTICE 'Scheduled deletion for kitchen % at %', p_kitchen_id, v_deletion_date;
END;
$$;

COMMENT ON FUNCTION public.schedule_kitchen_deletion(uuid) IS 
  'Schedules a team kitchen for automatic deletion 30 days from now. Called when subscription ends.';

-- =============================================================================
-- 4. Function to clear scheduled deletion (called when subscription is renewed)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.clear_kitchen_deletion_schedule(p_kitchen_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE public.kitchen
  SET deletion_scheduled_at = NULL
  WHERE kitchen_id = p_kitchen_id;

  RAISE NOTICE 'Cleared deletion schedule for kitchen %', p_kitchen_id;
END;
$$;

COMMENT ON FUNCTION public.clear_kitchen_deletion_schedule(uuid) IS 
  'Clears scheduled deletion when subscription is renewed.';

-- =============================================================================
-- 5. Cron job function to auto-delete expired kitchens
-- =============================================================================

CREATE OR REPLACE FUNCTION public.auto_delete_expired_kitchens()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_kitchen_record RECORD;
  v_deleted_count int := 0;
BEGIN
  RAISE NOTICE 'Starting auto-deletion check for expired kitchens';

  -- Find all kitchens scheduled for deletion that have passed their deletion date
  FOR v_kitchen_record IN
    SELECT kitchen_id, name, deletion_scheduled_at
    FROM public.kitchen
    WHERE deletion_scheduled_at IS NOT NULL
      AND deletion_scheduled_at <= now()
      AND type = 'Team'
  LOOP
    BEGIN
      RAISE NOTICE 'Auto-deleting kitchen: % (%) - scheduled for %', 
        v_kitchen_record.kitchen_id, 
        v_kitchen_record.name, 
        v_kitchen_record.deletion_scheduled_at;

      -- Delete the kitchen (CASCADE handles related data)
      DELETE FROM public.kitchen WHERE kitchen_id = v_kitchen_record.kitchen_id;

      v_deleted_count := v_deleted_count + 1;

      RAISE NOTICE 'Successfully deleted kitchen: %', v_kitchen_record.kitchen_id;

    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to delete kitchen %: %', v_kitchen_record.kitchen_id, SQLERRM;
      -- Continue with next kitchen even if one fails
    END;
  END LOOP;

  RAISE NOTICE 'Auto-deletion check completed. Deleted % kitchens', v_deleted_count;
END;
$$;

COMMENT ON FUNCTION public.auto_delete_expired_kitchens() IS 
  'Cron job function that runs daily to automatically delete kitchens that have passed their scheduled deletion date.';

-- Grant execute to service_role for cron job
GRANT EXECUTE ON FUNCTION public.auto_delete_expired_kitchens() TO service_role;

-- =============================================================================
-- 6. Update kitchen_subscription_status view to include deletion_scheduled_at
-- =============================================================================

DROP VIEW IF EXISTS public.kitchen_subscription_status;

CREATE VIEW public.kitchen_subscription_status
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
    CASE 
        WHEN s.status IN ('trialing', 'active') THEN true
        ELSE false
    END AS is_active,
    s.cancel_at_period_end,
    CASE 
        WHEN s.cancel_at_period_end = true OR s.cancel_at IS NOT NULL THEN true
        ELSE false
    END AS is_canceling,
    CASE 
        WHEN s.cancel_at IS NOT NULL THEN to_timestamp((s.cancel_at)::double precision)
        ELSE NULL
    END AS cancel_at,
    k.deletion_scheduled_at
FROM public.stripe_customer_links scl
LEFT JOIN stripe.subscriptions s ON scl.stripe_customer_id = s.customer
LEFT JOIN public.kitchen k ON scl.kitchen_id = k.kitchen_id
ORDER BY scl.kitchen_id, 
         CASE 
             WHEN s.status IN ('active', 'trialing') THEN 1
             ELSE 2
         END,
         s.created DESC;

-- Set view owner and security
ALTER VIEW public.kitchen_subscription_status OWNER TO postgres;
GRANT SELECT ON public.kitchen_subscription_status TO authenticated;
GRANT SELECT ON public.kitchen_subscription_status TO service_role;

COMMENT ON VIEW public.kitchen_subscription_status IS 
  'View combining kitchen subscription data from Stripe with deletion scheduling info. Returns one row per kitchen with their most recent/active subscription and scheduled deletion date.';

SELECT cron.schedule(
'auto-delete-expired-kitchens',
'0 2 * * *', -- Run daily at 2 AM UTC
$$
SELECT public.auto_delete_expired_kitchens();
$$
);