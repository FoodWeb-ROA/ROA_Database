-- Migration: Grant privileges on categories table to anon & authenticated roles
-- Description: Ensures Supabase REST clients can access the public.categories table after rename.

-- 1. Grant table privileges (idempotent – duplicates are ignored by Postgres)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.categories TO anon, authenticated;

-- 2. Grant usage on the sequence if it exists (created when category_id is serial/identity)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'S'
      AND n.nspname = 'public'
      AND c.relname = 'categories_category_id_seq'
  ) THEN
    EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE public.categories_category_id_seq TO anon, authenticated;';
  END IF;
END $$;
