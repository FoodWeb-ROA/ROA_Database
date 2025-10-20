-- Migration: Automatically delete personal kitchen when user is deleted from auth.users
-- This ensures that when a user is deleted (either manually from dashboard or via handle_user_delete),
-- their personal kitchen is automatically cleaned up via trigger

DROP FUNCTION IF EXISTS handle_user_delete;

-- ============================================================================
-- 1. Create trigger function to delete personal kitchen before user deletion
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_deleted_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_personal_kitchen_id uuid;
BEGIN
  -- Find the user's personal kitchen
  SELECT k.kitchen_id INTO v_personal_kitchen_id
  FROM public.kitchen k
  INNER JOIN public.kitchen_users ku ON k.kitchen_id = ku.kitchen_id
  WHERE ku.user_id = OLD.id
    AND k.type = 'Personal'
  LIMIT 1;

  -- Delete the personal kitchen (this will cascade to all kitchen-related data)
  IF v_personal_kitchen_id IS NOT NULL THEN
    RAISE NOTICE 'Auto-deleting personal kitchen % for user %', v_personal_kitchen_id, OLD.id;
    DELETE FROM public.kitchen WHERE kitchen_id = v_personal_kitchen_id;
  END IF;
  
  -- The CASCADE constraint on public.users will automatically remove the public profile
  -- The CASCADE constraint on kitchen_users will automatically remove team kitchen memberships
  
  RETURN OLD;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.handle_deleted_user() TO service_role;

-- Add comment
COMMENT ON FUNCTION public.handle_deleted_user() IS 
'Automatically deletes a user''s personal kitchen and all associated data when the user is deleted from auth.users. '
'Triggered BEFORE DELETE on auth.users to ensure personal kitchen is removed before cascade deletes occur.';

-- ============================================================================
-- 2. Create trigger on auth.users to auto-delete personal kitchen
-- ============================================================================
DO $$
BEGIN
  CREATE TRIGGER on_auth_user_deleted
    BEFORE DELETE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_deleted_user();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Trigger on_auth_user_deleted already exists, skipping';
END
$$;

-- ============================================================================
-- 3. Rename and simplify user deletion RPC
-- ============================================================================
-- Drop old function name
DROP FUNCTION IF EXISTS public.handle_user_delete();

-- Create with new name
CREATE OR REPLACE FUNCTION public.delete_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get the authenticated user's ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Log the deletion attempt
  RAISE NOTICE 'User deletion initiated for user_id: %', v_user_id;

  -- Delete the auth user
  -- The BEFORE DELETE trigger (on_auth_user_deleted) will automatically:
  -- 1. Delete the personal kitchen (cascades to all recipes/components)
  -- The CASCADE constraints will then automatically:
  -- 2. Remove team kitchen memberships (kitchen_users FK cascade)
  -- 3. Remove public.users profile (users FK cascade)
  RAISE NOTICE 'Deleting auth user: %', v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

  RAISE NOTICE 'User deletion completed for user_id: %', v_user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_user() TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION public.delete_user() IS 
'Handles complete user account deletion. Deletes the auth user, which triggers automatic cleanup: '
'1. Personal kitchen deletion (via on_auth_user_deleted trigger) '
'2. Team kitchen membership removal (via FK cascade) '
'3. Public user profile deletion (via FK cascade). '
'Must be called by an authenticated user to delete their own account.';

