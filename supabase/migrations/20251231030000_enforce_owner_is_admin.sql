-- Migration: Enforce kitchen owners are always admins
-- Created: 2025-12-31
-- Description:
--   Ensures that kitchen owners always have is_admin=true in kitchen_users.
--   Prevents revoking admin status from owners.
--   Also ensures that when a user becomes an owner, they automatically get admin status.

-- =============================================================================
-- 1. Create trigger function to enforce owner is admin
-- =============================================================================

CREATE OR REPLACE FUNCTION public.enforce_owner_is_admin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id uuid;
BEGIN
  -- Get the kitchen owner
  SELECT owner_user_id INTO v_owner_id
  FROM public.kitchen
  WHERE kitchen_id = NEW.kitchen_id;

  -- If this user is the owner, ensure is_admin is true
  IF NEW.user_id = v_owner_id THEN
    IF NEW.is_admin = false THEN
      RAISE EXCEPTION 'Cannot revoke admin status from kitchen owner';
    END IF;
    -- Force is_admin to true for owners
    NEW.is_admin := true;
  END IF;

  RETURN NEW;
END;
$$;

-- =============================================================================
-- 2. Create trigger on kitchen_users INSERT and UPDATE
-- =============================================================================

DROP TRIGGER IF EXISTS enforce_owner_is_admin_trigger ON public.kitchen_users;

CREATE TRIGGER enforce_owner_is_admin_trigger
  BEFORE INSERT OR UPDATE OF is_admin ON public.kitchen_users
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_owner_is_admin();

-- =============================================================================
-- 3. Create trigger to ensure owner is admin when kitchen owner changes
-- =============================================================================

CREATE OR REPLACE FUNCTION public.ensure_new_owner_is_admin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- When owner changes, ensure the new owner has is_admin=true
  IF NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id THEN
    -- Update the new owner to be admin
    UPDATE public.kitchen_users
    SET is_admin = true
    WHERE kitchen_id = NEW.kitchen_id
      AND user_id = NEW.owner_user_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ensure_new_owner_is_admin_trigger ON public.kitchen;

CREATE TRIGGER ensure_new_owner_is_admin_trigger
  AFTER UPDATE OF owner_user_id ON public.kitchen
  FOR EACH ROW
  WHEN (NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id)
  EXECUTE FUNCTION public.ensure_new_owner_is_admin();

-- =============================================================================
-- 4. Fix any existing kitchen owners who aren't admins
-- =============================================================================

-- Set is_admin=true for any kitchen owners who aren't currently admins
UPDATE public.kitchen_users ku
SET is_admin = true
FROM public.kitchen k
WHERE ku.kitchen_id = k.kitchen_id
  AND ku.user_id = k.owner_user_id
  AND ku.is_admin = false;

-- =============================================================================
-- Comments
-- =============================================================================

COMMENT ON FUNCTION public.enforce_owner_is_admin() IS 
  'Trigger function that prevents revoking admin status from kitchen owners';

COMMENT ON FUNCTION public.ensure_new_owner_is_admin() IS 
  'Trigger function that ensures new kitchen owners automatically get admin status';
