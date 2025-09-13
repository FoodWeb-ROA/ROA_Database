-- Migration: Rename menu_section table to categories
-- Timestamp: 2025-07-31 22:29:30+01:00
-- Description: Renames the existing public.menu_section table to public.categories while preserving all data and constraints.

-- Start transaction is implicit in Supabase migration runner

-- 1. Rename the table
ALTER TABLE IF EXISTS public.menu_section RENAME TO categories;

-- 2. OPTIONAL: Rename primary key constraint to follow convention (pk_categories)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        WHERE t.relname = 'categories'
          AND c.contype = 'p'
          AND c.conname = 'menu_section_pkey'
    ) THEN
        ALTER TABLE public.categories RENAME CONSTRAINT menu_section_pkey TO categories_pkey;
    END IF;
END $$;

-- 3. Rename primary key column if necessary
--    We handle two possible existing column names: "menu_section_id" (typical) or simply "id".
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'categories'
          AND column_name  = 'menu_section_id'
    ) THEN
        ALTER TABLE public.categories RENAME COLUMN menu_section_id TO category_id;
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'categories'
          AND column_name  = 'id'
    ) THEN
        ALTER TABLE public.categories RENAME COLUMN id TO category_id;
    END IF;
END $$;

-- 4. Rename RLS policies to match new table name
--    This covers the four standard policies defined previously.
ALTER POLICY IF EXISTS menu_section_select ON public.categories RENAME TO categories_select;
ALTER POLICY IF EXISTS menu_section_insert ON public.categories RENAME TO categories_insert;
ALTER POLICY IF EXISTS menu_section_update ON public.categories RENAME TO categories_update;
ALTER POLICY IF EXISTS menu_section_delete ON public.categories RENAME TO categories_delete;

-- 5. Rename foreign key column in recipes table
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'recipes'
          AND column_name  = 'menu_section_id'
    ) THEN
        -- Rename the column
        ALTER TABLE public.recipes RENAME COLUMN menu_section_id TO category_id;
    END IF;

    -- Rename foreign key constraint if it used the old name
    IF EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        WHERE t.relname = 'recipes'
          AND c.contype = 'f'
          AND c.conname = 'recipe_menu_section_id_fkey'
    ) THEN
        ALTER TABLE public.recipes RENAME CONSTRAINT recipe_menu_section_id_fkey TO recipe_category_id_fkey;
    END IF;
END $$;

-- 6. OPTIONAL: Rename sequence if it exists (menu_section_menu_section_id_seq -> categories_category_id_seq)
DO $$
DECLARE
    seq_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_class WHERE relkind = 'S' AND relname = 'menu_section_menu_section_id_seq'
    ) INTO seq_exists;

    IF seq_exists THEN
        ALTER SEQUENCE IF EXISTS menu_section_menu_section_id_seq RENAME TO categories_category_id_seq;
    END IF;
END $$;

-- 4. NOTE: Any foreign key constraints or indexes referencing the old table name remain valid; only their names might still include the old table name which is cosmetic.
-- End of migration
