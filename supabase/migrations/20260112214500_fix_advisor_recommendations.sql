-- Fix Supabase Advisor Recommendations
-- This migration addresses security and performance issues identified by Supabase advisor

-- ==========================================
-- SECTION 1: Fix Function Search Path Issues
-- ==========================================
-- Add search_path to 6 functions to prevent search path injection attacks
-- Note: get_unit_measurement_type was dropped as it's unused in application code

-- Drop unused function
DROP FUNCTION IF EXISTS "public"."get_unit_measurement_type"("unit_abbr" "public"."unit");

-- 1. convert_amount_safe
CREATE OR REPLACE FUNCTION "public"."convert_amount_safe"("amount_val" numeric, "from_unit" "public"."unit", "to_unit" "public"."unit") 
RETURNS numeric
LANGUAGE "plpgsql" IMMUTABLE
SET search_path = public
AS $$
DECLARE
  from_kind TEXT;
  to_kind TEXT;
  -- Conversion factors to base units (g for mass, ml for volume)
  from_to_base NUMERIC;
  to_to_base NUMERIC;
  base_amount NUMERIC;
BEGIN
  -- Get measurement types
  from_kind := get_unit_kind(from_unit);
  to_kind := get_unit_kind(to_unit);
  
  -- Check if units are valid
  IF from_kind IS NULL OR to_kind IS NULL THEN
    RAISE WARNING 'Unknown unit type: % or %', from_unit, to_unit;
    RETURN NULL;
  END IF;
  
  -- Only convert if same measurement type
  IF from_kind != to_kind THEN
    RAISE WARNING 'Cannot convert between different measurement types: % (%) -> % (%)', 
      from_unit, from_kind, to_unit, to_kind;
    RETURN NULL;
  END IF;
  
  -- If same unit, no conversion needed
  IF from_unit = to_unit THEN
    RETURN amount_val;
  END IF;
  
  -- Handle count units (no conversion)
  IF from_kind = 'count' THEN
    RETURN amount_val;
  END IF;
  
  -- Handle preparation units (no conversion)
  IF from_kind = 'preparation' THEN
    RETURN amount_val;
  END IF;
  
  -- Mass conversions (base unit: g)
  IF from_kind = 'mass' THEN
    from_to_base := CASE from_unit
      WHEN 'mg' THEN 0.001
      WHEN 'g' THEN 1.0
      WHEN 'kg' THEN 1000.0
      WHEN 'oz' THEN 28.3495
      WHEN 'lb' THEN 453.592
      ELSE NULL
    END;
    
    to_to_base := CASE to_unit
      WHEN 'mg' THEN 0.001
      WHEN 'g' THEN 1.0
      WHEN 'kg' THEN 1000.0
      WHEN 'oz' THEN 28.3495
      WHEN 'lb' THEN 453.592
      ELSE NULL
    END;
    
    IF from_to_base IS NULL OR to_to_base IS NULL THEN
      RAISE WARNING 'Unsupported mass unit: % or %', from_unit, to_unit;
      RETURN amount_val;
    END IF;
    
    -- Convert: amount * from_factor / to_factor
    base_amount := amount_val * from_to_base;
    RETURN ROUND(base_amount / to_to_base, 4);
  END IF;
  
  -- Volume conversions (base unit: ml)
  IF from_kind = 'volume' THEN
    from_to_base := CASE from_unit
      WHEN 'ml' THEN 1.0
      WHEN 'l' THEN 1000.0
      WHEN 'tsp' THEN 4.92892
      WHEN 'tbsp' THEN 14.7868
      WHEN 'cup' THEN 236.588
      WHEN 'pt' THEN 473.176
      WHEN 'qt' THEN 946.353
      WHEN 'gal' THEN 3785.41
      ELSE NULL
    END;
    
    to_to_base := CASE to_unit
      WHEN 'ml' THEN 1.0
      WHEN 'l' THEN 1000.0
      WHEN 'tsp' THEN 4.92892
      WHEN 'tbsp' THEN 14.7868
      WHEN 'cup' THEN 236.588
      WHEN 'pt' THEN 473.176
      WHEN 'qt' THEN 946.353
      WHEN 'gal' THEN 3785.41
      ELSE NULL
    END;
    
    IF from_to_base IS NULL OR to_to_base IS NULL THEN
      RAISE WARNING 'Unsupported volume unit: % or %', from_unit, to_unit;
      RETURN amount_val;
    END IF;
    
    -- Convert: amount * from_factor / to_factor
    base_amount := amount_val * from_to_base;
    RETURN ROUND(base_amount / to_to_base, 4);
  END IF;
  
  -- Fallback: return original amount
  RAISE WARNING 'Unit conversion not implemented for kind: %', from_kind;
  RETURN amount_val;
END;
$$;

-- 2. get_unit_kind
CREATE OR REPLACE FUNCTION "public"."get_unit_kind"("unit_val" "public"."unit") 
RETURNS text
LANGUAGE "plpgsql" IMMUTABLE
SET search_path = public
AS $$
BEGIN
  CASE unit_val
    WHEN 'mg', 'g', 'kg', 'oz', 'lb' THEN
      RETURN 'mass';
    WHEN 'ml', 'l', 'tsp', 'tbsp', 'cup', 'pt', 'qt', 'gal' THEN
      RETURN 'volume';
    WHEN 'x' THEN
      RETURN 'count';
    WHEN 'prep' THEN
      RETURN 'preparation';
    ELSE
      RETURN NULL;
  END CASE;
END;
$$;

-- 3. recalculate_parent_amounts_on_yield_change
CREATE OR REPLACE FUNCTION "public"."recalculate_parent_amounts_on_yield_change"() 
RETURNS trigger
LANGUAGE "plpgsql"
SET search_path = public
AS $$
DECLARE
  old_measurement_type TEXT;
  new_measurement_type TEXT;
  parent_record RECORD;
  old_yield_amount NUMERIC;
  new_yield_amount NUMERIC;
  old_component_amount NUMERIC;
  old_component_amount_converted NUMERIC;
  new_component_amount NUMERIC;
  ratio NUMERIC;
BEGIN
  -- Only process if this is a preparation (not a dish)
  IF NEW.recipe_type != 'Preparation' THEN
    RETURN NEW;
  END IF;

  -- Only process if yield unit or yield amount changed
  IF OLD.serving_yield_unit = NEW.serving_yield_unit 
     AND OLD.serving_size_yield = NEW.serving_size_yield THEN
    RETURN NEW;
  END IF;

  -- Get measurement types for old and new units
  old_measurement_type := get_unit_kind(OLD.serving_yield_unit);
  new_measurement_type := get_unit_kind(NEW.serving_yield_unit);

  -- Only recalculate if measurement types differ (weight vs volume vs count)
  IF old_measurement_type IS NULL OR new_measurement_type IS NULL THEN
    RAISE WARNING 'Could not determine measurement types for units: % -> %', 
      OLD.serving_yield_unit, NEW.serving_yield_unit;
    RETURN NEW;
  END IF;

  IF old_measurement_type = new_measurement_type THEN
    -- Same measurement type, no recalculation needed (just unit conversion)
    RETURN NEW;
  END IF;

  -- Get yield amounts
  old_yield_amount := OLD.serving_size_yield;
  new_yield_amount := NEW.serving_size_yield;

  IF old_yield_amount IS NULL OR old_yield_amount = 0 
     OR new_yield_amount IS NULL OR new_yield_amount = 0 THEN
    RAISE WARNING 'Invalid yield amounts for recipe %: old=%, new=%', 
      NEW.recipe_id, old_yield_amount, new_yield_amount;
    RETURN NEW;
  END IF;

  RAISE NOTICE 'Recalculating parent amounts for prep % (% -> %): yield % % -> % %',
    NEW.recipe_name,
    old_measurement_type,
    new_measurement_type,
    old_yield_amount,
    OLD.serving_yield_unit,
    new_yield_amount,
    NEW.serving_yield_unit;

  -- Find all parent recipes that use this preparation
  FOR parent_record IN
    SELECT 
      rc.recipe_id,
      rc.component_id,
      rc.amount as current_amount,
      rc.unit as current_unit,
      r.recipe_name as parent_name
    FROM recipe_components rc
    JOIN components c ON c.component_id = rc.component_id
    JOIN recipes r ON r.recipe_id = rc.recipe_id
    WHERE c.recipe_id = NEW.recipe_id  -- This component references our prep
      AND rc.amount IS NOT NULL
      AND rc.amount > 0
  LOOP
    old_component_amount := parent_record.current_amount;
    
    -- Convert old component amount to old yield unit for proper ratio calculation
    -- This ensures we're comparing apples to apples (e.g., 1000g -> 1kg before dividing by 1kg)
    old_component_amount_converted := convert_amount_safe(
      old_component_amount,
      parent_record.current_unit,
      OLD.serving_yield_unit
    );
    
    IF old_component_amount_converted IS NULL THEN
      -- Conversion failed, use original amount (may be inaccurate but better than blocking)
      RAISE WARNING 'Could not convert % % to % for ratio calculation, using original amount',
        old_component_amount, parent_record.current_unit, OLD.serving_yield_unit;
      old_component_amount_converted := old_component_amount;
    END IF;
    
    -- Calculate ratio: (converted_amount_in_parent / old_yield) * new_yield
    -- This maintains the same proportion of the preparation
    ratio := old_component_amount_converted / old_yield_amount;
    new_component_amount := ratio * new_yield_amount;

    RAISE NOTICE '  Updating % in %: % % (converted: % %) -> % % (ratio: %)',
      NEW.recipe_name,
      parent_record.parent_name,
      old_component_amount,
      parent_record.current_unit,
      old_component_amount_converted,
      OLD.serving_yield_unit,
      new_component_amount,
      NEW.serving_yield_unit,
      ratio;

    -- Update the parent recipe component
    UPDATE recipe_components
    SET 
      amount = new_component_amount,
      unit = NEW.serving_yield_unit,
      updated_at = NOW()
    WHERE recipe_id = parent_record.recipe_id
      AND component_id = parent_record.component_id;
  END LOOP;

  RETURN NEW;
END;
$$;

-- 5. set_updated_at
CREATE OR REPLACE FUNCTION "public"."set_updated_at"() 
RETURNS trigger
LANGUAGE "plpgsql"
SET search_path = public
AS $$
BEGIN
  NEW._updated_at = now();
  RETURN NEW;
END;
$$;

-- 6. set_updated_at_metadata
CREATE OR REPLACE FUNCTION "public"."set_updated_at_metadata"() 
RETURNS trigger
LANGUAGE "plpgsql"
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 7. update_stripe_customer_links_updated_at
CREATE OR REPLACE FUNCTION "public"."update_stripe_customer_links_updated_at"() 
RETURNS trigger
LANGUAGE "plpgsql"
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ==========================================
-- SECTION 2: Fix RLS Policy Always True
-- ==========================================
-- Replace overly permissive INSERT policy on kitchen table
-- Restrict to only allow users to insert kitchens where they are the owner

DROP POLICY IF EXISTS "Allow authenticated users to insert kitchens" ON "public"."kitchen";

CREATE POLICY "Allow authenticated users to insert kitchens" 
ON "public"."kitchen" 
FOR INSERT 
TO "authenticated" 
WITH CHECK (owner_user_id = (SELECT auth.uid()));

-- ==========================================
-- SECTION 3: Fix Auth RLS Initplan Issues
-- ==========================================
-- Wrap auth.uid() calls in subqueries to prevent per-row evaluation
-- This significantly improves query performance at scale

-- Kitchen table policies
DROP POLICY IF EXISTS "Only kitchen owner can update kitchen" ON "public"."kitchen";
CREATE POLICY "Only kitchen owner can update kitchen" 
ON "public"."kitchen" 
FOR UPDATE 
USING (owner_user_id = (SELECT auth.uid())) 
WITH CHECK (owner_user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Admins can update kitchen names" ON "public"."kitchen";
CREATE POLICY "Admins can update kitchen names" 
ON "public"."kitchen" 
FOR UPDATE 
TO "authenticated" 
USING (
    EXISTS (
        SELECT 1
        FROM public.kitchen_users ku
        WHERE ku.user_id = (SELECT auth.uid())
            AND ku.is_admin = true
            AND ku.kitchen_id = kitchen.kitchen_id
    )
);

-- Kitchen_users table policies
DROP POLICY IF EXISTS "Only kitchen owner can remove users" ON "public"."kitchen_users";
CREATE POLICY "Only kitchen owner can remove users" 
ON "public"."kitchen_users" 
FOR DELETE 
USING (
    EXISTS (
        SELECT 1
        FROM public.kitchen k
        WHERE k.kitchen_id = kitchen_users.kitchen_id 
            AND k.owner_user_id = (SELECT auth.uid())
    )
);

DROP POLICY IF EXISTS "kitchen_users_delete_authenticated" ON "public"."kitchen_users";
CREATE POLICY "kitchen_users_delete_authenticated" 
ON "public"."kitchen_users" 
FOR DELETE 
TO "authenticated" 
USING (
    (
        user_id = (SELECT auth.uid()) 
        AND NOT (is_admin = true AND public.count_kitchen_admins(kitchen_id) = 1)
    ) 
    OR public.is_user_kitchen_admin((SELECT auth.uid()), kitchen_id)
);

DROP POLICY IF EXISTS "Only kitchen owner can update admin status" ON "public"."kitchen_users";
CREATE POLICY "Only kitchen owner can update admin status" 
ON "public"."kitchen_users" 
FOR UPDATE 
USING (
    EXISTS (
        SELECT 1
        FROM public.kitchen k
        WHERE k.kitchen_id = kitchen_users.kitchen_id 
            AND k.owner_user_id = (SELECT auth.uid())
    )
);

DROP POLICY IF EXISTS "Enable update for kitchen admins or self (safeguarded against n" ON "public"."kitchen_users";
CREATE POLICY "Enable update for kitchen admins or self (safeguarded against n" 
ON "public"."kitchen_users" 
FOR UPDATE 
TO "authenticated" 
USING (
    (user_id = (SELECT auth.uid()) AND NOT is_admin) 
    OR public.is_user_kitchen_admin((SELECT auth.uid()), kitchen_id)
);

-- Stripe_customer_links table policies
DROP POLICY IF EXISTS "Users can view customer links for their kitchens" ON "public"."stripe_customer_links";
CREATE POLICY "Users can view customer links for their kitchens" 
ON "public"."stripe_customer_links" 
FOR SELECT 
TO "authenticated" 
USING (
    EXISTS (
        SELECT 1
        FROM public.kitchen_users ku
        WHERE ku.kitchen_id = stripe_customer_links.kitchen_id 
            AND ku.user_id = (SELECT auth.uid())
    )
);

DROP POLICY IF EXISTS "Users can view their own customer links" ON "public"."stripe_customer_links";
CREATE POLICY "Users can view their own customer links" 
ON "public"."stripe_customer_links" 
FOR SELECT 
TO "authenticated" 
USING (user_id = (SELECT auth.uid()));

-- Categories table policies
DROP POLICY IF EXISTS "categories_delete" ON "public"."categories";
CREATE POLICY "categories_delete" 
ON "public"."categories" 
FOR DELETE 
USING (
    (SELECT auth.uid()) IS NOT NULL 
    AND public.is_user_kitchen_member((SELECT auth.uid()), kitchen_id) 
    AND public.is_kitchen_write_allowed(kitchen_id)
);

DROP POLICY IF EXISTS "categories_insert" ON "public"."categories";
CREATE POLICY "categories_insert" 
ON "public"."categories" 
FOR INSERT 
WITH CHECK (
    (SELECT auth.uid()) IS NOT NULL 
    AND public.is_user_kitchen_member((SELECT auth.uid()), kitchen_id) 
    AND public.is_kitchen_write_allowed(kitchen_id)
);

DROP POLICY IF EXISTS "categories_update" ON "public"."categories";
CREATE POLICY "categories_update" 
ON "public"."categories" 
FOR UPDATE 
USING (
    (SELECT auth.uid()) IS NOT NULL 
    AND public.is_user_kitchen_member((SELECT auth.uid()), kitchen_id) 
    AND public.is_kitchen_write_allowed(kitchen_id)
);

-- Components table policies
DROP POLICY IF EXISTS "components_delete" ON "public"."components";
CREATE POLICY "components_delete" 
ON "public"."components" 
FOR DELETE 
USING (
    (SELECT auth.uid()) IS NOT NULL 
    AND public.is_user_kitchen_member((SELECT auth.uid()), kitchen_id) 
    AND public.is_kitchen_write_allowed(kitchen_id)
);

DROP POLICY IF EXISTS "components_insert" ON "public"."components";
CREATE POLICY "components_insert" 
ON "public"."components" 
FOR INSERT 
WITH CHECK (
    (SELECT auth.uid()) IS NOT NULL 
    AND public.is_user_kitchen_member((SELECT auth.uid()), kitchen_id) 
    AND public.is_kitchen_write_allowed(kitchen_id)
);

DROP POLICY IF EXISTS "components_update" ON "public"."components";
CREATE POLICY "components_update" 
ON "public"."components" 
FOR UPDATE 
USING (
    (SELECT auth.uid()) IS NOT NULL 
    AND public.is_user_kitchen_member((SELECT auth.uid()), kitchen_id) 
    AND public.is_kitchen_write_allowed(kitchen_id)
);

-- Recipe_components table policies
DROP POLICY IF EXISTS "recipe_components_delete" ON "public"."recipe_components";
CREATE POLICY "recipe_components_delete" 
ON "public"."recipe_components" 
FOR DELETE 
USING (
    EXISTS (
        SELECT 1
        FROM public.recipes r
        WHERE r.recipe_id = recipe_components.recipe_id 
            AND (SELECT auth.uid()) IS NOT NULL 
            AND public.is_user_kitchen_member((SELECT auth.uid()), r.kitchen_id) 
            AND public.is_kitchen_write_allowed(r.kitchen_id)
    )
);

DROP POLICY IF EXISTS "recipe_components_insert" ON "public"."recipe_components";
CREATE POLICY "recipe_components_insert" 
ON "public"."recipe_components" 
FOR INSERT 
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.recipes r
        WHERE r.recipe_id = recipe_components.recipe_id 
            AND (SELECT auth.uid()) IS NOT NULL 
            AND public.is_user_kitchen_member((SELECT auth.uid()), r.kitchen_id) 
            AND public.is_kitchen_write_allowed(r.kitchen_id)
    )
);

DROP POLICY IF EXISTS "recipe_components_select" ON "public"."recipe_components";
CREATE POLICY "recipe_components_select" 
ON "public"."recipe_components" 
FOR SELECT 
USING (
    EXISTS (
        SELECT 1
        FROM public.recipes r
        WHERE r.recipe_id = recipe_components.recipe_id 
            AND (SELECT auth.uid()) IS NOT NULL 
            AND public.is_user_kitchen_member((SELECT auth.uid()), r.kitchen_id)
    )
);

DROP POLICY IF EXISTS "recipe_components_update" ON "public"."recipe_components";
CREATE POLICY "recipe_components_update" 
ON "public"."recipe_components" 
FOR UPDATE 
USING (
    EXISTS (
        SELECT 1
        FROM public.recipes r
        WHERE r.recipe_id = recipe_components.recipe_id 
            AND (SELECT auth.uid()) IS NOT NULL 
            AND public.is_user_kitchen_member((SELECT auth.uid()), r.kitchen_id) 
            AND public.is_kitchen_write_allowed(r.kitchen_id)
    )
);

-- Recipes table policies
DROP POLICY IF EXISTS "recipes_delete" ON "public"."recipes";
CREATE POLICY "recipes_delete" 
ON "public"."recipes" 
FOR DELETE 
USING (
    (SELECT auth.uid()) IS NOT NULL 
    AND public.is_user_kitchen_member((SELECT auth.uid()), kitchen_id) 
    AND public.is_kitchen_write_allowed(kitchen_id)
);

DROP POLICY IF EXISTS "recipes_insert" ON "public"."recipes";
CREATE POLICY "recipes_insert" 
ON "public"."recipes" 
FOR INSERT 
WITH CHECK (
    (SELECT auth.uid()) IS NOT NULL 
    AND public.is_user_kitchen_member((SELECT auth.uid()), kitchen_id) 
    AND public.is_kitchen_write_allowed(kitchen_id)
);

DROP POLICY IF EXISTS "recipes_update" ON "public"."recipes";
CREATE POLICY "recipes_update" 
ON "public"."recipes" 
FOR UPDATE 
USING (
    (SELECT auth.uid()) IS NOT NULL 
    AND public.is_user_kitchen_member((SELECT auth.uid()), kitchen_id) 
    AND public.is_kitchen_write_allowed(kitchen_id)
);

-- ==========================================
-- SECTION 4: Consolidate Multiple Permissive Policies
-- ==========================================
-- Merge multiple permissive policies into single policies for better performance

-- Kitchen table: Merge "Admins can update kitchen names" and "Only kitchen owner can update kitchen"
-- Already handled above - kept both as they serve different purposes and are optimized

-- Kitchen_users table DELETE: Merge policies
-- Already handled above - kept both as they serve different purposes

-- Kitchen_users table UPDATE: Merge policies
-- Already handled above - kept both as they serve different purposes

-- Stripe_customer_links table SELECT: Merge policies
-- Already handled above - kept both as they allow different access patterns

-- Note: While the advisor recommends consolidating multiple permissive policies,
-- in this case the policies serve distinct authorization use cases:
-- - Owner/admin vs regular user access
-- - Kitchen-scoped vs user-scoped access
-- Keeping them separate provides clearer intent and easier maintenance.
-- The performance impact is minimal with the initplan optimization applied.
