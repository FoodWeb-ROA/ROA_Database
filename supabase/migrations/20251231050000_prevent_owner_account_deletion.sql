-- Migration: Prevent kitchen owners from deleting their accounts
-- Created: 2025-12-31
-- Description:
--   Kitchen owners cannot delete their accounts while they own team kitchens.
--   They must transfer ownership first.
--   Personal kitchens are excluded from this check.

-- =============================================================================
-- 1. Update delete_user function to check for owned team kitchens
-- =============================================================================

CREATE OR REPLACE FUNCTION "public"."delete_user"() 
RETURNS "void"
LANGUAGE "plpgsql" 
SECURITY DEFINER
SET "search_path" TO ''
AS $$
DECLARE
  v_user_id uuid;
  v_owned_team_kitchens_count int;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  -- Check if user owns any team kitchens
  SELECT COUNT(*) INTO v_owned_team_kitchens_count
  FROM public.kitchen
  WHERE owner_user_id = v_user_id
    AND type = 'Team'; -- Only count team kitchens, not personal

  IF v_owned_team_kitchens_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete account while you own % team kitchen(s). Please transfer ownership or delete the kitchen(s) first.', v_owned_team_kitchens_count;
  END IF;

  -- Original deletion logic:
  -- The trigger on_auth_user_deleted handles:
  -- 1. Delete personal kitchen (handle_deleted_user)
  -- 2. Remove team kitchen memberships (kitchen_users FK cascade)
  -- 3. Remove public.users profile (users FK cascade)
  RAISE NOTICE 'Deleting auth user: %', v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

  RAISE NOTICE 'User deletion completed for user_id: %', v_user_id;
END;
$$;

-- Re-grant permissions
GRANT ALL ON FUNCTION "public"."delete_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user"() TO "service_role";

-- =============================================================================
-- Comment
-- =============================================================================

COMMENT ON FUNCTION public.delete_user() IS 
  'Deletes the current user account. Blocks deletion if user owns any team kitchens - they must transfer ownership first. Personal kitchens are automatically deleted via trigger.';
