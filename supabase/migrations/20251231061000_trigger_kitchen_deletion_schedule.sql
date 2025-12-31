-- Migration: Trigger Kitchen Deletion Scheduling on Subscription Status Change
-- Created: 2025-12-31
-- Description:
--   Automatically schedules kitchen deletion when subscription becomes inactive
--   and clears deletion schedule when subscription is renewed/reactivated

-- =============================================================================
-- 1. Function to handle subscription status changes
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_subscription_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_kitchen_id uuid;
  v_old_status text;
  v_new_status text;
BEGIN
  -- Get the status values
  v_old_status := OLD.status;
  v_new_status := NEW.status;
  
  -- Get the kitchen_id associated with this subscription
  SELECT kitchen_id INTO v_kitchen_id
  FROM public.stripe_customer_links
  WHERE stripe_customer_id = NEW.customer
  LIMIT 1;
  
  -- If no kitchen found, nothing to do
  IF v_kitchen_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Check if subscription went from active/trialing to inactive
  IF (v_old_status IN ('active', 'trialing') AND v_new_status NOT IN ('active', 'trialing')) THEN
    -- Schedule deletion (30 days from now)
    RAISE NOTICE 'Subscription became inactive for kitchen %. Scheduling deletion.', v_kitchen_id;
    PERFORM public.schedule_kitchen_deletion(v_kitchen_id);
  END IF;
  
  -- Check if subscription went from inactive to active/trialing (renewal)
  IF (v_old_status NOT IN ('active', 'trialing') AND v_new_status IN ('active', 'trialing')) THEN
    -- Clear deletion schedule
    RAISE NOTICE 'Subscription reactivated for kitchen %. Clearing deletion schedule.', v_kitchen_id;
    PERFORM public.clear_kitchen_deletion_schedule(v_kitchen_id);
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_subscription_status_change() IS 
  'Trigger function that schedules kitchen deletion when subscription becomes inactive and clears it when reactivated.';

-- =============================================================================
-- 2. Create trigger on stripe.subscriptions table
-- =============================================================================

DROP TRIGGER IF EXISTS trigger_subscription_status_change ON stripe.subscriptions;

CREATE TRIGGER trigger_subscription_status_change
  AFTER UPDATE OF status ON stripe.subscriptions
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.handle_subscription_status_change();

COMMENT ON TRIGGER trigger_subscription_status_change ON stripe.subscriptions IS 
  'Automatically schedules kitchen deletion when subscription status changes to inactive, and clears schedule on reactivation.';

-- =============================================================================
-- 3. Backfill: Schedule deletion for currently expired subscriptions
-- =============================================================================

DO $$
DECLARE
  v_record RECORD;
BEGIN
  RAISE NOTICE 'Backfilling deletion schedules for currently expired subscriptions...';
  
  FOR v_record IN
    SELECT DISTINCT k.kitchen_id, k.name
    FROM public.kitchen k
    INNER JOIN public.stripe_customer_links scl ON k.kitchen_id = scl.kitchen_id
    INNER JOIN stripe.subscriptions s ON scl.stripe_customer_id = s.customer
    WHERE k.type = 'Team'
      AND s.status NOT IN ('active', 'trialing')
      AND k.deletion_scheduled_at IS NULL
  LOOP
    BEGIN
      RAISE NOTICE 'Scheduling deletion for kitchen: % (%)', v_record.name, v_record.kitchen_id;
      PERFORM public.schedule_kitchen_deletion(v_record.kitchen_id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to schedule deletion for kitchen %: %', v_record.kitchen_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Backfill completed.';
END;
$$;
