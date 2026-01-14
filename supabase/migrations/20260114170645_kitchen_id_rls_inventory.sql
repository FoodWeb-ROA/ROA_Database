-- Add kitchen_id to suppliers table
ALTER TABLE public.suppliers
  ADD COLUMN kitchen_id uuid NOT NULL;

-- Add kitchen_id to orders table
ALTER TABLE public.orders
  ADD COLUMN kitchen_id uuid NOT NULL;

-- Add kitchen_id to batches table
ALTER TABLE public.batches
  ADD COLUMN kitchen_id uuid NOT NULL;

-- Add foreign key constraints
ALTER TABLE public.suppliers
  ADD CONSTRAINT suppliers_kitchen_id_fkey
  FOREIGN KEY (kitchen_id) REFERENCES public.kitchen(kitchen_id)
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_kitchen_id_fkey
  FOREIGN KEY (kitchen_id) REFERENCES public.kitchen(kitchen_id)
  ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE public.batches
  ADD CONSTRAINT batches_kitchen_id_fkey
  FOREIGN KEY (kitchen_id) REFERENCES public.kitchen(kitchen_id)
  ON UPDATE CASCADE ON DELETE CASCADE;

-- Create indexes on kitchen_id for better query performance
CREATE INDEX suppliers_kitchen_id_idx ON public.suppliers(kitchen_id);
CREATE INDEX orders_kitchen_id_idx ON public.orders(kitchen_id);
CREATE INDEX batches_kitchen_id_idx ON public.batches(kitchen_id);

-- ============================================================================
-- RLS POLICIES FOR SUPPLIERS
-- ============================================================================

-- Service role: full access
CREATE POLICY suppliers_service_role_select
  ON public.suppliers FOR SELECT
  TO service_role
  USING (true);

-- Authenticated users: SELECT - can read suppliers from their kitchens
CREATE POLICY suppliers_authenticated_select
  ON public.suppliers FOR SELECT
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- Authenticated users: INSERT - can create suppliers in kitchens they're members of
CREATE POLICY suppliers_authenticated_insert
  ON public.suppliers FOR INSERT
  TO authenticated
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- Authenticated users: UPDATE - can update suppliers in kitchens with write access
CREATE POLICY suppliers_authenticated_update
  ON public.suppliers FOR UPDATE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  )
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- Authenticated users: DELETE - can delete suppliers in kitchens with write access
CREATE POLICY suppliers_authenticated_delete
  ON public.suppliers FOR DELETE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- ============================================================================
-- RLS POLICIES FOR ORDERS
-- ============================================================================

-- Service role: full access
CREATE POLICY orders_service_role_select
  ON public.orders FOR SELECT
  TO service_role
  USING (true);

-- Authenticated users: SELECT - can read orders from their kitchens
CREATE POLICY orders_authenticated_select
  ON public.orders FOR SELECT
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- Authenticated users: INSERT - can create orders in kitchens they're members of
CREATE POLICY orders_authenticated_insert
  ON public.orders FOR INSERT
  TO authenticated
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- Authenticated users: UPDATE - can update orders in kitchens with write access
CREATE POLICY orders_authenticated_update
  ON public.orders FOR UPDATE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  )
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- Authenticated users: DELETE - can delete orders in kitchens with write access
CREATE POLICY orders_authenticated_delete
  ON public.orders FOR DELETE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- ============================================================================
-- RLS POLICIES FOR BATCHES
-- ============================================================================

-- Service role: full access
CREATE POLICY batches_service_role_select
  ON public.batches FOR SELECT
  TO service_role
  USING (true);

-- Authenticated users: SELECT - can read batches from their kitchens
CREATE POLICY batches_authenticated_select
  ON public.batches FOR SELECT
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- Authenticated users: INSERT - can create batches in kitchens they're members of
CREATE POLICY batches_authenticated_insert
  ON public.batches FOR INSERT
  TO authenticated
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- Authenticated users: UPDATE - can update batches in kitchens with write access
CREATE POLICY batches_authenticated_update
  ON public.batches FOR UPDATE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  )
  WITH CHECK (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );

-- Authenticated users: DELETE - can delete batches in kitchens with write access
CREATE POLICY batches_authenticated_delete
  ON public.batches FOR DELETE
  TO authenticated
  USING (
    kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      WHERE ku.user_id = auth.uid()
    )
  );
