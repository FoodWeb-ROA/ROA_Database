-- Enable REPLICA IDENTITY FULL for all realtime tables
-- This is required for Supabase Realtime to work correctly with filtered subscriptions
-- Without this, realtime events may fail with "mismatch between server and client bindings" errors

-- Recipe-related tables
ALTER TABLE public.recipes REPLICA IDENTITY FULL;
ALTER TABLE public.components REPLICA IDENTITY FULL;
ALTER TABLE public.recipe_components REPLICA IDENTITY FULL;

-- Kitchen-related tables
ALTER TABLE public.kitchen REPLICA IDENTITY FULL;
ALTER TABLE public.kitchen_users REPLICA IDENTITY FULL;
ALTER TABLE public.kitchen_invites REPLICA IDENTITY FULL;
ALTER TABLE public.categories REPLICA IDENTITY FULL;

-- User table
ALTER TABLE public.users REPLICA IDENTITY FULL;

-- Verify replica identity settings
DO $$
DECLARE
    tbl_name TEXT;
    replica_setting TEXT;
BEGIN
    FOR tbl_name IN 
        SELECT unnest(ARRAY['recipes', 'components', 'recipe_components', 'kitchen', 'kitchen_users', 'kitchen_invites', 'categories', 'users'])
    LOOP
        SELECT relreplident INTO replica_setting
        FROM pg_class
        WHERE relname = tbl_name AND relnamespace = 'public'::regnamespace;
        
        IF replica_setting = 'f' THEN
            RAISE NOTICE 'Table %.% has REPLICA IDENTITY FULL enabled', 'public', tbl_name;
        ELSE
            RAISE WARNING 'Table %.% does not have REPLICA IDENTITY FULL (current: %)', 'public', tbl_name, replica_setting;
        END IF;
    END LOOP;
END $$;
