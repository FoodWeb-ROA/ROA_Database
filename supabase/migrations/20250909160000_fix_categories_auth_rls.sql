-- Fix categories RLS to wrap auth.* calls in SELECT for performance
-- See: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

BEGIN;

-- SELECT
ALTER POLICY categories_select ON public.categories
USING (
  (select auth.uid()) IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.kitchen_users ku
    WHERE ku.user_id = (select auth.uid())
      AND ku.kitchen_id = categories.kitchen_id
  )
);

-- INSERT
ALTER POLICY categories_insert ON public.categories
WITH CHECK (
  (select auth.uid()) IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.kitchen_users ku
    WHERE ku.user_id = (select auth.uid())
      AND ku.kitchen_id = categories.kitchen_id
  )
);

-- UPDATE
ALTER POLICY categories_update ON public.categories
USING (
  (select auth.uid()) IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.kitchen_users ku
    WHERE ku.user_id = (select auth.uid())
      AND ku.kitchen_id = categories.kitchen_id
  )
)
WITH CHECK (
  (select auth.uid()) IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.kitchen_users ku
    WHERE ku.user_id = (select auth.uid())
      AND ku.kitchen_id = categories.kitchen_id
  )
);

-- DELETE
ALTER POLICY categories_delete ON public.categories
USING (
  (select auth.uid()) IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.kitchen_users ku
    WHERE ku.user_id = (select auth.uid())
      AND ku.kitchen_id = categories.kitchen_id
  )
);

COMMIT;


