-- Migration: Fix kitchen name column references
-- The kitchen table uses 'name' not 'kitchen_name'

-- ============================================================================
-- 1. Fix handle_auth_user_updates to use correct column name
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
      name = NEW.email,
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

-- ============================================================================
-- 2. Fix handle_new_user to use correct column name
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
  INSERT INTO public.kitchen (name, type)
  VALUES (NEW.email, 'Personal')
  RETURNING kitchen_id INTO v_kitchen_id;
  
  -- Link the user to their personal kitchen as an admin
  INSERT INTO public.kitchen_users (user_id, kitchen_id, is_admin)
  VALUES (NEW.id, v_kitchen_id, true);
  
  RAISE NOTICE 'Created personal kitchen % for user % (%)', v_kitchen_id, NEW.id, NEW.email;
  
  RETURN NEW;
END;
$$;
