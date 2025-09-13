-- First, create a trigger function that will update the public.users table
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
  
  RETURN NEW;
END;
$$;

-- Now create the trigger on the auth.users table
CREATE OR REPLACE TRIGGER sync_user_data_to_public
AFTER UPDATE OF raw_user_meta_data, email
ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_auth_user_updates();