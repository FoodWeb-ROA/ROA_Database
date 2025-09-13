-- migrate:up
BEGIN;
-- Rename column total_time to "time" on public.recipes
-- Safe to re-run: only renames when the old column exists and the new one does not
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'recipes' AND column_name = 'total_time'
    ) THEN
        ALTER TABLE public.recipes RENAME COLUMN total_time TO "time";
        RAISE NOTICE 'Renamed public.recipes.total_time to "time"';
    ELSE
        RAISE NOTICE 'Skip rename: public.recipes.total_time not found (or already renamed)';
    END IF;
END;
$$;
COMMIT;

-- (no down migration)

