-- Migration: Add user deletion function
-- This function handles cascading deletion of user data when a user deletes their account
-- Following Supabase best practices: https://supabase.com/docs/guides/auth/managing-user-data

-- Function to handle user deletion
-- This will be called when a user deletes their account from the app
CREATE OR REPLACE FUNCTION public.handle_user_delete()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
  v_personal_kitchen_id uuid;
BEGIN
  -- Get the authenticated user's ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Log the deletion attempt
  RAISE NOTICE 'User deletion initiated for user_id: %', v_user_id;

  -- Find the user's personal kitchen
  SELECT k.kitchen_id INTO v_personal_kitchen_id
  FROM public.kitchen k
  INNER JOIN public.kitchen_users ku ON k.kitchen_id = ku.kitchen_id
  WHERE ku.user_id = v_user_id
    AND k.type = 'Personal'
  LIMIT 1;

  -- Delete the personal kitchen first (this will cascade to all kitchen-related data)
  -- The CASCADE constraints will handle:
  -- - kitchen_users entries for this kitchen
  -- - kitchen_invites
  -- - categories
  -- - recipes (dishes and preparations)
  -- - components
  -- - recipe_components
  IF v_personal_kitchen_id IS NOT NULL THEN
    RAISE NOTICE 'Deleting personal kitchen: %', v_personal_kitchen_id;
    DELETE FROM public.kitchen WHERE kitchen_id = v_personal_kitchen_id;
  END IF;

  -- Delete the auth user
  -- This MUST come before deleting public.users because public.users has a FK to auth.users
  -- The CASCADE constraint on kitchen_users will automatically remove team kitchen memberships
  -- The CASCADE constraint on public.users will automatically remove the public profile
  RAISE NOTICE 'Deleting auth user: %', v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

  RAISE NOTICE 'User deletion completed for user_id: %', v_user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.handle_user_delete() TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION public.handle_user_delete() IS 
'Handles complete user account deletion including all associated data. '
'Deletes personal kitchen (cascades to all recipes/components), removes team kitchen memberships, '
'and deletes the auth user account. Must be called by an authenticated user to delete their own account.';
