-- Enable Realtime replication for tables used by the mobile app
-- This ensures changes are broadcast on the 'supabase_realtime' publication

-- Create the publication if it does not exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

-- Helper to add a table to the publication if not already present
DO $$
DECLARE
  rel regclass;
BEGIN
  -- recipe_components
  BEGIN
    rel := 'public.recipe_components'::regclass;
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'recipe_components'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.recipe_components';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    -- table may not exist yet in earlier environments; ignore
    NULL;
  END;

  -- kitchen_invites
  BEGIN
    rel := 'public.kitchen_invites'::regclass;
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'kitchen_invites'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.kitchen_invites';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    NULL;
  END;

  -- users (public users table)
  BEGIN
    rel := 'public.users'::regclass;
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'users'
    ) THEN
      EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.users';
    END IF;
  EXCEPTION WHEN undefined_table THEN
    NULL;
  END;
END $$;


