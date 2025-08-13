-- Ensure functions reference fully-qualified tables to avoid search_path issues

-- is_user_kitchen_member
CREATE OR REPLACE FUNCTION public.is_user_kitchen_member(p_user_id uuid, p_kitchen_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.kitchen_users ku
        WHERE ku.user_id = p_user_id
          AND ku.kitchen_id = p_kitchen_id
    );
$$;

-- is_user_kitchen_admin
CREATE OR REPLACE FUNCTION public.is_user_kitchen_admin(p_user_id uuid, p_kitchen_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.kitchen_users ku
        WHERE ku.user_id = p_user_id
          AND ku.kitchen_id = p_kitchen_id
          AND ku.is_admin = true
    );
$$;

-- count_kitchen_admins
CREATE OR REPLACE FUNCTION public.count_kitchen_admins(p_kitchen_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
    SELECT COUNT(*)
    FROM public.kitchen_users ku
    WHERE ku.kitchen_id = p_kitchen_id
      AND ku.is_admin = true;
$$;

-- enforce_one_user_per_personal_kitchen
CREATE OR REPLACE FUNCTION public.enforce_one_user_per_personal_kitchen()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    kitchen_type TEXT;
BEGIN
    SELECT type INTO kitchen_type FROM public.kitchen WHERE kitchen_id = NEW.kitchen_id;

    IF kitchen_type = 'Personal' THEN
        -- Check if someone is already linked
        IF EXISTS (
            SELECT 1 FROM public.kitchen_users
            WHERE kitchen_id = NEW.kitchen_id
        ) THEN
            RAISE EXCEPTION 'Only one user can be linked to a Personal kitchen.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;
