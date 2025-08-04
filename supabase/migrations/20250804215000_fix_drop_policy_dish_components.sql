-- migrate:up
-- Purpose: avoid error when dropping policy on non-existent dish_components table

DO $$
BEGIN
  -- Only attempt to drop the policy if the underlying table still exists
  IF to_regclass('public.dish_components') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated users to delete from dish_components" ON public.dish_components';
  END IF;
END $$;

-- Optionally, ensure legacy table is removed (safe on fresh DBs as well)
DROP TABLE IF EXISTS public.dish_components CASCADE;

-- migrate:down
-- No-op (policy and table were already dropped)
