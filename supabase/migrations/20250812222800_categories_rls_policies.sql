-- Migration: Ensure kitchen-scoped RLS policies on public.categories
-- Description: Enables RLS and defines SELECT / INSERT / UPDATE / DELETE policies
--              so that only members of the category's kitchen can access rows.

-- 1. Enable RLS
ALTER TABLE IF EXISTS public.categories ENABLE ROW LEVEL SECURITY;

-- 2. Helper expression reused in multiple policies
--    We use a WITH clause to avoid repeating text in each policy. Postgres 15+
--    supports USING/WITH CHECK expressions directly; earlier versions require
--    repetition. For simplicity we inline it.

-- 3. CREATE OR REPLACE policies (drop if exists to stay idempotent)
DROP POLICY IF EXISTS categories_select ON public.categories;
CREATE POLICY categories_select ON public.categories
  FOR SELECT
  USING ( auth.uid() IS NOT NULL
          AND EXISTS (
              SELECT 1 FROM public.kitchen_users ku
              WHERE ku.user_id = auth.uid()
                AND ku.kitchen_id = categories.kitchen_id
          ) );

DROP POLICY IF EXISTS categories_insert ON public.categories;
CREATE POLICY categories_insert ON public.categories
  FOR INSERT
  WITH CHECK ( auth.uid() IS NOT NULL
               AND EXISTS (
                   SELECT 1 FROM public.kitchen_users ku
                   WHERE ku.user_id = auth.uid()
                     AND ku.kitchen_id = categories.kitchen_id
               ) );

DROP POLICY IF EXISTS categories_update ON public.categories;
CREATE POLICY categories_update ON public.categories
  FOR UPDATE
  USING ( auth.uid() IS NOT NULL
          AND EXISTS (
              SELECT 1 FROM public.kitchen_users ku
              WHERE ku.user_id = auth.uid()
                AND ku.kitchen_id = categories.kitchen_id
          ) )
  WITH CHECK ( auth.uid() IS NOT NULL
               AND EXISTS (
                   SELECT 1 FROM public.kitchen_users ku
                   WHERE ku.user_id = auth.uid()
                     AND ku.kitchen_id = categories.kitchen_id
               ) );

DROP POLICY IF EXISTS categories_delete ON public.categories;
CREATE POLICY categories_delete ON public.categories
  FOR DELETE
  USING ( auth.uid() IS NOT NULL
          AND EXISTS (
              SELECT 1 FROM public.kitchen_users ku
              WHERE ku.user_id = auth.uid()
                AND ku.kitchen_id = categories.kitchen_id
          ) );
