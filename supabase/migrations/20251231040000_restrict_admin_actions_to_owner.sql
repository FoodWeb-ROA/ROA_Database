-- Migration: Restrict admin actions to kitchen owners only
-- Created: 2025-12-31
-- Description:
--   Only kitchen owners can:
--   - Grant/revoke admin privileges (UPDATE kitchen_users.is_admin)
--   - Remove users from kitchen (DELETE from kitchen_users)
--   - Rename kitchen (UPDATE kitchen.name)
--   
--   Non-owner admins can no longer perform these actions.

-- =============================================================================
-- 1. Update kitchen_users RLS policies for admin status changes
-- =============================================================================

-- Drop existing policy if it exists (admins can update)
DROP POLICY IF EXISTS "Admins can update kitchen_users" ON public.kitchen_users;
DROP POLICY IF EXISTS "Admins can manage kitchen users" ON public.kitchen_users;
DROP POLICY IF EXISTS "Kitchen admins can update kitchen_users" ON public.kitchen_users;

-- New policy: Only owners can update is_admin
CREATE POLICY "Only kitchen owner can update admin status"
ON public.kitchen_users
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.kitchen k
    WHERE k.kitchen_id = kitchen_users.kitchen_id
    AND k.owner_user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.kitchen k
    WHERE k.kitchen_id = kitchen_users.kitchen_id
    AND k.owner_user_id = auth.uid()
  )
);

-- =============================================================================
-- 2. Update kitchen_users RLS policies for user removal
-- =============================================================================

-- Drop existing delete policies
DROP POLICY IF EXISTS "Admins can delete kitchen_users" ON public.kitchen_users;
DROP POLICY IF EXISTS "Kitchen admins can delete kitchen_users" ON public.kitchen_users;

-- New policy: Only owners can remove users
CREATE POLICY "Only kitchen owner can remove users"
ON public.kitchen_users
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM public.kitchen k
    WHERE k.kitchen_id = kitchen_users.kitchen_id
    AND k.owner_user_id = auth.uid()
  )
);

-- =============================================================================
-- 3. Update kitchen RLS policies for renaming
-- =============================================================================

-- Drop existing update policies that allow admins
DROP POLICY IF EXISTS "Admins can update kitchen" ON public.kitchen;
DROP POLICY IF EXISTS "Kitchen admins can update kitchen name" ON public.kitchen;

-- New policy: Only owners can update kitchen name
CREATE POLICY "Only kitchen owner can update kitchen"
ON public.kitchen
FOR UPDATE
USING (
  owner_user_id = auth.uid()
)
WITH CHECK (
  owner_user_id = auth.uid()
);

-- =============================================================================
-- Comments
-- =============================================================================

COMMENT ON POLICY "Only kitchen owner can update admin status" ON public.kitchen_users IS 
  'Restricts admin privilege management to kitchen owners only';

COMMENT ON POLICY "Only kitchen owner can remove users" ON public.kitchen_users IS 
  'Restricts user removal to kitchen owners only';

COMMENT ON POLICY "Only kitchen owner can update kitchen" ON public.kitchen IS 
  'Restricts kitchen updates (including name changes) to owners only';
