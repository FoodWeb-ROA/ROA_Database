-- migrate:up
-- Migration: Fix categories relation naming inconsistencies (idempotent)
-- Created: 2025-08-12 22:15:00+01:00
-- Description: Ensures the `public.categories` table and all related columns / constraints
--              are present with the correct names, regardless of prior state.
--              Designed to be SAFE TO RUN repeatedly.

BEGIN;

-- 1. Rename table if it still uses the old name
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'categories'
    )
    AND EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'menu_section'
    ) THEN
        ALTER TABLE public.menu_section RENAME TO categories;
    END IF;
END $$;

-- 2. Ensure primary-key column is `category_id`
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'categories' AND column_name = 'menu_section_id'
    ) THEN
        ALTER TABLE public.categories RENAME COLUMN menu_section_id TO category_id;
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'categories' AND column_name = 'id'
    ) THEN
        ALTER TABLE public.categories RENAME COLUMN id TO category_id;
    END IF;
END $$;

-- 3. Ensure primary-key constraint is named `categories_pkey`
DO $$
DECLARE
    pkey_name text;
BEGIN
    SELECT c.conname INTO pkey_name
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'categories' AND c.contype = 'p';

    IF pkey_name = 'menu_section_pkey' THEN
        ALTER TABLE public.categories RENAME CONSTRAINT menu_section_pkey TO categories_pkey;
    END IF;
END $$;

-- 4. Fix column / FK on recipes table
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'recipes' AND column_name = 'menu_section_id'
    ) THEN
        ALTER TABLE public.recipes RENAME COLUMN menu_section_id TO category_id;
    END IF;

    -- Rename FK constraint if it still has the old name
    IF EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        WHERE t.relname = 'recipes' AND c.contype = 'f' AND c.conname = 'recipe_menu_section_id_fkey'
    ) THEN
        ALTER TABLE public.recipes RENAME CONSTRAINT recipe_menu_section_id_fkey TO recipe_category_id_fkey;
    END IF;
END $$;

-- 5. Re-create / validate FK so it references the correct objects
ALTER TABLE IF EXISTS public.recipes
    DROP CONSTRAINT IF EXISTS recipe_category_id_fkey,
    ADD CONSTRAINT recipe_category_id_fkey
        FOREIGN KEY (category_id) REFERENCES public.categories(category_id) ON DELETE SET NULL;

-- 6. Clean up RLS policy names on the categories table (idempotent)
DO $$
BEGIN
    -- SELECT
    IF EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'categories' AND policyname = 'menu_section_select'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies
            WHERE schemaname = 'public' AND tablename = 'categories' AND policyname = 'categories_select'
        ) THEN
            ALTER POLICY menu_section_select ON public.categories RENAME TO categories_select;
        ELSE
            DROP POLICY IF EXISTS menu_section_select ON public.categories;
        END IF;
    END IF;

    -- INSERT
    IF EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'categories' AND policyname = 'menu_section_insert'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'categories' AND policyname = 'categories_insert'
        ) THEN
            ALTER POLICY menu_section_insert ON public.categories RENAME TO categories_insert;
        ELSE
            DROP POLICY IF EXISTS menu_section_insert ON public.categories;
        END IF;
    END IF;

    -- UPDATE
    IF EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'categories' AND policyname = 'menu_section_update'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'categories' AND policyname = 'categories_update'
        ) THEN
            ALTER POLICY menu_section_update ON public.categories RENAME TO categories_update;
        ELSE
            DROP POLICY IF EXISTS menu_section_update ON public.categories;
        END IF;
    END IF;

    -- DELETE
    IF EXISTS (
        SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'categories' AND policyname = 'menu_section_delete'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'categories' AND policyname = 'categories_delete'
        ) THEN
            ALTER POLICY menu_section_delete ON public.categories RENAME TO categories_delete;
        ELSE
            DROP POLICY IF EXISTS menu_section_delete ON public.categories;
        END IF;
    END IF;
END $$;

COMMIT;

-- migrate:down
-- Manual rollback not provided (no-op)
BEGIN;
ROLLBACK;
