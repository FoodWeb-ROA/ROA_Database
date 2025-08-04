-- Migration: Rename recipe_category_id_fkey to category_id_fkey
-- Timestamp: 2025-08-04 23:17:22+01:00
-- Description: Aligns foreign key name with frontend queries that expect `category_id_fkey`.
--            This affects the `recipes.category_id` foreign key referencing `categories.category_id`.
--            No data changes are performed.

BEGIN;

-- Rename the foreign-key constraint if it still uses the old name
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        WHERE t.relname = 'recipes'
          AND c.contype = 'f'
          AND c.conname = 'recipe_category_id_fkey'
    ) THEN
        ALTER TABLE public.recipes RENAME CONSTRAINT recipe_category_id_fkey TO category_id_fkey;
    END IF;
END $$;

COMMIT;
