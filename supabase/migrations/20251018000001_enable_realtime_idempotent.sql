-- Enable Realtime for all tables
-- This migration ensures all tables have REPLICA IDENTITY and are added to the realtime publication

-- Set REPLICA IDENTITY FULL for all tables that need realtime
ALTER TABLE IF EXISTS public.recipes REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.components REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.recipe_components REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.categories REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.kitchen REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.kitchen_users REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.kitchen_invites REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.users REPLICA IDENTITY FULL;

-- Add tables to realtime publication (ignore if already exists)
DO $$
BEGIN
    -- Add recipes table
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.recipes;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL; -- Table already in publication
    END;

    -- Add components table
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.components;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;

    -- Add recipe_components table
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.recipe_components;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;

    -- Add categories table
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;

    -- Add kitchen table
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.kitchen;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;

    -- Add kitchen_users table
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.kitchen_users;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;

    -- Add kitchen_invites table
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.kitchen_invites;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;

    -- Add users table
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
    EXCEPTION
        WHEN duplicate_object THEN
            NULL;
    END;
END $$;
