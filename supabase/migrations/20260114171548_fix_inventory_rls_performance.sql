-- Fix auth_rls_initplan warnings by wrapping auth.uid() in SELECT
-- Fix duplicate index on suppliers table

-- ============================================================================
-- DROP EXISTING POLICIES
-- ============================================================================

DROP POLICY IF EXISTS suppliers_authenticated_select ON public.suppliers;
DROP POLICY IF EXISTS suppliers_authenticated_insert ON public.suppliers;
DROP POLICY IF EXISTS suppliers_authenticated_update ON public.suppliers;
DROP POLICY IF EXISTS suppliers_authenticated_delete ON public.suppliers;

DROP POLICY IF EXISTS orders_authenticated_select ON public.orders;
DROP POLICY IF EXISTS orders_authenticated_insert ON public.orders;
DROP POLICY IF EXISTS orders_authenticated_update ON public.orders;
DROP POLICY IF EXISTS orders_authenticated_delete ON public.orders;

DROP POLICY IF EXISTS batches_authenticated_select ON public.batches;
DROP POLICY IF EXISTS batches_authenticated_insert ON public.batches;
DROP POLICY IF EXISTS batches_authenticated_update ON public.batches;
DROP POLICY IF EXISTS batches_authenticated_delete ON public.batches;

-- ============================================================================
-- FIX DUPLICATE INDEX ON SUPPLIERS
-- ============================================================================

-- Drop duplicate UNIQUE constraint (which creates the duplicate index)
-- Keep only the primary key constraint
ALTER TABLE public.suppliers DROP CONSTRAINT IF EXISTS suppliers_supplier_id_key;

-- ============================================================================
-- RECREATE RLS POLICIES FOR SUPPLIERS (with optimized auth.uid())
-- ============================================================================

CREATE POLICY suppliers_authenticated_select
  ON public.suppliers FOR SELECT
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

CREATE POLICY suppliers_authenticated_insert
  ON public.suppliers FOR INSERT
  TO authenticated
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

CREATE POLICY suppliers_authenticated_update
  ON public.suppliers FOR UPDATE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  )
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

CREATE POLICY suppliers_authenticated_delete
  ON public.suppliers FOR DELETE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

-- ============================================================================
-- RECREATE RLS POLICIES FOR ORDERS (with optimized auth.uid())
-- ============================================================================

CREATE POLICY orders_authenticated_select
  ON public.orders FOR SELECT
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

CREATE POLICY orders_authenticated_insert
  ON public.orders FOR INSERT
  TO authenticated
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

CREATE POLICY orders_authenticated_update
  ON public.orders FOR UPDATE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  )
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

CREATE POLICY orders_authenticated_delete
  ON public.orders FOR DELETE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

-- ============================================================================
-- RECREATE RLS POLICIES FOR BATCHES (with optimized auth.uid())
-- ============================================================================

CREATE POLICY batches_authenticated_select
  ON public.batches FOR SELECT
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

CREATE POLICY batches_authenticated_insert
  ON public.batches FOR INSERT
  TO authenticated
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

CREATE POLICY batches_authenticated_update
  ON public.batches FOR UPDATE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  )
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );

CREATE POLICY batches_authenticated_delete
  ON public.batches FOR DELETE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = (select auth.uid())
    )
  );
