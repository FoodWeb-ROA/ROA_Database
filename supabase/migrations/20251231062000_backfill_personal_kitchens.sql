-- Migration: Backfill Personal Kitchens for All Users
-- Created: 2025-12-31
-- Description:
--   Ensures every user has a personal kitchen and is properly linked via kitchen_users
--   Backfills any missing personal kitchens and links

-- =============================================================================
-- 1. Backfill: Create personal kitchens for users who don't have one
-- =============================================================================

DO $$
DECLARE
  v_user_record RECORD;
  v_kitchen_id uuid;
  v_existing_kitchen_id uuid;
  v_created_count int := 0;
  v_linked_count int := 0;
BEGIN
  RAISE NOTICE 'Starting personal kitchen backfill...';
  
  -- Find all users who don't have a personal kitchen
  FOR v_user_record IN
    SELECT u.user_id, u.user_email
    FROM public.users u
    WHERE NOT EXISTS (
      SELECT 1 
      FROM public.kitchen k
      INNER JOIN public.kitchen_users ku ON k.kitchen_id = ku.kitchen_id
      WHERE k.type = 'Personal'
        AND ku.user_id = u.user_id
    )
  LOOP
    BEGIN
      -- Check if a personal kitchen exists but isn't linked
      SELECT k.kitchen_id INTO v_existing_kitchen_id
      FROM public.kitchen k
      WHERE k.type = 'Personal'
        AND k.name = v_user_record.user_email
        AND k.owner_user_id IS NULL
      LIMIT 1;
      
      IF v_existing_kitchen_id IS NOT NULL THEN
        -- Kitchen exists but isn't linked - just create the link
        RAISE NOTICE 'Linking existing personal kitchen % to user % (%)', 
          v_existing_kitchen_id, v_user_record.user_id, v_user_record.user_email;
        
        INSERT INTO public.kitchen_users (user_id, kitchen_id, is_admin)
        VALUES (v_user_record.user_id, v_existing_kitchen_id, true)
        ON CONFLICT DO NOTHING;
        
        v_linked_count := v_linked_count + 1;
      ELSE
        -- No personal kitchen exists - create one
        RAISE NOTICE 'Creating personal kitchen for user % (%)', 
          v_user_record.user_id, v_user_record.user_email;
        
        INSERT INTO public.kitchen (name, type, owner_user_id)
        VALUES (v_user_record.user_email, 'Personal', NULL)
        RETURNING kitchen_id INTO v_kitchen_id;
        
        -- Link the user to their personal kitchen
        INSERT INTO public.kitchen_users (user_id, kitchen_id, is_admin)
        VALUES (v_user_record.user_id, v_kitchen_id, true);
        
        v_created_count := v_created_count + 1;
      END IF;
      
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Failed to create/link personal kitchen for user %: %', 
        v_user_record.user_id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Backfill completed. Created: %, Linked: %', v_created_count, v_linked_count;
END;
$$;

-- =============================================================================
-- 2. Verify and fix the trigger is properly attached
-- =============================================================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Recreate the trigger to ensure it's working
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();