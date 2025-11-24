-- Migration: Fix auth triggers and kitchen management
-- This migration:
-- 1. Drops old delete_user_kitchen function (replaced by handle_user_delete)
-- 2. Updates handle_auth_user_updates to maintain personal kitchen names on email change
-- 3. Updates handle_new_user to create personal kitchens
-- 4. Ensures triggers are properly attached to auth.users

-- ============================================================================
-- 1. Drop old delete_user_kitchen function (no longer needed)
-- ============================================================================
DROP FUNCTION IF EXISTS public.delete_user_kitchen() CASCADE;

-- ============================================================================
-- 2. Update handle_auth_user_updates to maintain personal kitchen names
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_auth_user_updates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  -- Update the corresponding record in public.users
  UPDATE public.users
  SET 
    user_fullname = NEW.raw_user_meta_data->>'full_name',
    user_email = NEW.email,
    updated_at = now()
  WHERE user_id = NEW.id;
  
  -- If no record exists yet (unlikely with proper setup, but as a fallback)
  -- Insert a new record
  IF NOT FOUND THEN
    INSERT INTO public.users (user_id, user_fullname, user_email)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', NEW.email);
  END IF;
  
  -- Update the user's personal kitchen name if email changed
  -- Personal kitchens are named after the user's email
  IF OLD.email IS DISTINCT FROM NEW.email THEN
    UPDATE public.kitchen
    SET 
      kitchen_name = NEW.email,
      updated_at = now()
    WHERE kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      INNER JOIN public.kitchen k ON k.kitchen_id = ku.kitchen_id
      WHERE ku.user_id = NEW.id
        AND k.type = 'Personal'
    );
    
    RAISE NOTICE 'Updated personal kitchen name from % to % for user %', OLD.email, NEW.email, NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.handle_auth_user_updates() TO service_role;

-- Add comment
COMMENT ON FUNCTION public.handle_auth_user_updates() IS 
'Syncs auth.users changes to public.users and updates personal kitchen names when email changes. '
'Triggered by UPDATE on auth.users (raw_user_meta_data or email).';

-- ============================================================================
-- 3. Update handle_new_user to create personal kitchens
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_kitchen_id uuid;
BEGIN
  -- Insert the user into public.users
  INSERT INTO public.users (user_id, user_email, user_fullname)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name'
  );
  
  -- Create a personal kitchen for the new user
  -- Kitchen name is the user's email address
  INSERT INTO public.kitchen (kitchen_name, type)
  VALUES (NEW.email, 'Personal')
  RETURNING kitchen_id INTO v_kitchen_id;
  
  -- Link the user to their personal kitchen as an admin
  INSERT INTO public.kitchen_users (user_id, kitchen_id, is_admin)
  VALUES (NEW.id, v_kitchen_id, true);
  
  RAISE NOTICE 'Created personal kitchen % for user % (%)', v_kitchen_id, NEW.id, NEW.email;
  
  RETURN NEW;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- Add comment
COMMENT ON FUNCTION public.handle_new_user() IS 
'Creates a new user record in public.users and automatically creates a personal kitchen for them. '
'The personal kitchen is named after the user''s email address. '
'Triggered by INSERT on auth.users.';

-- ============================================================================
-- 4. Ensure triggers are properly attached to auth.users
-- ============================================================================

-- Create trigger for new user creation (will fail silently if exists)
DO $$
BEGIN
  CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Trigger on_auth_user_created already exists, skipping';
END
$$;

-- Create trigger for user updates (will fail silently if exists)
DO $$
BEGIN
  CREATE OR REPLACE TRIGGER sync_user_data_to_public
    AFTER UPDATE OF raw_user_meta_data, email ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_auth_user_updates();
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Trigger sync_user_data_to_public already exists, skipping';
END
$$;

-- Note: Cannot add comments on triggers in auth schema due to ownership restrictions
-- Trigger descriptions are documented in the function comments instead
