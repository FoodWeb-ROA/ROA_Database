


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE SCHEMA IF NOT EXISTS "stripe";


ALTER SCHEMA "stripe" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "http" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "hypopg" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "index_advisor" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgmq";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "wrappers" WITH SCHEMA "extensions";






CREATE TYPE "public"."KitchenType" AS ENUM (
    'Personal',
    'Team'
);


ALTER TYPE "public"."KitchenType" OWNER TO "postgres";


CREATE TYPE "public"."component_type" AS ENUM (
    'Raw_Ingredient',
    'Preparation'
);


ALTER TYPE "public"."component_type" OWNER TO "postgres";


CREATE TYPE "public"."recipe_type" AS ENUM (
    'Dish',
    'Preparation'
);


ALTER TYPE "public"."recipe_type" OWNER TO "postgres";


CREATE TYPE "public"."unit" AS ENUM (
    'mg',
    'g',
    'kg',
    'ml',
    'l',
    'oz',
    'lb',
    'tsp',
    'tbsp',
    'cup',
    'pt',
    'qt',
    'gal',
    'x'
);


ALTER TYPE "public"."unit" OWNER TO "postgres";


CREATE TYPE "stripe"."invoice_status" AS ENUM (
    'draft',
    'open',
    'paid',
    'uncollectible',
    'void',
    'deleted'
);


ALTER TYPE "stripe"."invoice_status" OWNER TO "postgres";


CREATE TYPE "stripe"."pricing_tiers" AS ENUM (
    'graduated',
    'volume'
);


ALTER TYPE "stripe"."pricing_tiers" OWNER TO "postgres";


CREATE TYPE "stripe"."pricing_type" AS ENUM (
    'one_time',
    'recurring'
);


ALTER TYPE "stripe"."pricing_type" OWNER TO "postgres";


CREATE TYPE "stripe"."subscription_schedule_status" AS ENUM (
    'not_started',
    'active',
    'completed',
    'released',
    'canceled'
);


ALTER TYPE "stripe"."subscription_schedule_status" OWNER TO "postgres";


CREATE TYPE "stripe"."subscription_status" AS ENUM (
    'trialing',
    'active',
    'canceled',
    'incomplete',
    'incomplete_expired',
    'past_due',
    'unpaid',
    'paused'
);


ALTER TYPE "stripe"."subscription_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."components_enforce_recipe_pairing"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW.component_type = 'Preparation' THEN
    IF NEW.recipe_id IS NULL THEN
      RAISE EXCEPTION 'Preparation component must have recipe_id';
    END IF;
    PERFORM 1 FROM public.recipes r
      WHERE r.recipe_id = NEW.recipe_id AND r.recipe_type = 'Preparation';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Preparation component must reference a recipe of type Preparation';
    END IF;
  ELSE
    -- Raw_Ingredient must not reference any recipe
    IF NEW.recipe_id IS NOT NULL THEN
      RAISE EXCEPTION 'Raw_Ingredient component cannot have a recipe_id';
    END IF;
  END IF;
  RETURN NULL; -- for constraint triggers
END;
$$;


ALTER FUNCTION "public"."components_enforce_recipe_pairing"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."convert_amount_safe"("amount_val" numeric, "from_unit" "public"."unit", "to_unit" "public"."unit") RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
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


ALTER FUNCTION "public"."convert_amount_safe"("amount_val" numeric, "from_unit" "public"."unit", "to_unit" "public"."unit") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."count_kitchen_admins"("p_kitchen_id" "uuid") RETURNS integer
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT COUNT(*)
    FROM public.kitchen_users ku
    WHERE ku.kitchen_id = p_kitchen_id
      AND ku.is_admin = true;
$$;


ALTER FUNCTION "public"."count_kitchen_admins"("p_kitchen_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_free_team_kitchen"("p_user_id" "uuid", "p_team_name" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_kitchen_id uuid;
    v_user_email text;
BEGIN
    -- Validate user_id
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID is required';
    END IF;
    
    -- Get user email
    SELECT user_email INTO v_user_email
    FROM public.users
    WHERE user_id = p_user_id;
    
    IF v_user_email IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Enforce @foodweb.ai domain restriction
    IF v_user_email NOT LIKE '%@foodweb.ai' THEN
        RAISE EXCEPTION 'Free kitchen creation is restricted to @foodweb.ai users';
    END IF;
    
    -- Validate team name
    IF p_team_name IS NULL OR TRIM(p_team_name) = '' THEN
        RAISE EXCEPTION 'Team name cannot be empty';
    END IF;
    
    -- Create Team kitchen with owner
    INSERT INTO public.kitchen (name, type, owner_user_id)
    VALUES (TRIM(p_team_name), 'Team', p_user_id)
    RETURNING kitchen_id INTO v_kitchen_id;
    
    -- Link user as admin
    INSERT INTO public.kitchen_users (kitchen_id, user_id, is_admin)
    VALUES (v_kitchen_id, p_user_id, true);
    
    -- Return kitchen ID
    RETURN v_kitchen_id;
END;
$$;


ALTER FUNCTION "public"."create_free_team_kitchen"("p_user_id" "uuid", "p_team_name" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_free_team_kitchen"("p_user_id" "uuid", "p_team_name" "text") IS 'Creates a free Team kitchen for @foodweb.ai users. Returns kitchen_id. 
   Backend must create Stripe subscription with free price after this.';



CREATE OR REPLACE FUNCTION "public"."create_preparation_with_component"("_kitchen" "uuid", "_name" "text", "_category" "uuid", "_directions" "text"[], "_time" interval, "_cooking_notes" "text", "_yield_unit" "public"."unit" DEFAULT NULL::"public"."unit", "_yield_amount" numeric DEFAULT NULL::numeric) RETURNS TABLE("recipe_id" "uuid", "component_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_recipe_id uuid;
  v_component_id uuid;
  v_unit public.unit;
  v_amount numeric;
BEGIN
  -- Use provided yields when available; otherwise default to count-style 1 x for preparations
  v_unit := COALESCE(_yield_unit, 'x');
  v_amount := CASE WHEN v_unit = 'x' THEN 1 ELSE COALESCE(_yield_amount, 1) END;

  INSERT INTO public.recipes (
    recipe_name, category_id, directions, "time",
    serving_or_yield_unit, serving_item, recipe_type, cooking_notes, kitchen_id, serving_or_yield_amount
  ) VALUES (
    COALESCE(_name, ''), _category, _directions, COALESCE(_time, '00:00:00'::interval),
    v_unit, NULL, 'Preparation', _cooking_notes, _kitchen, v_amount
  ) RETURNING recipes.recipe_id INTO v_recipe_id;

  INSERT INTO public.components (name, component_type, kitchen_id, recipe_id)
  VALUES (COALESCE(_name, ''), 'Preparation', _kitchen, v_recipe_id)
  RETURNING components.component_id INTO v_component_id;

  -- Explicitly return a single row to the caller
  RETURN QUERY SELECT v_recipe_id::uuid AS recipe_id, v_component_id::uuid AS component_id;
END;
$$;


ALTER FUNCTION "public"."create_preparation_with_component"("_kitchen" "uuid", "_name" "text", "_category" "uuid", "_directions" "text"[], "_time" interval, "_cooking_notes" "text", "_yield_unit" "public"."unit", "_yield_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_expired_kitchen_invites"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  DELETE FROM public.kitchen_invites ki
  WHERE ki.expires_at IS NOT NULL
    AND ki.expires_at < (now() - interval '7 days');
END;
$$;


ALTER FUNCTION "public"."delete_expired_kitchen_invites"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."delete_expired_kitchen_invites"() IS 'Deletes rows from public.kitchen_invites where expires_at is more than 7 days in the past. Intended to be run by Supabase Cron.';



CREATE OR REPLACE FUNCTION "public"."delete_recipe"("_recipe_id" "uuid", "_kitchen_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_recipe_kitchen uuid;
  v_recipe_type text;
  v_recipe_name text;
  v_component_id uuid;
  v_component_ids_to_check uuid[];
  v_orphaned_raw_ingredients uuid[];
  v_deleted_count integer := 0;
  v_orphan_count integer := 0;
BEGIN
  -- Verify recipe exists and get basic info
  SELECT kitchen_id, recipe_type, recipe_name 
  INTO v_recipe_kitchen, v_recipe_type, v_recipe_name
  FROM public.recipes 
  WHERE recipe_id = _recipe_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Recipe % not found', _recipe_id;
  END IF;

  -- Kitchen access check
  IF v_recipe_kitchen IS DISTINCT FROM _kitchen_id THEN
    RAISE EXCEPTION 'Access denied: recipe belongs to different kitchen';
  END IF;

  -- Collect all component_ids that will be orphaned by this deletion
  -- (components currently used only by this recipe)
  SELECT array_agg(DISTINCT rc.component_id)
  INTO v_component_ids_to_check
  FROM public.recipe_components rc
  WHERE rc.recipe_id = _recipe_id
    AND rc.component_id IS NOT NULL;

  -- Delete the recipe and all its components in proper order
  -- 1. Delete recipe_components first (to avoid FK violations)
  DELETE FROM public.recipe_components WHERE recipe_id = _recipe_id;
  
  -- 2. Delete the recipe itself
  DELETE FROM public.recipes WHERE recipe_id = _recipe_id;
  v_deleted_count := 1;

  -- 3. For preparations, also delete the component that represents this recipe
  IF v_recipe_type = 'Preparation' THEN
    DELETE FROM public.components 
    WHERE recipe_id = _recipe_id;
  END IF;

  -- 4. Clean up orphaned raw ingredients
  -- Check each component to see if it's now unused and is a raw ingredient
  IF v_component_ids_to_check IS NOT NULL AND array_length(v_component_ids_to_check, 1) > 0 THEN
    SELECT array_agg(comp_id)
    INTO v_orphaned_raw_ingredients
    FROM (
      SELECT c.component_id as comp_id
      FROM public.components c
      WHERE c.component_id = ANY(v_component_ids_to_check)
        AND c.recipe_id IS NULL  -- Raw ingredient (not a preparation)
        AND c.kitchen_id = _kitchen_id  -- Same kitchen
        AND NOT EXISTS (
          -- Not used in any other recipe
          SELECT 1 FROM public.recipe_components rc 
          WHERE rc.component_id = c.component_id
        )
    ) orphaned;

    -- Delete orphaned raw ingredients
    IF v_orphaned_raw_ingredients IS NOT NULL AND array_length(v_orphaned_raw_ingredients, 1) > 0 THEN
      DELETE FROM public.components 
      WHERE component_id = ANY(v_orphaned_raw_ingredients);
      
      v_orphan_count := array_length(v_orphaned_raw_ingredients, 1);
      
      -- Log the cleanup for debugging
      RAISE NOTICE 'Deleted recipe "%" and cleaned up % orphaned raw ingredients', 
        v_recipe_name, v_orphan_count;
    END IF;
  END IF;

  -- Return summary
  RETURN jsonb_build_object(
    'success', true,
    'deleted_recipe_id', _recipe_id,
    'recipe_name', v_recipe_name,
    'recipe_type', v_recipe_type,
    'recipes_deleted', v_deleted_count,
    'orphaned_ingredients_cleaned', v_orphan_count,
    'orphaned_ingredient_ids', COALESCE(v_orphaned_raw_ingredients, ARRAY[]::uuid[])
  );
END;
$$;


ALTER FUNCTION "public"."delete_recipe"("_recipe_id" "uuid", "_kitchen_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_user"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get the authenticated user's ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Log the deletion attempt
  RAISE NOTICE 'User deletion initiated for user_id: %', v_user_id;

  -- Delete the auth user
  -- The BEFORE DELETE trigger (on_auth_user_deleted) will automatically:
  -- 1. Delete the personal kitchen (cascades to all recipes/components)
  -- The CASCADE constraints will then automatically:
  -- 2. Remove team kitchen memberships (kitchen_users FK cascade)
  -- 3. Remove public.users profile (users FK cascade)
  RAISE NOTICE 'Deleting auth user: %', v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

  RAISE NOTICE 'User deletion completed for user_id: %', v_user_id;
END;
$$;


ALTER FUNCTION "public"."delete_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_one_user_per_personal_kitchen"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
    kitchen_type TEXT;
BEGIN
    SELECT type INTO kitchen_type FROM public.kitchen WHERE kitchen_id = NEW.kitchen_id;

    IF kitchen_type = 'Personal' THEN
        -- Check if someone is already linked
        IF EXISTS (
            SELECT 1 FROM public.kitchen_users
            WHERE kitchen_id = NEW.kitchen_id
        ) THEN
            RAISE EXCEPTION 'Only one user can be linked to a Personal kitchen.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."enforce_one_user_per_personal_kitchen"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_prep_name_kitchen_match_from_components"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW.component_type = 'Preparation' THEN
    IF NEW.recipe_id IS NULL THEN
      RAISE EXCEPTION 'Preparation component must have recipe_id';
    END IF;
    
    -- Ensure target recipe exists and is a Preparation
    PERFORM 1 FROM public.recipes r WHERE r.recipe_id = NEW.recipe_id AND r.recipe_type = 'Preparation';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Preparation component must reference a Preparation recipe';
    END IF;

    -- Only update recipe if there's actually a difference
    -- More defensive: check if the recipe already has the correct name and kitchen
    IF TG_OP = 'UPDATE' THEN
      -- Check if the recipe actually needs updating
      PERFORM 1 FROM public.recipes r 
      WHERE r.recipe_id = NEW.recipe_id 
      AND r.recipe_type = 'Preparation'
      AND (r.recipe_name IS DISTINCT FROM NEW.name OR r.kitchen_id IS DISTINCT FROM NEW.kitchen_id);
      
      -- If recipe doesn't need updating, skip entirely
      IF NOT FOUND THEN
        RETURN NULL;
      END IF;
    END IF;

    -- Defensive update: only update recipe if it actually needs it
    UPDATE public.recipes r
       SET recipe_name = NEW.name,
           kitchen_id  = NEW.kitchen_id
     WHERE r.recipe_id = NEW.recipe_id
       AND r.recipe_type = 'Preparation'
       AND (r.recipe_name IS DISTINCT FROM NEW.name OR r.kitchen_id IS DISTINCT FROM NEW.kitchen_id);
  END IF;
  
  RETURN NULL; -- for constraint triggers
END;
$$;


ALTER FUNCTION "public"."enforce_prep_name_kitchen_match_from_components"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_prep_name_kitchen_match_from_recipes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW.recipe_type = 'Preparation' THEN
    -- Ensure a matching preparation component exists
    PERFORM 1 FROM public.components c WHERE c.recipe_id = NEW.recipe_id AND c.component_type = 'Preparation';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Preparation recipe must have a matching component (name/kitchen match enforcement)';
    END IF;

    -- Only update component if there's actually a difference
    -- More defensive: check if the component already has the correct name and kitchen
    IF TG_OP = 'UPDATE' THEN
      -- Check if any component actually needs updating
      PERFORM 1 FROM public.components c 
      WHERE c.recipe_id = NEW.recipe_id 
      AND c.component_type = 'Preparation'
      AND (c.name IS DISTINCT FROM NEW.recipe_name OR c.kitchen_id IS DISTINCT FROM NEW.kitchen_id);
      
      -- If no component needs updating, skip entirely
      IF NOT FOUND THEN
        RETURN NULL;
      END IF;
    END IF;

    -- Defensive update: only update components that actually need it
    UPDATE public.components c
       SET name       = NEW.recipe_name,
           kitchen_id = NEW.kitchen_id
     WHERE c.recipe_id = NEW.recipe_id
       AND c.component_type = 'Preparation'
       AND (c.name IS DISTINCT FROM NEW.recipe_name OR c.kitchen_id IS DISTINCT FROM NEW.kitchen_id);
  END IF;
  
  RETURN NULL; -- for constraint triggers
END;
$$;


ALTER FUNCTION "public"."enforce_prep_name_kitchen_match_from_recipes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_by_fingerprints"("_fps" "uuid"[], "_kitchen" "uuid", "_only_preparations" boolean DEFAULT false) RETURNS TABLE("fingerprint" "uuid", "recipe_id" "uuid", "component_id" "uuid", "recipe_type" "public"."recipe_type")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT r.fingerprint,
         r.recipe_id,
         CASE WHEN r.recipe_type = 'Preparation' THEN c.component_id ELSE NULL END AS component_id,
         r.recipe_type
    FROM public.recipes r
    LEFT JOIN public.components c
           ON c.recipe_id = r.recipe_id
          AND r.recipe_type = 'Preparation'
   WHERE r.kitchen_id = _kitchen
     AND r.fingerprint IS NOT NULL
     AND r.fingerprint = ANY(_fps)
     AND (_only_preparations IS FALSE OR r.recipe_type = 'Preparation');
$$;


ALTER FUNCTION "public"."find_by_fingerprints"("_fps" "uuid"[], "_kitchen" "uuid", "_only_preparations" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_by_plain"("_names" "text"[], "_kitchen" "uuid", "_threshold" real DEFAULT 0.75, "_only_preparations" boolean DEFAULT false) RETURNS TABLE("fingerprint_plain" "text", "recipe_id" "uuid", "component_id" "uuid", "recipe_type" "public"."recipe_type", "sim" numeric)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  WITH q AS (
    SELECT unnest(_names) AS plain
  )
  SELECT r.fingerprint_plain,
         r.recipe_id,
         CASE WHEN r.recipe_type = 'Preparation' THEN c.component_id ELSE NULL END AS component_id,
         r.recipe_type,
         extensions.similarity(r.fingerprint_plain, q.plain) AS sim
    FROM q
    JOIN public.recipes r
      ON r.kitchen_id = _kitchen
    LEFT JOIN public.components c
           ON c.recipe_id = r.recipe_id
          AND r.recipe_type = 'Preparation'
   WHERE r.fingerprint_plain IS NOT NULL
     AND extensions.similarity(r.fingerprint_plain, q.plain) >= COALESCE(_threshold, 0.75)
     AND (_only_preparations IS FALSE OR r.recipe_type = 'Preparation')
   ORDER BY sim DESC;
$$;


ALTER FUNCTION "public"."find_by_plain"("_names" "text"[], "_kitchen" "uuid", "_threshold" real, "_only_preparations" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_ingredients_by_name_exact"("_names" "text"[], "_kitchen" "uuid") RETURNS TABLE("input_name" "text", "ingredient_id" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  WITH q AS (
    SELECT unnest(_names) AS name
  )
  SELECT q.name AS input_name,
         c.component_id AS ingredient_id
    FROM q
    JOIN public.components c
      ON c.kitchen_id = _kitchen
     AND c.component_type = 'Raw_Ingredient'
     AND lower(trim(c.name)) = lower(trim(q.name));
$$;


ALTER FUNCTION "public"."find_ingredients_by_name_exact"("_names" "text"[], "_kitchen" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_ingredients_by_name_fuzzy"("_names" "text"[], "_kitchen" "uuid", "_threshold" real DEFAULT 0.75) RETURNS TABLE("input_name" "text", "ingredient_id" "uuid")
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
WITH q AS (
  SELECT unnest(_names) AS name
), cand AS (
  SELECT q.name AS input_name,
         c.component_id,
         extensions.similarity(lower(trim(c.name)), lower(trim(q.name))) AS sim,
         row_number() OVER (
           PARTITION BY q.name
           ORDER BY extensions.similarity(lower(trim(c.name)), lower(trim(q.name))) DESC
         ) AS rn
    FROM q
    JOIN public.components c
      ON c.kitchen_id = _kitchen
     AND c.component_type = 'Raw_Ingredient'
     AND extensions.similarity(lower(trim(c.name)), lower(trim(q.name))) >= _threshold
)
SELECT input_name, component_id
  FROM cand
 WHERE rn = 1;
$$;


ALTER FUNCTION "public"."find_ingredients_by_name_fuzzy"("_names" "text"[], "_kitchen" "uuid", "_threshold" real) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fp_namespace"() RETURNS "uuid"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
    SELECT public.uuid_generate_v5(public.uuid_ns_dns(), 'roa-preparation-fingerprint');
$$;


ALTER FUNCTION "public"."fp_namespace"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_components_for_recipes"("_recipe_ids" "uuid"[]) RETURNS TABLE("recipe_id" "uuid", "component_id" "uuid", "amount" numeric, "unit" "public"."unit", "is_preparation" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  SELECT
    rc.recipe_id,
    rc.component_id,
    rc.amount,
    rc.unit AS unit,
    (c.component_type = 'Preparation') AS is_preparation
  FROM public.recipe_components rc
  JOIN public.components c ON c.component_id = rc.component_id
  WHERE rc.recipe_id = ANY(_recipe_ids);
$$;


ALTER FUNCTION "public"."get_components_for_recipes"("_recipe_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_kitchen_categories_for_parser"("p_kitchen_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    result JSONB;
BEGIN
    -- Return a JSON array of category names for the kitchen
    SELECT jsonb_agg(c.name ORDER BY c.name)
    INTO result
    FROM public.categories c
    WHERE c.kitchen_id = p_kitchen_id;
    
    -- Return empty array if no categories found
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_kitchen_categories_for_parser"("p_kitchen_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_kitchen_owner"("p_kitchen_id" "uuid") RETURNS TABLE("owner_user_id" "uuid", "owner_email" "text", "owner_name" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT 
    k.owner_user_id,
    u.user_email,
    u.user_fullname
  FROM public.kitchen k
  LEFT JOIN public.users u ON u.user_id = k.owner_user_id
  WHERE k.kitchen_id = p_kitchen_id;
$$;


ALTER FUNCTION "public"."get_kitchen_owner"("p_kitchen_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_kitchen_owner_email"("p_kitchen_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_owner_user_id uuid;
    v_owner_email text;
BEGIN
    -- Get owner_user_id from kitchen
    SELECT owner_user_id INTO v_owner_user_id
    FROM public.kitchen
    WHERE kitchen_id = p_kitchen_id;
    
    IF v_owner_user_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Get email from users
    SELECT user_email INTO v_owner_email
    FROM public.users
    WHERE user_id = v_owner_user_id;
    
    RETURN v_owner_email;
END;
$$;


ALTER FUNCTION "public"."get_kitchen_owner_email"("p_kitchen_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_kitchen_owner_email"("p_kitchen_id" "uuid") IS 'Helper function to get owner email for a kitchen. Used by webhook payload.';



CREATE OR REPLACE FUNCTION "public"."get_kitchen_preparations_for_parser"("p_kitchen_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', r.recipe_id::text,
            'recipe_name', r.recipe_name,
            'recipe_type', 'Preparation',
            'language', 'UNK',
            'components', COALESCE(comp_data.components, '[]'::jsonb),
            'directions', COALESCE(to_jsonb(r.directions), '[]'::jsonb),
            'time_minutes', EXTRACT(EPOCH FROM COALESCE(r.time, '0 minutes'::interval)) / 60,
            'cook_notes', r.cooking_notes,
            'serving_or_yield_amount', r.serving_or_yield_amount,
            'serving_or_yield_unit', r.serving_or_yield_unit
        )
        
    ) INTO result
    FROM public.recipes r
    LEFT JOIN LATERAL (
        SELECT jsonb_agg(
            CASE 
                WHEN prep_recipe.recipe_id IS NOT NULL THEN
                    jsonb_build_object(
                        'component_type', 'ComponentPreparation',
                        'recipe_id', prep_recipe.recipe_id::text,
                        'amount', rc.amount,
                        'unit', rc.unit,
                        'source', 'database'
                    )
                ELSE
                    jsonb_build_object(
                        'component_type', 'RawIngredient',
                        'name', c.name,
                        'amount', rc.amount,
                        'unit', rc.unit,
                        'item', rc.item
                    )
            END
        ) AS components
        FROM public.recipe_components rc
        JOIN public.components c ON rc.component_id = c.component_id
        LEFT JOIN public.recipes prep_recipe ON c.recipe_id = prep_recipe.recipe_id 
            AND prep_recipe.recipe_type = 'Preparation'
        WHERE rc.recipe_id = r.recipe_id
    ) comp_data ON true
    WHERE r.kitchen_id = p_kitchen_id 
    AND r.recipe_type = 'Preparation';
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$;


ALTER FUNCTION "public"."get_kitchen_preparations_for_parser"("p_kitchen_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unit_kind"("unit_val" "public"."unit") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
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


ALTER FUNCTION "public"."get_unit_kind"("unit_val" "public"."unit") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unit_measurement_type"("unit_abbr" "public"."unit") RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
  -- Use the existing unit_kind function that's already defined in the schema
  RETURN public.unit_kind(unit_abbr);
END;
$$;


ALTER FUNCTION "public"."get_unit_measurement_type"("unit_abbr" "public"."unit") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_auth_user_updates"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  -- Update the corresponding record in public.users
  UPDATE public.users
  SET 
    user_fullname = NEW.raw_user_meta_data->>'full_name',
    user_email = NEW.email,
    updated_at = now()
  WHERE user_id = NEW.id;
  
  -- If no record exists yet (unlikely with proper setup, but as a fallback)
  -- Insert a new record
  IF NOT FOUND THEN
    INSERT INTO public.users (user_id, user_fullname, user_email)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', NEW.email);
  END IF;
  
  -- Update the user's personal kitchen name if email changed
  -- Personal kitchens are named after the user's email
  IF OLD.email IS DISTINCT FROM NEW.email THEN
    UPDATE public.kitchen
    SET 
      name = NEW.email,
      updated_at = now()
    WHERE kitchen_id IN (
      SELECT ku.kitchen_id
      FROM public.kitchen_users ku
      INNER JOIN public.kitchen k ON k.kitchen_id = ku.kitchen_id
      WHERE ku.user_id = NEW.id
        AND k.type = 'Personal'
    );
    
    RAISE NOTICE 'Updated personal kitchen name from % to % for user %', OLD.email, NEW.email, NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_auth_user_updates"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_deleted_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  -- Delete the user's personal kitchen by name (always equals user's email)
  -- Personal kitchens are kept in sync with user email via handle_auth_user_updates trigger
  DELETE FROM public.kitchen 
  WHERE name = OLD.email 
    AND type = 'Personal';
  
  -- This cascades to all kitchen-related data:
  -- - kitchen_users (removes kitchen membership)
  -- - kitchen_invites
  -- - categories
  -- - recipes (dishes and preparations)
  -- - components
  -- - recipe_components
  
  -- The CASCADE constraint on public.users will automatically remove the public profile
  -- The CASCADE constraint on kitchen_users will automatically remove team kitchen memberships
  
  RAISE NOTICE 'Auto-deleted personal kitchen for user % (email: %)', OLD.id, OLD.email;
  
  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."handle_deleted_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_kitchen_id uuid;
BEGIN
  -- Insert the user into public.users
  INSERT INTO public.users (user_id, user_email, user_fullname)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name'
  );
  
  -- Create a personal kitchen for the new user
  -- Kitchen name is the user's email address
  INSERT INTO public.kitchen (name, type)
  VALUES (NEW.email, 'Personal')
  RETURNING kitchen_id INTO v_kitchen_id;
  
  -- Link the user to their personal kitchen as an admin
  INSERT INTO public.kitchen_users (user_id, kitchen_id, is_admin)
  VALUES (NEW.id, v_kitchen_id, true);
  
  RAISE NOTICE 'Created personal kitchen % for user % (%)', v_kitchen_id, NEW.id, NEW.email;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_subscription_checkout_complete"("p_stripe_customer_id" "text", "p_user_id" "uuid", "p_team_name" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_kitchen_id uuid;
  v_final_team_name text;
  v_user_email text;
BEGIN
  -- Get user email for default team name
  SELECT user_email INTO v_user_email
  FROM public.users
  WHERE user_id = p_user_id;
  
  v_final_team_name := COALESCE(p_team_name, v_user_email, 'Team');
  
  -- Check if customer link already exists (re-subscribe scenario)
  SELECT kitchen_id INTO v_kitchen_id
  FROM public.stripe_customer_links
  WHERE stripe_customer_id = p_stripe_customer_id;
  
  IF v_kitchen_id IS NOT NULL THEN
    -- Existing subscription, return the kitchen
    RETURN v_kitchen_id;
  END IF;
  
  -- Create new Team kitchen with owner
  INSERT INTO public.kitchen (name, type, owner_user_id)
  VALUES (v_final_team_name, 'Team', p_user_id)
  RETURNING kitchen_id INTO v_kitchen_id;
  
  -- Link paying user as admin
  INSERT INTO public.kitchen_users (kitchen_id, user_id, is_admin)
  VALUES (v_kitchen_id, p_user_id, true);
  
  -- Create customer link
  INSERT INTO public.stripe_customer_links (user_id, kitchen_id, stripe_customer_id, team_name)
  VALUES (p_user_id, v_kitchen_id, p_stripe_customer_id, v_final_team_name);
  
  RETURN v_kitchen_id;
END;
$$;


ALTER FUNCTION "public"."handle_subscription_checkout_complete"("p_stripe_customer_id" "text", "p_user_id" "uuid", "p_team_name" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."handle_subscription_checkout_complete"("p_stripe_customer_id" "text", "p_user_id" "uuid", "p_team_name" "text") IS 'Creates Team kitchen and links paying user as admin when Stripe checkout completes. Called by Stripe Sync Engine Edge Function. Returns kitchen_id.';



CREATE OR REPLACE FUNCTION "public"."inventory_prep_consistency"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  IF (NEW.type = 'preparation' AND NEW.prep_id IS NULL) OR
     (NEW.type = 'ingredient'   AND NEW.prep_id IS NOT NULL) THEN
        RAISE EXCEPTION 'type/prep_id mismatch on inventory_id %', NEW.inventory_id;
  END IF;
  RETURN NEW;
END; $$;


ALTER FUNCTION "public"."inventory_prep_consistency"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_kitchen_subscribed"("p_kitchen_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'stripe'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.stripe_customer_links scl
    JOIN stripe.subscriptions s ON s.customer = scl.stripe_customer_id
    WHERE scl.kitchen_id = p_kitchen_id
      AND s.status IN ('trialing', 'active')
      AND (s.current_period_end IS NULL OR to_timestamp(s.current_period_end) > now())
  );
$$;


ALTER FUNCTION "public"."is_kitchen_subscribed"("p_kitchen_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_kitchen_subscribed"("p_kitchen_id" "uuid") IS 'Returns true if kitchen has active/trialing subscription. Queries local stripe.subscriptions table (synced by Stripe Sync Engine).';



CREATE OR REPLACE FUNCTION "public"."is_user_kitchen_admin"("p_user_id" "uuid", "p_kitchen_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.kitchen_users ku
        WHERE ku.user_id = p_user_id
          AND ku.kitchen_id = p_kitchen_id
          AND ku.is_admin = true
    );
$$;


ALTER FUNCTION "public"."is_user_kitchen_admin"("p_user_id" "uuid", "p_kitchen_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_user_kitchen_member"("p_user_id" "uuid", "p_kitchen_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.kitchen_users ku
        WHERE ku.user_id = p_user_id
          AND ku.kitchen_id = p_kitchen_id
    );
$$;


ALTER FUNCTION "public"."is_user_kitchen_member"("p_user_id" "uuid", "p_kitchen_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_kitchen_with_invite"("invite_code_to_join" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  target_kitchen_id UUID;
  invite_record RECORD;
  current_user_id UUID := auth.uid();
  already_member BOOLEAN;
BEGIN
  -- Fetch invite details
  SELECT * INTO invite_record
  FROM public.kitchen_invites
  WHERE invite_code = invite_code_to_join;

  -- Validate invite code
  IF NOT FOUND THEN
    RETURN json_build_object('error', 'Invalid invite code.');
  END IF;

  IF NOT invite_record.is_active THEN
    RETURN json_build_object('error', 'Invite code is no longer active.');
  END IF;

  IF invite_record.expires_at IS NOT NULL AND invite_record.expires_at < NOW() THEN
    -- Optionally, also set is_active to false
    UPDATE public.kitchen_invites SET is_active = FALSE WHERE invite_code = invite_code_to_join;
    RETURN json_build_object('error', 'Invite code has expired.');
  END IF;

  IF invite_record.max_uses IS NOT NULL AND invite_record.current_uses >= invite_record.max_uses THEN
    -- Optionally, also set is_active to false if not already
    UPDATE public.kitchen_invites SET is_active = FALSE WHERE invite_code = invite_code_to_join;
    RETURN json_build_object('error', 'Invite code has reached its maximum number of uses.');
  END IF;

  target_kitchen_id := invite_record.kitchen_id;

  -- Check if user is already a member
  SELECT EXISTS (
    SELECT 1 FROM public.kitchen_users ku
    WHERE ku.user_id = current_user_id AND ku.kitchen_id = target_kitchen_id
  ) INTO already_member;

  IF already_member THEN
    RETURN json_build_object('error', 'You are already a member of this kitchen.');
  END IF;

  -- Add user to kitchen without role
  INSERT INTO public.kitchen_users (user_id, kitchen_id, is_admin)
  VALUES (current_user_id, target_kitchen_id, FALSE); -- Default admin status

  -- Update invite usage
  UPDATE public.kitchen_invites
  SET current_uses = invite_record.current_uses + 1
  WHERE invite_code = invite_code_to_join;

  -- Deactivate if max uses reached
  IF invite_record.max_uses IS NOT NULL AND (invite_record.current_uses + 1) >= invite_record.max_uses THEN
    UPDATE public.kitchen_invites SET is_active = FALSE WHERE invite_code = invite_code_to_join;
  END IF;

  RETURN json_build_object('success', true, 'kitchen_id', target_kitchen_id, 'message', 'Successfully joined kitchen.');
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error internally if possible
    RETURN json_build_object('error', 'An unexpected error occurred: ' || SQLERRM);
END;
$$;


ALTER FUNCTION "public"."join_kitchen_with_invite"("invite_code_to_join" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."overwrite_preparation_with_components"("_prep_component_id" "uuid", "_kitchen_id" "uuid", "_new_name" "text", "_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_recipe_id uuid;
  v_component_kitchen uuid;
BEGIN
  -- Lock the component and associated recipe
  SELECT recipe_id, kitchen_id INTO v_recipe_id, v_component_kitchen
  FROM public.components WHERE component_id = _prep_component_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Preparation component % not found', _prep_component_id; END IF;
  IF v_component_kitchen IS DISTINCT FROM _kitchen_id THEN RAISE EXCEPTION 'Kitchen mismatch for component %', _prep_component_id; END IF;

  -- Update name
  UPDATE public.components SET name = COALESCE(_new_name, name)
  WHERE component_id = _prep_component_id;

  -- Upsert children via helper
  PERFORM public.upsert_preparation_components(v_recipe_id, _kitchen_id, _items);
  RETURN;
END;
$$;


ALTER FUNCTION "public"."overwrite_preparation_with_components"("_prep_component_id" "uuid", "_kitchen_id" "uuid", "_new_name" "text", "_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prep_yield_change_guard"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  existing_kind text;
  new_kind text;
  in_use boolean;
BEGIN
  IF NEW.recipe_type <> 'Preparation' THEN
    RETURN NEW;
  END IF;

  IF NEW.serving_or_yield_unit IS DISTINCT FROM OLD.serving_or_yield_unit THEN
    -- Force amount to 1 when unit is x
    IF NEW.serving_or_yield_unit = 'x' AND NEW.serving_or_yield_amount <> 1 THEN
      NEW.serving_or_yield_amount := 1;
    END IF;

    existing_kind := public.unit_kind(OLD.serving_or_yield_unit);
    new_kind := public.unit_kind(NEW.serving_or_yield_unit);

    SELECT EXISTS (
      SELECT 1 FROM public.recipe_components rc
      JOIN public.components c ON c.component_id = rc.component_id
      WHERE c.recipe_id = NEW.recipe_id
    ) INTO in_use;

    IF in_use AND existing_kind IS DISTINCT FROM new_kind THEN
      RAISE EXCEPTION 'Cannot change preparation yield measurement type while it is used in other recipes';
    END IF;
  END IF;
  RETURN NEW;
END;$$;


ALTER FUNCTION "public"."prep_yield_change_guard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_owner_leave"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Check if the user being removed is the kitchen owner
  IF EXISTS (
    SELECT 1 FROM public.kitchen
    WHERE kitchen_id = OLD.kitchen_id
    AND owner_user_id = OLD.user_id
  ) THEN
    RAISE EXCEPTION 'Cannot leave kitchen: you are the billing owner. Transfer ownership first or cancel the subscription.';
  END IF;
  
  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."prevent_owner_leave"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_preparation_cycle"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
    _parent_prep_component_id uuid;
    _child_recipe_id uuid;
    _cycle_found boolean := FALSE;
BEGIN
    -- Ignore deletes
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    -- Only run when the component we’re adding is itself a preparation
    SELECT c.recipe_id INTO _child_recipe_id
    FROM public.components c
    WHERE c.component_id = NEW.component_id AND c.recipe_id IS NOT NULL;

    IF _child_recipe_id IS NULL THEN
        RETURN NEW; -- child is not a preparation
    END IF;

    -- If the parent is not a preparation, cycles cannot occur (dishes are not components)
    SELECT c.component_id INTO _parent_prep_component_id
    FROM public.components c
    WHERE c.recipe_id = NEW.recipe_id AND c.recipe_id IS NOT NULL;

    IF _parent_prep_component_id IS NULL THEN
        RETURN NEW;
    END IF;

    /*
      Walk up the ancestor chain:
      starting from recipes that currently include the parent preparation as a component
      and climbing via recipe_components.recipe_id → recipes.preparation_id.
    */
    WITH RECURSIVE ancestors AS (
        -- Direct parents that include the parent preparation component
        SELECT rc.recipe_id                           AS ancestor_recipe_id,
               ARRAY[rc.recipe_id]                    AS path
        FROM   public.recipe_components rc
        WHERE  rc.component_id = _parent_prep_component_id

        UNION ALL

        SELECT rc2.recipe_id,
               a.path || rc2.recipe_id
        FROM   ancestors a
        JOIN   public.components cp ON cp.recipe_id = a.ancestor_recipe_id AND cp.recipe_id IS NOT NULL
        JOIN   public.recipe_components rc2
               ON rc2.component_id = cp.component_id
        WHERE  NOT rc2.recipe_id = ANY(a.path)
    )
    SELECT TRUE
      INTO _cycle_found
      FROM ancestors
     WHERE ancestor_recipe_id = _child_recipe_id
     LIMIT 1;

    IF _cycle_found THEN
        RAISE EXCEPTION
          'Cycle detected: adding preparation % as a component of recipe % would create a loop',
          NEW.component_id, NEW.recipe_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_preparation_cycle"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rc_prep_unit_guard"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  child_recipe_id uuid;
  yield_unit public.unit;
BEGIN
  -- Only enforce if component is a preparation (has a recipe_id)
  SELECT c.recipe_id INTO child_recipe_id
  FROM public.components c
  WHERE c.component_id = NEW.component_id AND c.recipe_id IS NOT NULL;

  IF child_recipe_id IS NULL THEN
    RETURN NEW; -- raw ingredient
  END IF;

  SELECT r.serving_or_yield_unit INTO yield_unit
  FROM public.recipes r WHERE r.recipe_id = child_recipe_id;

  IF yield_unit IS NULL THEN
    -- Should be normalized to 'x' via defaults; double-guard
    RAISE EXCEPTION 'Preparation yield must be defined';
  END IF;

  -- If yield is count, parent usage must be count
  IF yield_unit = 'x' AND NEW.unit <> 'x' THEN
    RAISE EXCEPTION 'When preparation yield is count (x), parent unit must be x';
  END IF;

  -- If yield is mass/volume, parent usage must match measurement kind
  IF yield_unit <> 'x' THEN
    IF public.unit_kind(NEW.unit) IS DISTINCT FROM public.unit_kind(yield_unit) THEN
      RAISE EXCEPTION 'Parent unit % incompatible with preparation yield %', NEW.unit, yield_unit;
    END IF;
  END IF;

  -- item is only allowed with count
  IF NEW.unit <> 'x' AND NEW.item IS NOT NULL THEN
    RAISE EXCEPTION 'item can only be set when unit = x';
  END IF;

  RETURN NEW;
END;$$;


ALTER FUNCTION "public"."rc_prep_unit_guard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_parent_amounts_on_yield_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "public"."recalculate_parent_amounts_on_yield_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recipe_components_item_unit_guard"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW.unit <> 'x' AND NEW.item IS NOT NULL THEN
    RAISE EXCEPTION 'item can only be set when unit = ''x''.';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."recipe_components_item_unit_guard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recipes_enforce_component_pairing"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  IF NEW.recipe_type = 'Preparation' THEN
    PERFORM 1 FROM public.components c
      WHERE c.recipe_id = NEW.recipe_id AND c.component_type = 'Preparation';
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Preparation recipe must have a matching components row';
    END IF;
  ELSE
    -- Dish must not have any components row pointing to it
    PERFORM 1 FROM public.components c
      WHERE c.recipe_id = NEW.recipe_id;
    IF FOUND THEN
      RAISE EXCEPTION 'Dish recipe cannot have a components row (component_type should be Preparation only)';
    END IF;
  END IF;
  RETURN NULL; -- for constraint triggers
END;
$$;


ALTER FUNCTION "public"."recipes_enforce_component_pairing"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."replace_recipe_components"("_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_recipe_kitchen uuid;
  v_component_ids uuid[];
  v_missing uuid[];
BEGIN
  -- Lock the recipe row
  PERFORM 1 FROM public.recipes r WHERE r.recipe_id = _recipe_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recipe % not found', _recipe_id; END IF;

  SELECT kitchen_id INTO v_recipe_kitchen FROM public.recipes WHERE recipe_id = _recipe_id;
  IF v_recipe_kitchen IS DISTINCT FROM _kitchen_id THEN RAISE EXCEPTION 'Kitchen mismatch for recipe %', _recipe_id; END IF;

  -- Collect component_ids for validation
  SELECT array_agg((x->>'component_id')::uuid)
  INTO v_component_ids
  FROM jsonb_array_elements(_items) AS x
  WHERE (x ? 'component_id') AND length(coalesce(x->>'component_id','')) > 0;

  -- Validate component_ids exist and belong to correct kitchen
  IF v_component_ids IS NOT NULL AND array_length(v_component_ids, 1) > 0 THEN
    -- Existence check
    SELECT array_agg(id)
    INTO v_missing
    FROM unnest(v_component_ids) AS id
    WHERE NOT EXISTS (SELECT 1 FROM public.components c WHERE c.component_id = id);
    IF v_missing IS NOT NULL AND array_length(v_missing, 1) > 0 THEN
      RAISE EXCEPTION 'Some components in payload do not exist: %', v_missing;
    END IF;

    -- Access check
    IF EXISTS (
      SELECT 1 FROM public.components c
      WHERE c.component_id = ANY(v_component_ids)
        AND c.kitchen_id IS DISTINCT FROM _kitchen_id
    ) THEN
      RAISE EXCEPTION 'Some components are not accessible in this kitchen';
    END IF;
  END IF;

  -- Replace children (no triggers to worry about)
  DELETE FROM public.recipe_components WHERE recipe_id = _recipe_id;

  INSERT INTO public.recipe_components (recipe_id, component_id, amount, unit, item)
  SELECT
    _recipe_id,
    (x->>'component_id')::uuid,
    COALESCE(NULLIF(x->>'amount','')::numeric, 0),
    (x->>'unit')::public.unit,
    CASE WHEN (x->>'unit') = 'x' THEN NULLIF(x->>'item','') ELSE NULL END
  FROM jsonb_array_elements(_items) AS x
  WHERE (x ? 'component_id')
    AND length(coalesce(x->>'component_id','')) > 0
    AND (x ? 'amount')
    AND (x ? 'unit');

  RETURN;
END;
$$;


ALTER FUNCTION "public"."replace_recipe_components"("_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_recipe_type"("p_recipe_id" "uuid", "p_new_type" "public"."recipe_type") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
  v_old_type public.recipe_type;
  v_kitchen_id uuid;
  v_name text;
BEGIN
  -- Lock row to avoid races
  SELECT recipe_type, kitchen_id, recipe_name INTO v_old_type, v_kitchen_id, v_name
  FROM public.recipes WHERE recipe_id = p_recipe_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Recipe % not found', p_recipe_id;
  END IF;

  IF v_old_type = p_new_type THEN
    RETURN;
  END IF;

  IF p_new_type = 'Preparation' THEN
    -- Update recipe first, then ensure matching component
    UPDATE public.recipes
      SET recipe_type = 'Preparation',
          serving_or_yield_unit = NULL,
          serving_or_yield_amount = NULL,
          serving_item = NULL
      WHERE recipe_id = p_recipe_id;

    -- Insert component if missing
    IF NOT EXISTS (
      SELECT 1 FROM public.components c WHERE c.recipe_id = p_recipe_id AND c.component_type = 'Preparation'
    ) THEN
      INSERT INTO public.components (name, component_type, kitchen_id, recipe_id)
      VALUES (COALESCE(v_name, ''), 'Preparation', v_kitchen_id, p_recipe_id);
    END IF;

  ELSIF p_new_type = 'Dish' THEN
    -- Remove any component row pointing to this recipe
    DELETE FROM public.components WHERE recipe_id = p_recipe_id;
    -- Update recipe type
    UPDATE public.recipes
      SET recipe_type = 'Dish'
      WHERE recipe_id = p_recipe_id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."set_recipe_type"("p_recipe_id" "uuid", "p_new_type" "public"."recipe_type") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new._updated_at = now();
  return NEW;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at_metadata"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return NEW;
end;
$$;


ALTER FUNCTION "public"."set_updated_at_metadata"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_components_update_fingerprint"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    _prep_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        _prep_id := OLD.recipe_id;
    ELSE
        _prep_id := NEW.recipe_id;
    END IF;

    PERFORM public.update_preparation_fingerprint(_prep_id);

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;


ALTER FUNCTION "public"."tg_components_update_fingerprint"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_preparations_set_fingerprint"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
  PERFORM public.update_preparation_fingerprint(NEW.preparation_id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."tg_preparations_set_fingerprint"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_recipe_components_update_fingerprint"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    _recipe_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        _recipe_id := OLD.recipe_id;
    ELSE
        _recipe_id := NEW.recipe_id;
    END IF;
    PERFORM public.update_recipe_fingerprint(_recipe_id);
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;


ALTER FUNCTION "public"."tg_recipe_components_update_fingerprint"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_recipes_set_fingerprint"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    PERFORM public.update_recipe_fingerprint(NEW.recipe_id);
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."tg_recipes_set_fingerprint"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_kitchen_ownership"("p_kitchen_id" "uuid", "p_new_owner_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_current_user_id uuid;
  v_current_owner_id uuid;
BEGIN
  -- Get the current user
  v_current_user_id := auth.uid();
  
  -- Check if current user is the owner
  SELECT owner_user_id INTO v_current_owner_id
  FROM public.kitchen
  WHERE kitchen_id = p_kitchen_id;
  
  IF v_current_owner_id IS NULL OR v_current_owner_id != v_current_user_id THEN
    RAISE EXCEPTION 'Only the current owner can transfer ownership';
  END IF;
  
  -- Check if new owner is a member of the kitchen
  IF NOT EXISTS (
    SELECT 1 FROM public.kitchen_users
    WHERE kitchen_id = p_kitchen_id
    AND user_id = p_new_owner_user_id
  ) THEN
    RAISE EXCEPTION 'New owner must be a member of the kitchen';
  END IF;
  
  -- Transfer ownership
  UPDATE public.kitchen
  SET owner_user_id = p_new_owner_user_id
  WHERE kitchen_id = p_kitchen_id;
  
  -- Ensure new owner is an admin
  UPDATE public.kitchen_users
  SET is_admin = true
  WHERE kitchen_id = p_kitchen_id
  AND user_id = p_new_owner_user_id;
  
  -- Update stripe_customer_links to reflect new owner
  UPDATE public.stripe_customer_links
  SET user_id = p_new_owner_user_id
  WHERE kitchen_id = p_kitchen_id;
  
  RETURN true;
END;
$$;


ALTER FUNCTION "public"."transfer_kitchen_ownership"("p_kitchen_id" "uuid", "p_new_owner_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unit_kind"("u" "public"."unit") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  SELECT CASE u
           WHEN 'mg' THEN 'mass' WHEN 'g' THEN 'mass' WHEN 'kg' THEN 'mass'
           WHEN 'oz' THEN 'mass' WHEN 'lb' THEN 'mass'
           WHEN 'ml' THEN 'volume' WHEN 'l' THEN 'volume'
           WHEN 'tsp' THEN 'volume' WHEN 'tbsp' THEN 'volume' WHEN 'cup' THEN 'volume'
           WHEN 'pt' THEN 'volume' WHEN 'qt' THEN 'volume' WHEN 'gal' THEN 'volume'
           WHEN 'x' THEN 'count'
           ELSE NULL
         END;
$$;


ALTER FUNCTION "public"."unit_kind"("u" "public"."unit") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_preparation_fingerprint"("_recipe_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    _plain text;
    _fp    uuid;
BEGIN
    -- Only for preparations
    IF NOT EXISTS (
        SELECT 1 FROM public.recipes r
         WHERE r.recipe_id = _recipe_id
           AND r.recipe_type = 'Preparation'
    ) THEN
        RETURN;
    END IF;

    /*
     * Build a Unicode-safe plain string:
     *  - component names: lower + trim + collapse whitespace; keep letters (all langs) and spaces
     *  - directions: lower + collapse whitespace; strip non-letters except spaces
     */
    SELECT COALESCE(
             string_agg(
               regexp_replace(lower(trim(c.name)), '\\s+', ' ', 'g'),
               ' ' ORDER BY regexp_replace(lower(trim(c.name)), '\\s+', ' ', 'g')
             ),
             'empty'
           ) || '|' ||
           regexp_replace(lower(array_to_string(r.directions, ' ')), '[^[:alpha:]\s]+', ' ', 'g')
      INTO _plain
      FROM public.recipes r
      LEFT JOIN public.recipe_components rc ON rc.recipe_id = r.recipe_id
      LEFT JOIN public.components c ON c.component_id = rc.component_id
     WHERE r.recipe_id = _recipe_id
     GROUP BY r.directions;

    _plain := regexp_replace(coalesce(_plain, ''), '\\s+', ' ', 'g');
    _plain := trim(_plain);

    _fp := public.uuid_generate_v5(public.fp_namespace(), _plain);

    UPDATE public.recipes
       SET fingerprint       = _fp,
           fingerprint_plain = _plain
     WHERE recipe_id = _recipe_id
       AND (fingerprint IS DISTINCT FROM _fp OR fingerprint_plain IS DISTINCT FROM _plain);
END;
$$;


ALTER FUNCTION "public"."update_preparation_fingerprint"("_recipe_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_recipe_fingerprint"("_recipe_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    _plain text;
    _fp    uuid;
BEGIN
    -- Skip if recipe does not exist
    IF NOT EXISTS (SELECT 1 FROM public.recipes r WHERE r.recipe_id = _recipe_id) THEN
        RETURN;
    END IF;

    /*
     * Build a Unicode-safe plain string from component names and directions:
     *  - component names: lower + trim + collapse whitespace
     *  - directions:      lower + collapse whitespace; strip non-letters except spaces
     */
    SELECT COALESCE(
             string_agg(
               regexp_replace(lower(trim(c.name)), '\\s+', ' ', 'g'),
               ' ' ORDER BY regexp_replace(lower(trim(c.name)), '\\s+', ' ', 'g')
             ),
             'empty'
           ) || '|' ||
           regexp_replace(lower(array_to_string(r.directions, ' ')), '[^[:alpha:]\s]+', ' ', 'g')
      INTO _plain
      FROM public.recipes r
      LEFT JOIN public.recipe_components rc ON rc.recipe_id = r.recipe_id
      LEFT JOIN public.components c ON c.component_id = rc.component_id
     WHERE r.recipe_id = _recipe_id
     GROUP BY r.directions;

    _plain := regexp_replace(coalesce(_plain, ''), '\\s+', ' ', 'g');
    _plain := trim(_plain);

    _fp := public.uuid_generate_v5(public.fp_namespace(), _plain);

    UPDATE public.recipes
       SET fingerprint       = _fp,
           fingerprint_plain = _plain
     WHERE recipe_id = _recipe_id
       AND (fingerprint IS DISTINCT FROM _fp OR fingerprint_plain IS DISTINCT FROM _plain);
END;
$$;


ALTER FUNCTION "public"."update_recipe_fingerprint"("_recipe_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_stripe_customer_links_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_stripe_customer_links_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
   NEW.updated_at = NOW(); 
   RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_preparation_components"("_prep_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
  v_recipe_kitchen uuid;
  v_component_ids uuid[];
  v_missing uuid[];
BEGIN
  -- Lock the prep recipe row to serialize concurrent updates
  PERFORM 1 FROM public.recipes r WHERE r.recipe_id = _prep_recipe_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Preparation recipe % not found', _prep_recipe_id;
  END IF;

  SELECT kitchen_id INTO v_recipe_kitchen FROM public.recipes WHERE recipe_id = _prep_recipe_id;
  IF v_recipe_kitchen IS DISTINCT FROM _kitchen_id THEN
    RAISE EXCEPTION 'Kitchen mismatch for preparation %', _prep_recipe_id;
  END IF;

  -- Collect component_ids for validation
  SELECT array_agg((x->>'component_id')::uuid)
  INTO v_component_ids
  FROM jsonb_array_elements(_items) AS x
  WHERE (x ? 'component_id') AND length(coalesce(x->>'component_id','')) > 0;

  -- Validate component_ids exist and belong to correct kitchen
  IF v_component_ids IS NOT NULL AND array_length(v_component_ids, 1) > 0 THEN
    -- Existence check: all provided component_ids must exist
    SELECT array_agg(id)
    INTO v_missing
    FROM unnest(v_component_ids) AS id
    WHERE NOT EXISTS (SELECT 1 FROM public.components c WHERE c.component_id = id);
    IF v_missing IS NOT NULL AND array_length(v_missing, 1) > 0 THEN
      RAISE EXCEPTION 'Some components in payload do not exist: %', v_missing;
    END IF;

    -- Access check: all components must belong to same kitchen (via components table)
    IF EXISTS (
      SELECT 1 FROM public.components c
      WHERE c.component_id = ANY(v_component_ids)
        AND c.kitchen_id IS DISTINCT FROM _kitchen_id
    ) THEN
      RAISE EXCEPTION 'Some nested components are not accessible in this kitchen';
    END IF;
  END IF;

  -- Replace children (no triggers to worry about)
  DELETE FROM public.recipe_components rc WHERE rc.recipe_id = _prep_recipe_id;

  INSERT INTO public.recipe_components (recipe_id, component_id, amount, unit, item)
  SELECT
    _prep_recipe_id,
    (x->>'component_id')::uuid,
    COALESCE(NULLIF(x->>'amount','')::numeric, 0),
    (x->>'unit')::public.unit,
    CASE WHEN (x->>'unit') = 'x' THEN NULLIF(x->>'item','') ELSE NULL END
  FROM jsonb_array_elements(_items) AS x
  WHERE (x ? 'component_id')
    AND length(coalesce(x->>'component_id','')) > 0
    AND (x ? 'amount')
    AND (x ? 'unit');

  RETURN;
END;
$$;


ALTER FUNCTION "public"."upsert_preparation_components"("_prep_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."uuid_generate_v5"("namespace" "uuid", "name" "text") RETURNS "uuid"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
    SELECT extensions.uuid_generate_v5(namespace, name);
$$;


ALTER FUNCTION "public"."uuid_generate_v5"("namespace" "uuid", "name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."uuid_ns_dns"() RETURNS "uuid"
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    SET "search_path" TO ''
    AS $$
  SELECT extensions.uuid_ns_dns();
$$;


ALTER FUNCTION "public"."uuid_ns_dns"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verify_kitchen_owner_is_member"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Only check if owner_user_id is set (i.e., Team kitchens)
  IF NEW.owner_user_id IS NOT NULL THEN
    -- Verify the owner exists in kitchen_users for this kitchen
    IF NOT EXISTS (
      SELECT 1 
      FROM public.kitchen_users 
      WHERE kitchen_id = NEW.kitchen_id 
        AND user_id = NEW.owner_user_id
    ) THEN
      RAISE EXCEPTION 'Kitchen owner must be a member of the kitchen (kitchen_id: %, owner_user_id: %)', 
        NEW.kitchen_id, NEW.owner_user_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."verify_kitchen_owner_is_member"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."verify_kitchen_owner_is_member"() IS 'Verifies that the kitchen owner (owner_user_id) is a member of the kitchen in kitchen_users';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "category_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "kitchen_id" "uuid" NOT NULL
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."components" (
    "name" "text" NOT NULL,
    "component_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "kitchen_id" "uuid" DEFAULT '816f8fdb-fedd-4e6e-899b-9c98513e49c5'::"uuid" NOT NULL,
    "component_type" "public"."component_type" DEFAULT 'Raw_Ingredient'::"public"."component_type" NOT NULL,
    "recipe_id" "uuid",
    CONSTRAINT "components_recipe_id_check" CHECK (((("component_type" = 'Preparation'::"public"."component_type") AND ("recipe_id" IS NOT NULL)) OR (("component_type" <> 'Preparation'::"public"."component_type") AND ("recipe_id" IS NULL)))),
    CONSTRAINT "components_recipe_id_nullable_by_type" CHECK (((("component_type" = 'Preparation'::"public"."component_type") AND ("recipe_id" IS NOT NULL)) OR (("component_type" = 'Raw_Ingredient'::"public"."component_type") AND ("recipe_id" IS NULL))))
);


ALTER TABLE "public"."components" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kitchen" (
    "kitchen_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" DEFAULT 'new_kitchen'::"text" NOT NULL,
    "type" "public"."KitchenType" DEFAULT 'Personal'::"public"."KitchenType" NOT NULL,
    "owner_user_id" "uuid",
    CONSTRAINT "kitchen_owner_type_check" CHECK (((("type" = 'Team'::"public"."KitchenType") AND ("owner_user_id" IS NOT NULL)) OR (("type" = 'Personal'::"public"."KitchenType") AND ("owner_user_id" IS NULL))))
);


ALTER TABLE "public"."kitchen" OWNER TO "postgres";


COMMENT ON CONSTRAINT "kitchen_owner_type_check" ON "public"."kitchen" IS 'Ensures Team kitchens have an owner and Personal kitchens do not';



CREATE TABLE IF NOT EXISTS "public"."kitchen_invites" (
    "invite_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "kitchen_id" "uuid" NOT NULL,
    "invite_code" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "max_uses" integer DEFAULT 1 NOT NULL,
    "current_uses" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."kitchen_invites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stripe_customer_links" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "kitchen_id" "uuid",
    "stripe_customer_id" "text" NOT NULL,
    "team_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."stripe_customer_links" OWNER TO "postgres";


COMMENT ON TABLE "public"."stripe_customer_links" IS 'Links Stripe customers to ROA users and kitchens. One subscription per kitchen enforced via UNIQUE constraint on kitchen_id.';



CREATE TABLE IF NOT EXISTS "stripe"."subscriptions" (
    "_account_id" "text" NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "application_fee_percent" double precision GENERATED ALWAYS AS ((("_raw_data" ->> 'application_fee_percent'::"text"))::double precision) STORED,
    "billing_cycle_anchor" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'billing_cycle_anchor'::"text"))::integer) STORED,
    "billing_thresholds" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'billing_thresholds'::"text")) STORED,
    "cancel_at" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'cancel_at'::"text"))::integer) STORED,
    "collection_method" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'collection_method'::"text")) STORED,
    "days_until_due" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'days_until_due'::"text"))::integer) STORED,
    "default_payment_method" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'default_payment_method'::"text")) STORED,
    "default_source" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'default_source'::"text")) STORED,
    "default_tax_rates" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'default_tax_rates'::"text")) STORED,
    "discount" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'discount'::"text")) STORED,
    "ended_at" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'ended_at'::"text"))::integer) STORED,
    "items" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'items'::"text")) STORED,
    "latest_invoice" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'latest_invoice'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "next_pending_invoice_item_invoice" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'next_pending_invoice_item_invoice'::"text"))::integer) STORED,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "pause_collection" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'pause_collection'::"text")) STORED,
    "pending_invoice_item_interval" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'pending_invoice_item_interval'::"text")) STORED,
    "pending_setup_intent" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'pending_setup_intent'::"text")) STORED,
    "pending_update" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'pending_update'::"text")) STORED,
    "plan" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'plan'::"text")) STORED,
    "schedule" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'schedule'::"text")) STORED,
    "start_date" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'start_date'::"text"))::integer) STORED,
    "transfer_data" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'transfer_data'::"text")) STORED,
    "trial_end" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'trial_end'::"text")) STORED,
    "trial_start" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'trial_start'::"text")) STORED,
    "cancel_at_period_end" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'cancel_at_period_end'::"text"))::boolean) STORED,
    "canceled_at" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'canceled_at'::"text"))::integer) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "current_period_end" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'current_period_end'::"text"))::integer) STORED,
    "current_period_start" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'current_period_start'::"text"))::integer) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED
);


ALTER TABLE "stripe"."subscriptions" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."kitchen_subscription_status" AS
 SELECT "scl"."kitchen_id",
    "scl"."user_id" AS "paying_user_id",
    "scl"."stripe_customer_id",
    "scl"."team_name",
    "s"."id" AS "stripe_subscription_id",
    "s"."status",
    "to_timestamp"(("s"."current_period_start")::double precision) AS "current_period_start",
    "to_timestamp"(("s"."current_period_end")::double precision) AS "current_period_end",
    "s"."cancel_at_period_end",
    "to_timestamp"(("s"."canceled_at")::double precision) AS "canceled_at",
    "to_timestamp"(("s"."created")::double precision) AS "subscription_created_at",
        CASE
            WHEN (("s"."status" = ANY (ARRAY['trialing'::"text", 'active'::"text"])) AND (("s"."current_period_end" IS NULL) OR ("to_timestamp"(("s"."current_period_end")::double precision) > "now"()))) THEN true
            ELSE false
        END AS "is_active"
   FROM ("public"."stripe_customer_links" "scl"
     LEFT JOIN "stripe"."subscriptions" "s" ON (("s"."customer" = "scl"."stripe_customer_id")));


ALTER VIEW "public"."kitchen_subscription_status" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kitchen_users" (
    "kitchen_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "is_admin" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."kitchen_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."recipe_components" (
    "recipe_id" "uuid" NOT NULL,
    "component_id" "uuid" NOT NULL,
    "amount" numeric NOT NULL,
    "unit" "public"."unit" NOT NULL,
    "item" "text",
    CONSTRAINT "recipe_components_item_unit_check" CHECK ((("unit" = 'x'::"public"."unit") OR ("item" IS NULL)))
);


ALTER TABLE "public"."recipe_components" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."recipes" (
    "recipe_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "category_id" "uuid",
    "recipe_name" "text" NOT NULL,
    "time" interval DEFAULT '00:30:00'::interval NOT NULL,
    "serving_or_yield_amount" integer DEFAULT 1 NOT NULL,
    "cooking_notes" "text",
    "serving_item" "text" DEFAULT 'Buns'::"text",
    "directions" "text"[],
    "kitchen_id" "uuid" NOT NULL,
    "image_updated_at" timestamp with time zone,
    "recipe_type" "public"."recipe_type" DEFAULT 'Dish'::"public"."recipe_type" NOT NULL,
    "serving_or_yield_unit" "public"."unit" DEFAULT 'x'::"public"."unit" NOT NULL,
    "fingerprint" "uuid",
    "fingerprint_plain" "text",
    CONSTRAINT "recipes_serving_item_requires_x" CHECK ((("serving_item" IS NULL) OR ("serving_or_yield_unit" = 'x'::"public"."unit"))),
    CONSTRAINT "recipes_x_yield_is_1" CHECK ((("recipe_type" IS DISTINCT FROM 'Preparation'::"public"."recipe_type") OR ("serving_or_yield_unit" IS DISTINCT FROM 'x'::"public"."unit") OR ("serving_or_yield_amount" = 1))),
    CONSTRAINT "recipes_yield_pair_check" CHECK (((("serving_or_yield_unit" IS NULL) AND ("serving_or_yield_amount" IS NULL)) OR (("serving_or_yield_unit" IS NOT NULL) AND ("serving_or_yield_amount" IS NOT NULL))))
);


ALTER TABLE "public"."recipes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "user_id" "uuid" NOT NULL,
    "user_fullname" "text",
    "user_email" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."_managed_webhooks" (
    "id" "text" NOT NULL,
    "object" "text",
    "url" "text" NOT NULL,
    "enabled_events" "jsonb" NOT NULL,
    "description" "text",
    "enabled" boolean,
    "livemode" boolean,
    "metadata" "jsonb",
    "secret" "text" NOT NULL,
    "status" "text",
    "api_version" "text",
    "created" integer,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "last_synced_at" timestamp with time zone,
    "account_id" "text" NOT NULL
);


ALTER TABLE "stripe"."_managed_webhooks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."_migrations" (
    "id" integer NOT NULL,
    "name" character varying(100) NOT NULL,
    "hash" character varying(40) NOT NULL,
    "executed_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "stripe"."_migrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."_sync_obj_runs" (
    "_account_id" "text" NOT NULL,
    "run_started_at" timestamp with time zone NOT NULL,
    "object" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "processed_count" integer DEFAULT 0,
    "cursor" "text",
    "error_message" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "_sync_obj_run_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'running'::"text", 'complete'::"text", 'error'::"text"])))
);


ALTER TABLE "stripe"."_sync_obj_runs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."_sync_runs" (
    "_account_id" "text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "max_concurrent" integer DEFAULT 3 NOT NULL,
    "error_message" "text",
    "triggered_by" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "closed_at" timestamp with time zone
);


ALTER TABLE "stripe"."_sync_runs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."accounts" (
    "_raw_data" "jsonb" NOT NULL,
    "first_synced_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "_last_synced_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "_updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "business_name" "text" GENERATED ALWAYS AS ((("_raw_data" -> 'business_profile'::"text") ->> 'name'::"text")) STORED,
    "email" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'email'::"text")) STORED,
    "type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'type'::"text")) STORED,
    "charges_enabled" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'charges_enabled'::"text"))::boolean) STORED,
    "payouts_enabled" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'payouts_enabled'::"text"))::boolean) STORED,
    "details_submitted" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'details_submitted'::"text"))::boolean) STORED,
    "country" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'country'::"text")) STORED,
    "default_currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'default_currency'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "api_key_hashes" "text"[] DEFAULT '{}'::"text"[],
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."accounts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."active_entitlements" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "feature" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'feature'::"text")) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "lookup_key" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'lookup_key'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."active_entitlements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."charges" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "paid" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'paid'::"text"))::boolean) STORED,
    "order" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'order'::"text")) STORED,
    "amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount'::"text"))::bigint) STORED,
    "review" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'review'::"text")) STORED,
    "source" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'source'::"text")) STORED,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "dispute" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'dispute'::"text")) STORED,
    "invoice" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'invoice'::"text")) STORED,
    "outcome" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'outcome'::"text")) STORED,
    "refunds" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'refunds'::"text")) STORED,
    "updated" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'updated'::"text"))::integer) STORED,
    "captured" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'captured'::"text"))::boolean) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "refunded" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'refunded'::"text"))::boolean) STORED,
    "shipping" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'shipping'::"text")) STORED,
    "application" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'application'::"text")) STORED,
    "description" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'description'::"text")) STORED,
    "destination" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'destination'::"text")) STORED,
    "failure_code" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'failure_code'::"text")) STORED,
    "on_behalf_of" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'on_behalf_of'::"text")) STORED,
    "fraud_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'fraud_details'::"text")) STORED,
    "receipt_email" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'receipt_email'::"text")) STORED,
    "payment_intent" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_intent'::"text")) STORED,
    "receipt_number" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'receipt_number'::"text")) STORED,
    "transfer_group" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'transfer_group'::"text")) STORED,
    "amount_refunded" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_refunded'::"text"))::bigint) STORED,
    "application_fee" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'application_fee'::"text")) STORED,
    "failure_message" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'failure_message'::"text")) STORED,
    "source_transfer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'source_transfer'::"text")) STORED,
    "balance_transaction" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'balance_transaction'::"text")) STORED,
    "statement_descriptor" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'statement_descriptor'::"text")) STORED,
    "payment_method_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'payment_method_details'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."charges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."checkout_session_line_items" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "description" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'description'::"text")) STORED,
    "price" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'price'::"text")) STORED,
    "quantity" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'quantity'::"text"))::integer) STORED,
    "checkout_session" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'checkout_session'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL,
    "amount_discount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_discount'::"text"))::bigint) STORED,
    "amount_subtotal" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_subtotal'::"text"))::bigint) STORED,
    "amount_tax" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_tax'::"text"))::bigint) STORED,
    "amount_total" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_total'::"text"))::bigint) STORED
);


ALTER TABLE "stripe"."checkout_session_line_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."checkout_sessions" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "adaptive_pricing" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'adaptive_pricing'::"text")) STORED,
    "after_expiration" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'after_expiration'::"text")) STORED,
    "allow_promotion_codes" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'allow_promotion_codes'::"text"))::boolean) STORED,
    "automatic_tax" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'automatic_tax'::"text")) STORED,
    "billing_address_collection" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'billing_address_collection'::"text")) STORED,
    "cancel_url" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'cancel_url'::"text")) STORED,
    "client_reference_id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'client_reference_id'::"text")) STORED,
    "client_secret" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'client_secret'::"text")) STORED,
    "collected_information" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'collected_information'::"text")) STORED,
    "consent" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'consent'::"text")) STORED,
    "consent_collection" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'consent_collection'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "currency_conversion" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'currency_conversion'::"text")) STORED,
    "custom_fields" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'custom_fields'::"text")) STORED,
    "custom_text" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'custom_text'::"text")) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "customer_creation" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer_creation'::"text")) STORED,
    "customer_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'customer_details'::"text")) STORED,
    "customer_email" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer_email'::"text")) STORED,
    "discounts" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'discounts'::"text")) STORED,
    "expires_at" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'expires_at'::"text"))::integer) STORED,
    "invoice" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'invoice'::"text")) STORED,
    "invoice_creation" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'invoice_creation'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "locale" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'locale'::"text")) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "mode" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'mode'::"text")) STORED,
    "optional_items" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'optional_items'::"text")) STORED,
    "payment_intent" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_intent'::"text")) STORED,
    "payment_link" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_link'::"text")) STORED,
    "payment_method_collection" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_method_collection'::"text")) STORED,
    "payment_method_configuration_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'payment_method_configuration_details'::"text")) STORED,
    "payment_method_options" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'payment_method_options'::"text")) STORED,
    "payment_method_types" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'payment_method_types'::"text")) STORED,
    "payment_status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_status'::"text")) STORED,
    "permissions" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'permissions'::"text")) STORED,
    "phone_number_collection" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'phone_number_collection'::"text")) STORED,
    "presentment_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'presentment_details'::"text")) STORED,
    "recovered_from" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'recovered_from'::"text")) STORED,
    "redirect_on_completion" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'redirect_on_completion'::"text")) STORED,
    "return_url" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'return_url'::"text")) STORED,
    "saved_payment_method_options" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'saved_payment_method_options'::"text")) STORED,
    "setup_intent" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'setup_intent'::"text")) STORED,
    "shipping_address_collection" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'shipping_address_collection'::"text")) STORED,
    "shipping_cost" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'shipping_cost'::"text")) STORED,
    "shipping_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'shipping_details'::"text")) STORED,
    "shipping_options" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'shipping_options'::"text")) STORED,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED,
    "submit_type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'submit_type'::"text")) STORED,
    "subscription" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'subscription'::"text")) STORED,
    "success_url" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'success_url'::"text")) STORED,
    "tax_id_collection" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'tax_id_collection'::"text")) STORED,
    "total_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'total_details'::"text")) STORED,
    "ui_mode" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'ui_mode'::"text")) STORED,
    "url" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'url'::"text")) STORED,
    "wallet_options" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'wallet_options'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL,
    "amount_subtotal" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_subtotal'::"text"))::bigint) STORED,
    "amount_total" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_total'::"text"))::bigint) STORED
);


ALTER TABLE "stripe"."checkout_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."coupons" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "name" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'name'::"text")) STORED,
    "valid" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'valid'::"text"))::boolean) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "updated" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'updated'::"text"))::integer) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "duration" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'duration'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "redeem_by" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'redeem_by'::"text"))::integer) STORED,
    "amount_off" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_off'::"text"))::bigint) STORED,
    "percent_off" double precision GENERATED ALWAYS AS ((("_raw_data" ->> 'percent_off'::"text"))::double precision) STORED,
    "times_redeemed" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'times_redeemed'::"text"))::bigint) STORED,
    "max_redemptions" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'max_redemptions'::"text"))::bigint) STORED,
    "duration_in_months" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'duration_in_months'::"text"))::bigint) STORED,
    "percent_off_precise" double precision GENERATED ALWAYS AS ((("_raw_data" ->> 'percent_off_precise'::"text"))::double precision) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."coupons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."credit_notes" (
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "customer_balance_transaction" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer_balance_transaction'::"text")) STORED,
    "discount_amounts" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'discount_amounts'::"text")) STORED,
    "invoice" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'invoice'::"text")) STORED,
    "lines" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'lines'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "memo" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'memo'::"text")) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "number" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'number'::"text")) STORED,
    "pdf" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'pdf'::"text")) STORED,
    "reason" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'reason'::"text")) STORED,
    "refund" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'refund'::"text")) STORED,
    "shipping_cost" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'shipping_cost'::"text")) STORED,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED,
    "tax_amounts" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'tax_amounts'::"text")) STORED,
    "type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'type'::"text")) STORED,
    "voided_at" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'voided_at'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL,
    "amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount'::"text"))::bigint) STORED,
    "amount_shipping" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_shipping'::"text"))::bigint) STORED,
    "discount_amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'discount_amount'::"text"))::bigint) STORED,
    "out_of_band_amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'out_of_band_amount'::"text"))::bigint) STORED,
    "subtotal" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'subtotal'::"text"))::bigint) STORED,
    "subtotal_excluding_tax" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'subtotal_excluding_tax'::"text"))::bigint) STORED,
    "total" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'total'::"text"))::bigint) STORED,
    "total_excluding_tax" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'total_excluding_tax'::"text"))::bigint) STORED
);


ALTER TABLE "stripe"."credit_notes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."customers" (
    "_account_id" "text" NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "address" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'address'::"text")) STORED,
    "balance" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'balance'::"text"))::bigint) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "default_source" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'default_source'::"text")) STORED,
    "deleted" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'deleted'::"text"))::boolean) STORED,
    "delinquent" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'delinquent'::"text"))::boolean) STORED,
    "discount" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'discount'::"text")) STORED,
    "invoice_prefix" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'invoice_prefix'::"text")) STORED,
    "invoice_settings" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'invoice_settings'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "next_invoice_sequence" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'next_invoice_sequence'::"text"))::integer) STORED,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "phone" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'phone'::"text")) STORED,
    "preferred_locales" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'preferred_locales'::"text")) STORED,
    "shipping" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'shipping'::"text")) STORED,
    "tax_exempt" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'tax_exempt'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "description" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'description'::"text")) STORED,
    "email" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'email'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL,
    "name" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'name'::"text")) STORED
);


ALTER TABLE "stripe"."customers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."disputes" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount'::"text"))::bigint) STORED,
    "charge" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'charge'::"text")) STORED,
    "reason" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'reason'::"text")) STORED,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "updated" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'updated'::"text"))::integer) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "evidence" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'evidence'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "evidence_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'evidence_details'::"text")) STORED,
    "balance_transactions" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'balance_transactions'::"text")) STORED,
    "is_charge_refundable" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'is_charge_refundable'::"text"))::boolean) STORED,
    "payment_intent" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_intent'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."disputes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."early_fraud_warnings" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "actionable" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'actionable'::"text"))::boolean) STORED,
    "charge" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'charge'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "fraud_type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'fraud_type'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "payment_intent" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_intent'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."early_fraud_warnings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."events" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "data" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'data'::"text")) STORED,
    "type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'type'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "request" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'request'::"text")) STORED,
    "updated" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'updated'::"text"))::integer) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "api_version" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'api_version'::"text")) STORED,
    "pending_webhooks" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'pending_webhooks'::"text"))::bigint) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."exchange_rates_from_usd" (
    "_raw_data" "jsonb" NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_updated_at" timestamp with time zone DEFAULT "now"(),
    "_account_id" "text" NOT NULL,
    "date" "date" NOT NULL,
    "sell_currency" "text" NOT NULL,
    "buy_currency_exchange_rates" "text" GENERATED ALWAYS AS (NULLIF(("_raw_data" ->> 'buy_currency_exchange_rates'::"text"), ''::"text")) STORED
);


ALTER TABLE "stripe"."exchange_rates_from_usd" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."features" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "name" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'name'::"text")) STORED,
    "lookup_key" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'lookup_key'::"text")) STORED,
    "active" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'active'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."features" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."invoices" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "auto_advance" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'auto_advance'::"text"))::boolean) STORED,
    "collection_method" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'collection_method'::"text")) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "description" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'description'::"text")) STORED,
    "hosted_invoice_url" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'hosted_invoice_url'::"text")) STORED,
    "lines" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'lines'::"text")) STORED,
    "period_end" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'period_end'::"text"))::integer) STORED,
    "period_start" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'period_start'::"text"))::integer) STORED,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED,
    "total" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'total'::"text"))::bigint) STORED,
    "account_country" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'account_country'::"text")) STORED,
    "account_name" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'account_name'::"text")) STORED,
    "account_tax_ids" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'account_tax_ids'::"text")) STORED,
    "amount_due" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_due'::"text"))::bigint) STORED,
    "amount_paid" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_paid'::"text"))::bigint) STORED,
    "amount_remaining" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_remaining'::"text"))::bigint) STORED,
    "application_fee_amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'application_fee_amount'::"text"))::bigint) STORED,
    "attempt_count" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'attempt_count'::"text"))::integer) STORED,
    "attempted" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'attempted'::"text"))::boolean) STORED,
    "billing_reason" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'billing_reason'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "custom_fields" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'custom_fields'::"text")) STORED,
    "customer_address" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'customer_address'::"text")) STORED,
    "customer_email" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer_email'::"text")) STORED,
    "customer_name" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer_name'::"text")) STORED,
    "customer_phone" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer_phone'::"text")) STORED,
    "customer_shipping" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'customer_shipping'::"text")) STORED,
    "customer_tax_exempt" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer_tax_exempt'::"text")) STORED,
    "customer_tax_ids" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'customer_tax_ids'::"text")) STORED,
    "default_tax_rates" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'default_tax_rates'::"text")) STORED,
    "discount" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'discount'::"text")) STORED,
    "discounts" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'discounts'::"text")) STORED,
    "due_date" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'due_date'::"text"))::integer) STORED,
    "footer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'footer'::"text")) STORED,
    "invoice_pdf" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'invoice_pdf'::"text")) STORED,
    "last_finalization_error" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'last_finalization_error'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "next_payment_attempt" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'next_payment_attempt'::"text"))::integer) STORED,
    "number" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'number'::"text")) STORED,
    "paid" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'paid'::"text"))::boolean) STORED,
    "payment_settings" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'payment_settings'::"text")) STORED,
    "receipt_number" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'receipt_number'::"text")) STORED,
    "statement_descriptor" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'statement_descriptor'::"text")) STORED,
    "status_transitions" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'status_transitions'::"text")) STORED,
    "total_discount_amounts" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'total_discount_amounts'::"text")) STORED,
    "total_tax_amounts" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'total_tax_amounts'::"text")) STORED,
    "transfer_data" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'transfer_data'::"text")) STORED,
    "webhooks_delivered_at" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'webhooks_delivered_at'::"text"))::integer) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "subscription" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'subscription'::"text")) STORED,
    "payment_intent" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_intent'::"text")) STORED,
    "default_payment_method" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'default_payment_method'::"text")) STORED,
    "default_source" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'default_source'::"text")) STORED,
    "on_behalf_of" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'on_behalf_of'::"text")) STORED,
    "charge" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'charge'::"text")) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL,
    "ending_balance" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'ending_balance'::"text"))::bigint) STORED,
    "starting_balance" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'starting_balance'::"text"))::bigint) STORED,
    "subtotal" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'subtotal'::"text"))::bigint) STORED,
    "tax" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'tax'::"text"))::bigint) STORED,
    "post_payment_credit_notes_amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'post_payment_credit_notes_amount'::"text"))::bigint) STORED,
    "pre_payment_credit_notes_amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'pre_payment_credit_notes_amount'::"text"))::bigint) STORED
);


ALTER TABLE "stripe"."invoices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."payment_intents" (
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "amount_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'amount_details'::"text")) STORED,
    "application" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'application'::"text")) STORED,
    "automatic_payment_methods" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'automatic_payment_methods'::"text")) STORED,
    "canceled_at" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'canceled_at'::"text"))::integer) STORED,
    "cancellation_reason" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'cancellation_reason'::"text")) STORED,
    "capture_method" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'capture_method'::"text")) STORED,
    "client_secret" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'client_secret'::"text")) STORED,
    "confirmation_method" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'confirmation_method'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "description" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'description'::"text")) STORED,
    "invoice" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'invoice'::"text")) STORED,
    "last_payment_error" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'last_payment_error'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "next_action" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'next_action'::"text")) STORED,
    "on_behalf_of" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'on_behalf_of'::"text")) STORED,
    "payment_method" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_method'::"text")) STORED,
    "payment_method_options" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'payment_method_options'::"text")) STORED,
    "payment_method_types" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'payment_method_types'::"text")) STORED,
    "processing" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'processing'::"text")) STORED,
    "receipt_email" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'receipt_email'::"text")) STORED,
    "review" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'review'::"text")) STORED,
    "setup_future_usage" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'setup_future_usage'::"text")) STORED,
    "shipping" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'shipping'::"text")) STORED,
    "statement_descriptor" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'statement_descriptor'::"text")) STORED,
    "statement_descriptor_suffix" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'statement_descriptor_suffix'::"text")) STORED,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED,
    "transfer_data" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'transfer_data'::"text")) STORED,
    "transfer_group" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'transfer_group'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL,
    "amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount'::"text"))::bigint) STORED,
    "amount_capturable" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_capturable'::"text"))::bigint) STORED,
    "amount_received" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_received'::"text"))::bigint) STORED,
    "application_fee_amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'application_fee_amount'::"text"))::bigint) STORED
);


ALTER TABLE "stripe"."payment_intents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."payment_methods" (
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'type'::"text")) STORED,
    "billing_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'billing_details'::"text")) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "card" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'card'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."payment_methods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."payouts" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "date" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'date'::"text")) STORED,
    "type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'type'::"text")) STORED,
    "amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount'::"text"))::bigint) STORED,
    "method" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'method'::"text")) STORED,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "updated" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'updated'::"text"))::integer) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "automatic" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'automatic'::"text"))::boolean) STORED,
    "recipient" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'recipient'::"text")) STORED,
    "description" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'description'::"text")) STORED,
    "destination" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'destination'::"text")) STORED,
    "source_type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'source_type'::"text")) STORED,
    "arrival_date" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'arrival_date'::"text")) STORED,
    "bank_account" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'bank_account'::"text")) STORED,
    "failure_code" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'failure_code'::"text")) STORED,
    "transfer_group" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'transfer_group'::"text")) STORED,
    "amount_reversed" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount_reversed'::"text"))::bigint) STORED,
    "failure_message" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'failure_message'::"text")) STORED,
    "source_transaction" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'source_transaction'::"text")) STORED,
    "balance_transaction" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'balance_transaction'::"text")) STORED,
    "statement_descriptor" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'statement_descriptor'::"text")) STORED,
    "statement_description" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'statement_description'::"text")) STORED,
    "failure_balance_transaction" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'failure_balance_transaction'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."payouts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."plans" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "name" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'name'::"text")) STORED,
    "tiers" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'tiers'::"text")) STORED,
    "active" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'active'::"text"))::boolean) STORED,
    "amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount'::"text"))::bigint) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "product" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'product'::"text")) STORED,
    "updated" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'updated'::"text"))::integer) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "interval" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'interval'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "nickname" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'nickname'::"text")) STORED,
    "tiers_mode" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'tiers_mode'::"text")) STORED,
    "usage_type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'usage_type'::"text")) STORED,
    "billing_scheme" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'billing_scheme'::"text")) STORED,
    "interval_count" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'interval_count'::"text"))::bigint) STORED,
    "aggregate_usage" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'aggregate_usage'::"text")) STORED,
    "transform_usage" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'transform_usage'::"text")) STORED,
    "trial_period_days" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'trial_period_days'::"text"))::bigint) STORED,
    "statement_descriptor" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'statement_descriptor'::"text")) STORED,
    "statement_description" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'statement_description'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."prices" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "active" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'active'::"text"))::boolean) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "nickname" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'nickname'::"text")) STORED,
    "recurring" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'recurring'::"text")) STORED,
    "type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'type'::"text")) STORED,
    "billing_scheme" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'billing_scheme'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "lookup_key" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'lookup_key'::"text")) STORED,
    "tiers_mode" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'tiers_mode'::"text")) STORED,
    "transform_quantity" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'transform_quantity'::"text")) STORED,
    "unit_amount_decimal" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'unit_amount_decimal'::"text")) STORED,
    "product" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'product'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL,
    "unit_amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'unit_amount'::"text"))::bigint) STORED
);


ALTER TABLE "stripe"."prices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."products" (
    "_account_id" "text" NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "default_price" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'default_price'::"text")) STORED,
    "images" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'images'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "marketing_features" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'marketing_features'::"text")) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "package_dimensions" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'package_dimensions'::"text")) STORED,
    "shippable" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'shippable'::"text"))::boolean) STORED,
    "statement_descriptor" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'statement_descriptor'::"text")) STORED,
    "unit_label" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'unit_label'::"text")) STORED,
    "updated" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'updated'::"text"))::integer) STORED,
    "url" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'url'::"text")) STORED,
    "active" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'active'::"text"))::boolean) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "description" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'description'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL,
    "name" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'name'::"text")) STORED
);


ALTER TABLE "stripe"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."refunds" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "balance_transaction" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'balance_transaction'::"text")) STORED,
    "charge" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'charge'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "currency" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'currency'::"text")) STORED,
    "destination_details" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'destination_details'::"text")) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "payment_intent" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_intent'::"text")) STORED,
    "reason" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'reason'::"text")) STORED,
    "receipt_number" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'receipt_number'::"text")) STORED,
    "source_transfer_reversal" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'source_transfer_reversal'::"text")) STORED,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED,
    "transfer_reversal" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'transfer_reversal'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL,
    "amount" bigint GENERATED ALWAYS AS ((("_raw_data" ->> 'amount'::"text"))::bigint) STORED
);


ALTER TABLE "stripe"."refunds" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."reviews" (
    "_updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "billing_zip" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'billing_zip'::"text")) STORED,
    "charge" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'charge'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "closed_reason" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'closed_reason'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "ip_address" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'ip_address'::"text")) STORED,
    "ip_address_location" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'ip_address_location'::"text")) STORED,
    "open" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'open'::"text"))::boolean) STORED,
    "opened_reason" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'opened_reason'::"text")) STORED,
    "payment_intent" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_intent'::"text")) STORED,
    "reason" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'reason'::"text")) STORED,
    "session" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'session'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."setup_intents" (
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "description" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'description'::"text")) STORED,
    "payment_method" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'payment_method'::"text")) STORED,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED,
    "usage" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'usage'::"text")) STORED,
    "cancellation_reason" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'cancellation_reason'::"text")) STORED,
    "latest_attempt" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'latest_attempt'::"text")) STORED,
    "mandate" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'mandate'::"text")) STORED,
    "single_use_mandate" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'single_use_mandate'::"text")) STORED,
    "on_behalf_of" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'on_behalf_of'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."setup_intents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."subscription_item_change_events_v2_beta" (
    "_raw_data" "jsonb" NOT NULL,
    "_last_synced_at" timestamp with time zone,
    "_updated_at" timestamp with time zone DEFAULT "now"(),
    "_account_id" "text" NOT NULL,
    "event_timestamp" timestamp with time zone NOT NULL,
    "event_type" "text" NOT NULL,
    "subscription_item_id" "text" NOT NULL,
    "currency" "text" GENERATED ALWAYS AS (NULLIF(("_raw_data" ->> 'currency'::"text"), ''::"text")) STORED,
    "mrr_change" bigint GENERATED ALWAYS AS ((NULLIF(("_raw_data" ->> 'mrr_change'::"text"), ''::"text"))::bigint) STORED,
    "quantity_change" bigint GENERATED ALWAYS AS ((NULLIF(("_raw_data" ->> 'quantity_change'::"text"), ''::"text"))::bigint) STORED,
    "subscription_id" "text" GENERATED ALWAYS AS (NULLIF(("_raw_data" ->> 'subscription_id'::"text"), ''::"text")) STORED,
    "customer_id" "text" GENERATED ALWAYS AS (NULLIF(("_raw_data" ->> 'customer_id'::"text"), ''::"text")) STORED,
    "price_id" "text" GENERATED ALWAYS AS (NULLIF(("_raw_data" ->> 'price_id'::"text"), ''::"text")) STORED,
    "product_id" "text" GENERATED ALWAYS AS (NULLIF(("_raw_data" ->> 'product_id'::"text"), ''::"text")) STORED,
    "local_event_timestamp" "text" GENERATED ALWAYS AS (NULLIF(("_raw_data" ->> 'local_event_timestamp'::"text"), ''::"text")) STORED
);


ALTER TABLE "stripe"."subscription_item_change_events_v2_beta" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."subscription_items" (
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "billing_thresholds" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'billing_thresholds'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "deleted" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'deleted'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "quantity" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'quantity'::"text"))::integer) STORED,
    "price" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'price'::"text")) STORED,
    "subscription" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'subscription'::"text")) STORED,
    "tax_rates" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'tax_rates'::"text")) STORED,
    "current_period_end" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'current_period_end'::"text"))::integer) STORED,
    "current_period_start" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'current_period_start'::"text"))::integer) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."subscription_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."subscription_schedules" (
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "application" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'application'::"text")) STORED,
    "canceled_at" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'canceled_at'::"text"))::integer) STORED,
    "completed_at" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'completed_at'::"text"))::integer) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "current_phase" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'current_phase'::"text")) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "default_settings" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'default_settings'::"text")) STORED,
    "end_behavior" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'end_behavior'::"text")) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "metadata" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'metadata'::"text")) STORED,
    "phases" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'phases'::"text")) STORED,
    "released_at" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'released_at'::"text"))::integer) STORED,
    "released_subscription" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'released_subscription'::"text")) STORED,
    "status" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'status'::"text")) STORED,
    "subscription" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'subscription'::"text")) STORED,
    "test_clock" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'test_clock'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."subscription_schedules" OWNER TO "postgres";


CREATE OR REPLACE VIEW "stripe"."sync_runs" AS
 SELECT "r"."_account_id" AS "account_id",
    "r"."started_at",
    "r"."closed_at",
    "r"."triggered_by",
    "r"."max_concurrent",
    COALESCE("sum"("o"."processed_count"), (0)::bigint) AS "total_processed",
    "count"("o".*) AS "total_objects",
    "count"(*) FILTER (WHERE ("o"."status" = 'complete'::"text")) AS "complete_count",
    "count"(*) FILTER (WHERE ("o"."status" = 'error'::"text")) AS "error_count",
    "count"(*) FILTER (WHERE ("o"."status" = 'running'::"text")) AS "running_count",
    "count"(*) FILTER (WHERE ("o"."status" = 'pending'::"text")) AS "pending_count",
    "string_agg"("o"."error_message", '; '::"text") FILTER (WHERE ("o"."error_message" IS NOT NULL)) AS "error_message",
        CASE
            WHEN (("r"."closed_at" IS NULL) AND ("count"(*) FILTER (WHERE ("o"."status" = 'running'::"text")) > 0)) THEN 'running'::"text"
            WHEN (("r"."closed_at" IS NULL) AND (("count"("o".*) = 0) OR ("count"("o".*) = "count"(*) FILTER (WHERE ("o"."status" = 'pending'::"text"))))) THEN 'pending'::"text"
            WHEN ("r"."closed_at" IS NULL) THEN 'running'::"text"
            WHEN ("count"(*) FILTER (WHERE ("o"."status" = 'error'::"text")) > 0) THEN 'error'::"text"
            ELSE 'complete'::"text"
        END AS "status"
   FROM ("stripe"."_sync_runs" "r"
     LEFT JOIN "stripe"."_sync_obj_runs" "o" ON ((("o"."_account_id" = "r"."_account_id") AND ("o"."run_started_at" = "r"."started_at"))))
  GROUP BY "r"."_account_id", "r"."started_at", "r"."closed_at", "r"."triggered_by", "r"."max_concurrent";


ALTER VIEW "stripe"."sync_runs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "stripe"."tax_ids" (
    "_last_synced_at" timestamp with time zone,
    "_raw_data" "jsonb",
    "_account_id" "text" NOT NULL,
    "object" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'object'::"text")) STORED,
    "country" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'country'::"text")) STORED,
    "customer" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'customer'::"text")) STORED,
    "type" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'type'::"text")) STORED,
    "value" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'value'::"text")) STORED,
    "created" integer GENERATED ALWAYS AS ((("_raw_data" ->> 'created'::"text"))::integer) STORED,
    "livemode" boolean GENERATED ALWAYS AS ((("_raw_data" ->> 'livemode'::"text"))::boolean) STORED,
    "owner" "jsonb" GENERATED ALWAYS AS (("_raw_data" -> 'owner'::"text")) STORED,
    "id" "text" GENERATED ALWAYS AS (("_raw_data" ->> 'id'::"text")) STORED NOT NULL
);


ALTER TABLE "stripe"."tax_ids" OWNER TO "postgres";


ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("category_id");



ALTER TABLE ONLY "public"."components"
    ADD CONSTRAINT "ingredients_pkey" PRIMARY KEY ("component_id");



ALTER TABLE ONLY "public"."kitchen_invites"
    ADD CONSTRAINT "kitchen_invites_invite_code_key" UNIQUE ("invite_code");



ALTER TABLE ONLY "public"."kitchen_invites"
    ADD CONSTRAINT "kitchen_invites_pkey" PRIMARY KEY ("invite_id");



ALTER TABLE ONLY "public"."kitchen"
    ADD CONSTRAINT "kitchen_pkey" PRIMARY KEY ("kitchen_id");



ALTER TABLE ONLY "public"."kitchen_users"
    ADD CONSTRAINT "kitchen_users_pkey" PRIMARY KEY ("kitchen_id", "user_id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "menu_section_name_kitchen_id_unique" UNIQUE ("name", "kitchen_id");



ALTER TABLE ONLY "public"."recipe_components"
    ADD CONSTRAINT "recipe_components_pkey" PRIMARY KEY ("recipe_id", "component_id");



ALTER TABLE ONLY "public"."recipes"
    ADD CONSTRAINT "recipe_pkey" PRIMARY KEY ("recipe_id");



ALTER TABLE ONLY "public"."recipes"
    ADD CONSTRAINT "recipes_name_kitchen_id_unique" UNIQUE ("recipe_name", "kitchen_id");



ALTER TABLE ONLY "public"."stripe_customer_links"
    ADD CONSTRAINT "stripe_customer_links_kitchen_id_key" UNIQUE ("kitchen_id");



ALTER TABLE ONLY "public"."stripe_customer_links"
    ADD CONSTRAINT "stripe_customer_links_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."components"
    ADD CONSTRAINT "unique_kitchen_ingredient_name" UNIQUE ("name", "kitchen_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "stripe"."_migrations"
    ADD CONSTRAINT "_migrations_name_key" UNIQUE ("name");



ALTER TABLE ONLY "stripe"."_migrations"
    ADD CONSTRAINT "_migrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."_sync_obj_runs"
    ADD CONSTRAINT "_sync_obj_run_pkey" PRIMARY KEY ("_account_id", "run_started_at", "object");



ALTER TABLE ONLY "stripe"."_sync_runs"
    ADD CONSTRAINT "_sync_run_pkey" PRIMARY KEY ("_account_id", "started_at");



ALTER TABLE ONLY "stripe"."accounts"
    ADD CONSTRAINT "accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."active_entitlements"
    ADD CONSTRAINT "active_entitlements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."charges"
    ADD CONSTRAINT "charges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."checkout_session_line_items"
    ADD CONSTRAINT "checkout_session_line_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."checkout_sessions"
    ADD CONSTRAINT "checkout_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."coupons"
    ADD CONSTRAINT "coupons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."credit_notes"
    ADD CONSTRAINT "credit_notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."disputes"
    ADD CONSTRAINT "disputes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."early_fraud_warnings"
    ADD CONSTRAINT "early_fraud_warnings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."exchange_rates_from_usd"
    ADD CONSTRAINT "exchange_rates_from_usd_pkey" PRIMARY KEY ("_account_id", "date", "sell_currency");



ALTER TABLE ONLY "stripe"."features"
    ADD CONSTRAINT "features_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."invoices"
    ADD CONSTRAINT "invoices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."_managed_webhooks"
    ADD CONSTRAINT "managed_webhooks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."_managed_webhooks"
    ADD CONSTRAINT "managed_webhooks_url_account_unique" UNIQUE ("url", "account_id");



ALTER TABLE ONLY "stripe"."_sync_runs"
    ADD CONSTRAINT "one_active_run_per_account" EXCLUDE USING "btree" ("_account_id" WITH =) WHERE (("closed_at" IS NULL));



ALTER TABLE ONLY "stripe"."payment_intents"
    ADD CONSTRAINT "payment_intents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."payment_methods"
    ADD CONSTRAINT "payment_methods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."payouts"
    ADD CONSTRAINT "payouts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."plans"
    ADD CONSTRAINT "plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."prices"
    ADD CONSTRAINT "prices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."refunds"
    ADD CONSTRAINT "refunds_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."setup_intents"
    ADD CONSTRAINT "setup_intents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."subscription_item_change_events_v2_beta"
    ADD CONSTRAINT "subscription_item_change_events_v2_beta_pkey" PRIMARY KEY ("_account_id", "event_timestamp", "event_type", "subscription_item_id");



ALTER TABLE ONLY "stripe"."subscription_items"
    ADD CONSTRAINT "subscription_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."subscription_schedules"
    ADD CONSTRAINT "subscription_schedules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "stripe"."tax_ids"
    ADD CONSTRAINT "tax_ids_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_categories_kitchen_id" ON "public"."categories" USING "btree" ("kitchen_id");



CREATE INDEX "idx_components_kitchen_id" ON "public"."components" USING "btree" ("kitchen_id");



CREATE INDEX "idx_components_kitchen_lowername" ON "public"."components" USING "btree" ("kitchen_id", "lower"("btrim"("name"))) WHERE ("component_type" = 'Raw_Ingredient'::"public"."component_type");



CREATE INDEX "idx_components_name_trgm_unicode" ON "public"."components" USING "gin" ("lower"("btrim"("name")) "extensions"."gin_trgm_ops") WHERE ("component_type" = 'Raw_Ingredient'::"public"."component_type");



CREATE INDEX "idx_components_recipe_id" ON "public"."components" USING "btree" ("recipe_id");



CREATE UNIQUE INDEX "idx_components_unique_prep_recipe" ON "public"."components" USING "btree" ("recipe_id") WHERE ("component_type" = 'Preparation'::"public"."component_type");



CREATE INDEX "idx_kitchen_invites_created_by" ON "public"."kitchen_invites" USING "btree" ("created_by");



CREATE INDEX "idx_kitchen_invites_invite_code" ON "public"."kitchen_invites" USING "btree" ("invite_code");



CREATE INDEX "idx_kitchen_invites_kitchen_id" ON "public"."kitchen_invites" USING "btree" ("kitchen_id");



CREATE INDEX "idx_kitchen_owner_user_id" ON "public"."kitchen" USING "btree" ("owner_user_id");



CREATE INDEX "idx_kitchen_users_kitchen_id" ON "public"."kitchen_users" USING "btree" ("kitchen_id");



CREATE INDEX "idx_kitchen_users_user_id" ON "public"."kitchen_users" USING "btree" ("user_id");



CREATE INDEX "idx_recipe_components_component_id" ON "public"."recipe_components" USING "btree" ("component_id");



CREATE INDEX "idx_recipe_components_recipe_id" ON "public"."recipe_components" USING "btree" ("recipe_id");



CREATE INDEX "idx_recipes_category_id" ON "public"."recipes" USING "btree" ("category_id");



CREATE INDEX "idx_recipes_fingerprint" ON "public"."recipes" USING "btree" ("fingerprint");



CREATE INDEX "idx_recipes_fingerprint_plain_trgm" ON "public"."recipes" USING "gin" ("fingerprint_plain" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_recipes_kitchen_id" ON "public"."recipes" USING "btree" ("kitchen_id");



CREATE INDEX "idx_stripe_customer_links_customer" ON "public"."stripe_customer_links" USING "btree" ("stripe_customer_id");



CREATE INDEX "idx_stripe_customer_links_kitchen" ON "public"."stripe_customer_links" USING "btree" ("kitchen_id");



CREATE INDEX "idx_stripe_customer_links_user" ON "public"."stripe_customer_links" USING "btree" ("user_id");



CREATE INDEX "recipe_components_unique_idx" ON "public"."recipe_components" USING "btree" ("recipe_id", "component_id");



CREATE INDEX "recipe_name_trgm_idx" ON "public"."recipes" USING "gin" ("lower"("recipe_name") "extensions"."gin_trgm_ops");



CREATE UNIQUE INDEX "unique_personal_kitchen_name" ON "public"."kitchen" USING "btree" ("name") WHERE ("type" = 'Personal'::"public"."KitchenType");



CREATE UNIQUE INDEX "active_entitlements_lookup_key_key" ON "stripe"."active_entitlements" USING "btree" ("lookup_key") WHERE ("lookup_key" IS NOT NULL);



CREATE UNIQUE INDEX "features_lookup_key_key" ON "stripe"."features" USING "btree" ("lookup_key") WHERE ("lookup_key" IS NOT NULL);



CREATE INDEX "idx_accounts_api_key_hashes" ON "stripe"."accounts" USING "gin" ("api_key_hashes");



CREATE INDEX "idx_accounts_business_name" ON "stripe"."accounts" USING "btree" ("business_name");



CREATE INDEX "idx_exchange_rates_from_usd_date" ON "stripe"."exchange_rates_from_usd" USING "btree" ("date");



CREATE INDEX "idx_exchange_rates_from_usd_sell_currency" ON "stripe"."exchange_rates_from_usd" USING "btree" ("sell_currency");



CREATE INDEX "idx_sync_obj_runs_status" ON "stripe"."_sync_obj_runs" USING "btree" ("_account_id", "run_started_at", "status");



CREATE INDEX "idx_sync_runs_account_status" ON "stripe"."_sync_runs" USING "btree" ("_account_id", "closed_at");



CREATE INDEX "stripe_active_entitlements_customer_idx" ON "stripe"."active_entitlements" USING "btree" ("customer");



CREATE INDEX "stripe_active_entitlements_feature_idx" ON "stripe"."active_entitlements" USING "btree" ("feature");



CREATE INDEX "stripe_checkout_session_line_items_price_idx" ON "stripe"."checkout_session_line_items" USING "btree" ("price");



CREATE INDEX "stripe_checkout_session_line_items_session_idx" ON "stripe"."checkout_session_line_items" USING "btree" ("checkout_session");



CREATE INDEX "stripe_checkout_sessions_customer_idx" ON "stripe"."checkout_sessions" USING "btree" ("customer");



CREATE INDEX "stripe_checkout_sessions_invoice_idx" ON "stripe"."checkout_sessions" USING "btree" ("invoice");



CREATE INDEX "stripe_checkout_sessions_payment_intent_idx" ON "stripe"."checkout_sessions" USING "btree" ("payment_intent");



CREATE INDEX "stripe_checkout_sessions_subscription_idx" ON "stripe"."checkout_sessions" USING "btree" ("subscription");



CREATE INDEX "stripe_credit_notes_customer_idx" ON "stripe"."credit_notes" USING "btree" ("customer");



CREATE INDEX "stripe_credit_notes_invoice_idx" ON "stripe"."credit_notes" USING "btree" ("invoice");



CREATE INDEX "stripe_dispute_created_idx" ON "stripe"."disputes" USING "btree" ("created");



CREATE INDEX "stripe_early_fraud_warnings_charge_idx" ON "stripe"."early_fraud_warnings" USING "btree" ("charge");



CREATE INDEX "stripe_early_fraud_warnings_payment_intent_idx" ON "stripe"."early_fraud_warnings" USING "btree" ("payment_intent");



CREATE INDEX "stripe_invoices_customer_idx" ON "stripe"."invoices" USING "btree" ("customer");



CREATE INDEX "stripe_invoices_subscription_idx" ON "stripe"."invoices" USING "btree" ("subscription");



CREATE INDEX "stripe_managed_webhooks_enabled_idx" ON "stripe"."_managed_webhooks" USING "btree" ("enabled");



CREATE INDEX "stripe_managed_webhooks_status_idx" ON "stripe"."_managed_webhooks" USING "btree" ("status");



CREATE INDEX "stripe_payment_intents_customer_idx" ON "stripe"."payment_intents" USING "btree" ("customer");



CREATE INDEX "stripe_payment_intents_invoice_idx" ON "stripe"."payment_intents" USING "btree" ("invoice");



CREATE INDEX "stripe_payment_methods_customer_idx" ON "stripe"."payment_methods" USING "btree" ("customer");



CREATE INDEX "stripe_refunds_charge_idx" ON "stripe"."refunds" USING "btree" ("charge");



CREATE INDEX "stripe_refunds_payment_intent_idx" ON "stripe"."refunds" USING "btree" ("payment_intent");



CREATE INDEX "stripe_reviews_charge_idx" ON "stripe"."reviews" USING "btree" ("charge");



CREATE INDEX "stripe_reviews_payment_intent_idx" ON "stripe"."reviews" USING "btree" ("payment_intent");



CREATE INDEX "stripe_setup_intents_customer_idx" ON "stripe"."setup_intents" USING "btree" ("customer");



CREATE INDEX "stripe_tax_ids_customer_idx" ON "stripe"."tax_ids" USING "btree" ("customer");



CREATE OR REPLACE TRIGGER "kitchen-stripe-sync" AFTER DELETE OR UPDATE ON "public"."kitchen" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://roa-api-prod-515418725737.us-central1.run.app/subscriptions/sync-kitchen-to-stripe', 'POST', '{"Content-type":"application/json","X-Supabase-Webhook-Secret":"roa-webhook-secret-130402"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "prevent_owner_leave_trigger" BEFORE DELETE ON "public"."kitchen_users" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_owner_leave"();



CREATE OR REPLACE TRIGGER "recipe-images" AFTER DELETE OR UPDATE ON "public"."recipes" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://roa-api-515418725737.us-central1.run.app/webhook', 'POST', '{"Content-type":"application/json","X-Supabase-Signature":"roa-webhook-secret-130402"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "stripe_customer_links_updated_at" BEFORE UPDATE ON "public"."stripe_customer_links" FOR EACH ROW EXECUTE FUNCTION "public"."update_stripe_customer_links_updated_at"();



CREATE OR REPLACE TRIGGER "tg_recipe_components_update_fingerprint" AFTER INSERT OR DELETE OR UPDATE ON "public"."recipe_components" FOR EACH ROW EXECUTE FUNCTION "public"."tg_components_update_fingerprint"();



CREATE CONSTRAINT TRIGGER "trg_components_enforce_recipe_pairing" AFTER INSERT OR UPDATE OF "component_type", "recipe_id" ON "public"."components" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."components_enforce_recipe_pairing"();



CREATE CONSTRAINT TRIGGER "trg_components_match_name_kitchen" AFTER INSERT OR UPDATE OF "name", "kitchen_id", "component_type", "recipe_id" ON "public"."components" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."enforce_prep_name_kitchen_match_from_components"();



CREATE OR REPLACE TRIGGER "trg_enforce_one_user_per_personal_kitchen" BEFORE INSERT ON "public"."kitchen_users" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_one_user_per_personal_kitchen"();



CREATE OR REPLACE TRIGGER "trg_prevent_prep_cycle" BEFORE INSERT OR UPDATE ON "public"."recipe_components" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_preparation_cycle"();



CREATE OR REPLACE TRIGGER "trg_rc_prep_unit_guard" BEFORE INSERT OR UPDATE ON "public"."recipe_components" FOR EACH ROW EXECUTE FUNCTION "public"."rc_prep_unit_guard"();



CREATE OR REPLACE TRIGGER "trg_recalculate_parent_amounts_on_yield_change" BEFORE UPDATE OF "serving_or_yield_unit", "serving_or_yield_amount" ON "public"."recipes" FOR EACH ROW WHEN ((("old"."serving_or_yield_unit" IS DISTINCT FROM "new"."serving_or_yield_unit") OR ("old"."serving_or_yield_amount" IS DISTINCT FROM "new"."serving_or_yield_amount"))) EXECUTE FUNCTION "public"."recalculate_parent_amounts_on_yield_change"();



CREATE OR REPLACE TRIGGER "trg_recipe_components_item_unit" BEFORE INSERT OR UPDATE ON "public"."recipe_components" FOR EACH ROW EXECUTE FUNCTION "public"."recipe_components_item_unit_guard"();



CREATE OR REPLACE TRIGGER "trg_recipe_components_update_fingerprint" AFTER INSERT OR DELETE OR UPDATE ON "public"."recipe_components" FOR EACH ROW EXECUTE FUNCTION "public"."tg_recipe_components_update_fingerprint"();



CREATE CONSTRAINT TRIGGER "trg_recipes_enforce_component_pairing" AFTER INSERT OR UPDATE OF "recipe_type" ON "public"."recipes" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."recipes_enforce_component_pairing"();



CREATE CONSTRAINT TRIGGER "trg_recipes_match_name_kitchen" AFTER INSERT OR UPDATE OF "recipe_name", "kitchen_id", "recipe_type" ON "public"."recipes" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."enforce_prep_name_kitchen_match_from_recipes"();



CREATE OR REPLACE TRIGGER "trg_recipes_set_fingerprint" AFTER INSERT OR UPDATE OF "directions" ON "public"."recipes" FOR EACH ROW EXECUTE FUNCTION "public"."tg_recipes_set_fingerprint"();



CREATE CONSTRAINT TRIGGER "verify_owner_membership_trigger" AFTER INSERT OR UPDATE OF "owner_user_id" ON "public"."kitchen" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."verify_kitchen_owner_is_member"();



COMMENT ON TRIGGER "verify_owner_membership_trigger" ON "public"."kitchen" IS 'Enforces that kitchen owner must be a member of the kitchen (deferred to end of transaction)';



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."_managed_webhooks" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at_metadata"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."_sync_obj_runs" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at_metadata"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."_sync_runs" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at_metadata"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."accounts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."active_entitlements" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."charges" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."checkout_session_line_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."checkout_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."coupons" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."customers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."disputes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."early_fraud_warnings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."events" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."exchange_rates_from_usd" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."features" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."invoices" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."payouts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."plans" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."prices" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."products" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."refunds" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."subscription_item_change_events_v2_beta" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "stripe"."subscriptions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



ALTER TABLE ONLY "public"."components"
    ADD CONSTRAINT "components_recipe_id_fk" FOREIGN KEY ("recipe_id") REFERENCES "public"."recipes"("recipe_id") ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;



ALTER TABLE ONLY "public"."recipes"
    ADD CONSTRAINT "dishes_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."components"
    ADD CONSTRAINT "ingredients_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kitchen_invites"
    ADD CONSTRAINT "kitchen_invites_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kitchen_invites"
    ADD CONSTRAINT "kitchen_invites_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kitchen"
    ADD CONSTRAINT "kitchen_owner_user_id_fkey" FOREIGN KEY ("owner_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."kitchen_users"
    ADD CONSTRAINT "kitchen_users_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kitchen_users"
    ADD CONSTRAINT "kitchen_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "menu_section_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."recipes"
    ADD CONSTRAINT "recipe_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("category_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."recipe_components"
    ADD CONSTRAINT "recipe_components_component_id_fkey" FOREIGN KEY ("component_id") REFERENCES "public"."components"("component_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."recipe_components"
    ADD CONSTRAINT "recipe_components_recipe_id_fkey" FOREIGN KEY ("recipe_id") REFERENCES "public"."recipes"("recipe_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stripe_customer_links"
    ADD CONSTRAINT "stripe_customer_links_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stripe_customer_links"
    ADD CONSTRAINT "stripe_customer_links_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "stripe"."active_entitlements"
    ADD CONSTRAINT "fk_active_entitlements_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."charges"
    ADD CONSTRAINT "fk_charges_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."checkout_session_line_items"
    ADD CONSTRAINT "fk_checkout_session_line_items_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."checkout_sessions"
    ADD CONSTRAINT "fk_checkout_sessions_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."credit_notes"
    ADD CONSTRAINT "fk_credit_notes_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."customers"
    ADD CONSTRAINT "fk_customers_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."disputes"
    ADD CONSTRAINT "fk_disputes_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."early_fraud_warnings"
    ADD CONSTRAINT "fk_early_fraud_warnings_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."exchange_rates_from_usd"
    ADD CONSTRAINT "fk_exchange_rates_from_usd_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."features"
    ADD CONSTRAINT "fk_features_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."invoices"
    ADD CONSTRAINT "fk_invoices_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."_managed_webhooks"
    ADD CONSTRAINT "fk_managed_webhooks_account" FOREIGN KEY ("account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."payment_intents"
    ADD CONSTRAINT "fk_payment_intents_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."payment_methods"
    ADD CONSTRAINT "fk_payment_methods_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."plans"
    ADD CONSTRAINT "fk_plans_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."prices"
    ADD CONSTRAINT "fk_prices_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."products"
    ADD CONSTRAINT "fk_products_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."refunds"
    ADD CONSTRAINT "fk_refunds_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."reviews"
    ADD CONSTRAINT "fk_reviews_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."setup_intents"
    ADD CONSTRAINT "fk_setup_intents_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."subscription_item_change_events_v2_beta"
    ADD CONSTRAINT "fk_subscription_item_change_events_v2_beta_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."subscription_items"
    ADD CONSTRAINT "fk_subscription_items_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."subscription_schedules"
    ADD CONSTRAINT "fk_subscription_schedules_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."subscriptions"
    ADD CONSTRAINT "fk_subscriptions_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."_sync_obj_runs"
    ADD CONSTRAINT "fk_sync_obj_runs_parent" FOREIGN KEY ("_account_id", "run_started_at") REFERENCES "stripe"."_sync_runs"("_account_id", "started_at");



ALTER TABLE ONLY "stripe"."_sync_runs"
    ADD CONSTRAINT "fk_sync_run_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



ALTER TABLE ONLY "stripe"."tax_ids"
    ADD CONSTRAINT "fk_tax_ids_account" FOREIGN KEY ("_account_id") REFERENCES "stripe"."accounts"("id");



CREATE POLICY "Admins can update kitchen names" ON "public"."kitchen" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."is_admin" = true) AND ("ku"."kitchen_id" = "kitchen"."kitchen_id")))));



CREATE POLICY "Allow admin to add users to their kitchen" ON "public"."kitchen_users" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_user_kitchen_admin"(( SELECT "auth"."uid"() AS "uid"), "kitchen_id"));



CREATE POLICY "Allow authenticated users to insert kitchens" ON "public"."kitchen" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to select their kitchens" ON "public"."kitchen" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."kitchen_id" = "kitchen"."kitchen_id") AND ("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Allow users to see all members in their kitchens" ON "public"."kitchen_users" FOR SELECT TO "authenticated" USING ("public"."is_user_kitchen_member"(( SELECT "auth"."uid"() AS "uid"), "kitchen_id"));



CREATE POLICY "Enable delete access for the user based on their id" ON "public"."users" FOR DELETE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Enable insert access for authenticated users" ON "public"."users" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Enable read access for all users" ON "public"."users" FOR SELECT USING (true);



CREATE POLICY "Enable update access for the user based on their id" ON "public"."users" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Enable update for kitchen admins or self (safeguarded against n" ON "public"."kitchen_users" FOR UPDATE TO "authenticated" USING (("public"."is_user_kitchen_admin"(( SELECT "auth"."uid"() AS "uid"), "kitchen_id") OR ("user_id" = ( SELECT "auth"."uid"() AS "uid")))) WITH CHECK (("public"."count_kitchen_admins"("kitchen_id") >= 1));



CREATE POLICY "Kitchen admins can create invites for their kitchens" ON "public"."kitchen_invites" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_user_kitchen_admin"(( SELECT "auth"."uid"() AS "uid"), "kitchen_id"));



CREATE POLICY "Kitchen admins can update invites for their kitchens" ON "public"."kitchen_invites" FOR UPDATE TO "authenticated" USING ("public"."is_user_kitchen_admin"(( SELECT "auth"."uid"() AS "uid"), "kitchen_id")) WITH CHECK ("public"."is_user_kitchen_admin"(( SELECT "auth"."uid"() AS "uid"), "kitchen_id"));



CREATE POLICY "Kitchen admins can view invites for their kitchens" ON "public"."kitchen_invites" FOR SELECT TO "authenticated" USING ("public"."is_user_kitchen_admin"(( SELECT "auth"."uid"() AS "uid"), "kitchen_id"));



CREATE POLICY "Parser service can read all recipe components" ON "public"."recipe_components" FOR SELECT TO "service_role" USING (true);



CREATE POLICY "Parser service can read all recipes" ON "public"."recipes" FOR SELECT TO "service_role" USING (true);



CREATE POLICY "Users can view customer links for their kitchens" ON "public"."stripe_customer_links" FOR SELECT TO "authenticated" USING (("kitchen_id" IN ( SELECT "ku"."kitchen_id"
   FROM "public"."kitchen_users" "ku"
  WHERE ("ku"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view their own customer links" ON "public"."stripe_customer_links" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "categories_delete" ON "public"."categories" FOR DELETE USING (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "categories"."kitchen_id"))))));



CREATE POLICY "categories_insert" ON "public"."categories" FOR INSERT WITH CHECK (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "categories"."kitchen_id"))))));



CREATE POLICY "categories_select" ON "public"."categories" FOR SELECT USING (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "categories"."kitchen_id"))))));



CREATE POLICY "categories_update" ON "public"."categories" FOR UPDATE USING (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "categories"."kitchen_id")))))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "categories"."kitchen_id"))))));



ALTER TABLE "public"."components" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "components_delete" ON "public"."components" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "components"."kitchen_id"))))));



CREATE POLICY "components_insert" ON "public"."components" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "components"."kitchen_id"))))));



CREATE POLICY "components_select" ON "public"."components" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "components"."kitchen_id"))))));



CREATE POLICY "components_update" ON "public"."components" FOR UPDATE TO "authenticated" USING ("public"."is_user_kitchen_member"(( SELECT "auth"."uid"() AS "uid"), "kitchen_id")) WITH CHECK ("public"."is_user_kitchen_member"(( SELECT "auth"."uid"() AS "uid"), "kitchen_id"));



ALTER TABLE "public"."kitchen" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kitchen_invites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kitchen_users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "kitchen_users_delete_authenticated" ON "public"."kitchen_users" FOR DELETE TO "authenticated" USING (((("user_id" = ( SELECT "auth"."uid"() AS "uid")) AND (NOT (("is_admin" = true) AND ("public"."count_kitchen_admins"("kitchen_id") = 1)))) OR "public"."is_user_kitchen_admin"(( SELECT "auth"."uid"() AS "uid"), "kitchen_id")));



ALTER TABLE "public"."recipe_components" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "recipe_components_delete" ON "public"."recipe_components" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."recipes" "r"
  WHERE (("r"."recipe_id" = "recipe_components"."recipe_id") AND "public"."is_user_kitchen_member"("auth"."uid"(), "r"."kitchen_id")))));



CREATE POLICY "recipe_components_insert" ON "public"."recipe_components" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."recipes" "r"
  WHERE (("r"."recipe_id" = "recipe_components"."recipe_id") AND "public"."is_user_kitchen_member"("auth"."uid"(), "r"."kitchen_id")))));



CREATE POLICY "recipe_components_select" ON "public"."recipe_components" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."recipes" "r"
  WHERE (("r"."recipe_id" = "recipe_components"."recipe_id") AND "public"."is_user_kitchen_member"("auth"."uid"(), "r"."kitchen_id")))));



CREATE POLICY "recipe_components_update" ON "public"."recipe_components" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."recipes" "r"
  WHERE (("r"."recipe_id" = "recipe_components"."recipe_id") AND "public"."is_user_kitchen_member"("auth"."uid"(), "r"."kitchen_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."recipes" "r"
  WHERE (("r"."recipe_id" = "recipe_components"."recipe_id") AND "public"."is_user_kitchen_member"("auth"."uid"(), "r"."kitchen_id")))));



ALTER TABLE "public"."recipes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "recipes_delete" ON "public"."recipes" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "recipes"."kitchen_id"))))));



CREATE POLICY "recipes_insert" ON "public"."recipes" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "recipes"."kitchen_id"))))));



CREATE POLICY "recipes_select" ON "public"."recipes" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "recipes"."kitchen_id"))))));



CREATE POLICY "recipes_update" ON "public"."recipes" FOR UPDATE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "recipes"."kitchen_id")))))) WITH CHECK (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("ku"."kitchen_id" = "recipes"."kitchen_id"))))));



ALTER TABLE "public"."stripe_customer_links" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


SET SESSION AUTHORIZATION "postgres";
RESET SESSION AUTHORIZATION;






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";













































































































































































































































































































































































































































































































































GRANT ALL ON FUNCTION "public"."components_enforce_recipe_pairing"() TO "anon";
GRANT ALL ON FUNCTION "public"."components_enforce_recipe_pairing"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."components_enforce_recipe_pairing"() TO "service_role";



GRANT ALL ON FUNCTION "public"."convert_amount_safe"("amount_val" numeric, "from_unit" "public"."unit", "to_unit" "public"."unit") TO "anon";
GRANT ALL ON FUNCTION "public"."convert_amount_safe"("amount_val" numeric, "from_unit" "public"."unit", "to_unit" "public"."unit") TO "authenticated";
GRANT ALL ON FUNCTION "public"."convert_amount_safe"("amount_val" numeric, "from_unit" "public"."unit", "to_unit" "public"."unit") TO "service_role";



GRANT ALL ON FUNCTION "public"."count_kitchen_admins"("p_kitchen_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."count_kitchen_admins"("p_kitchen_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."count_kitchen_admins"("p_kitchen_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_free_team_kitchen"("p_user_id" "uuid", "p_team_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_free_team_kitchen"("p_user_id" "uuid", "p_team_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_free_team_kitchen"("p_user_id" "uuid", "p_team_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_preparation_with_component"("_kitchen" "uuid", "_name" "text", "_category" "uuid", "_directions" "text"[], "_time" interval, "_cooking_notes" "text", "_yield_unit" "public"."unit", "_yield_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."create_preparation_with_component"("_kitchen" "uuid", "_name" "text", "_category" "uuid", "_directions" "text"[], "_time" interval, "_cooking_notes" "text", "_yield_unit" "public"."unit", "_yield_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_preparation_with_component"("_kitchen" "uuid", "_name" "text", "_category" "uuid", "_directions" "text"[], "_time" interval, "_cooking_notes" "text", "_yield_unit" "public"."unit", "_yield_amount" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_expired_kitchen_invites"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_expired_kitchen_invites"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_expired_kitchen_invites"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_recipe"("_recipe_id" "uuid", "_kitchen_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_recipe"("_recipe_id" "uuid", "_kitchen_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_recipe"("_recipe_id" "uuid", "_kitchen_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_one_user_per_personal_kitchen"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_one_user_per_personal_kitchen"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_one_user_per_personal_kitchen"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_prep_name_kitchen_match_from_components"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_prep_name_kitchen_match_from_components"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_prep_name_kitchen_match_from_components"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_prep_name_kitchen_match_from_recipes"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_prep_name_kitchen_match_from_recipes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_prep_name_kitchen_match_from_recipes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."find_by_fingerprints"("_fps" "uuid"[], "_kitchen" "uuid", "_only_preparations" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."find_by_fingerprints"("_fps" "uuid"[], "_kitchen" "uuid", "_only_preparations" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_by_fingerprints"("_fps" "uuid"[], "_kitchen" "uuid", "_only_preparations" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_by_plain"("_names" "text"[], "_kitchen" "uuid", "_threshold" real, "_only_preparations" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."find_by_plain"("_names" "text"[], "_kitchen" "uuid", "_threshold" real, "_only_preparations" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_by_plain"("_names" "text"[], "_kitchen" "uuid", "_threshold" real, "_only_preparations" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_ingredients_by_name_exact"("_names" "text"[], "_kitchen" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."find_ingredients_by_name_exact"("_names" "text"[], "_kitchen" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_ingredients_by_name_exact"("_names" "text"[], "_kitchen" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."find_ingredients_by_name_fuzzy"("_names" "text"[], "_kitchen" "uuid", "_threshold" real) TO "anon";
GRANT ALL ON FUNCTION "public"."find_ingredients_by_name_fuzzy"("_names" "text"[], "_kitchen" "uuid", "_threshold" real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_ingredients_by_name_fuzzy"("_names" "text"[], "_kitchen" "uuid", "_threshold" real) TO "service_role";



GRANT ALL ON FUNCTION "public"."fp_namespace"() TO "anon";
GRANT ALL ON FUNCTION "public"."fp_namespace"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fp_namespace"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_components_for_recipes"("_recipe_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_components_for_recipes"("_recipe_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_components_for_recipes"("_recipe_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_kitchen_categories_for_parser"("p_kitchen_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_kitchen_categories_for_parser"("p_kitchen_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_kitchen_categories_for_parser"("p_kitchen_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_kitchen_owner"("p_kitchen_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_kitchen_owner"("p_kitchen_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_kitchen_owner"("p_kitchen_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_kitchen_owner_email"("p_kitchen_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_kitchen_owner_email"("p_kitchen_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_kitchen_owner_email"("p_kitchen_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_kitchen_preparations_for_parser"("p_kitchen_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_kitchen_preparations_for_parser"("p_kitchen_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_kitchen_preparations_for_parser"("p_kitchen_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unit_kind"("unit_val" "public"."unit") TO "anon";
GRANT ALL ON FUNCTION "public"."get_unit_kind"("unit_val" "public"."unit") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unit_kind"("unit_val" "public"."unit") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unit_measurement_type"("unit_abbr" "public"."unit") TO "anon";
GRANT ALL ON FUNCTION "public"."get_unit_measurement_type"("unit_abbr" "public"."unit") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unit_measurement_type"("unit_abbr" "public"."unit") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_auth_user_updates"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_auth_user_updates"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_auth_user_updates"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_deleted_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_deleted_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_deleted_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_subscription_checkout_complete"("p_stripe_customer_id" "text", "p_user_id" "uuid", "p_team_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_subscription_checkout_complete"("p_stripe_customer_id" "text", "p_user_id" "uuid", "p_team_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."handle_subscription_checkout_complete"("p_stripe_customer_id" "text", "p_user_id" "uuid", "p_team_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_subscription_checkout_complete"("p_stripe_customer_id" "text", "p_user_id" "uuid", "p_team_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."inventory_prep_consistency"() TO "anon";
GRANT ALL ON FUNCTION "public"."inventory_prep_consistency"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."inventory_prep_consistency"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_kitchen_subscribed"("p_kitchen_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_kitchen_subscribed"("p_kitchen_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_kitchen_subscribed"("p_kitchen_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_user_kitchen_admin"("p_user_id" "uuid", "p_kitchen_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_user_kitchen_admin"("p_user_id" "uuid", "p_kitchen_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_user_kitchen_admin"("p_user_id" "uuid", "p_kitchen_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_user_kitchen_member"("p_user_id" "uuid", "p_kitchen_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_user_kitchen_member"("p_user_id" "uuid", "p_kitchen_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_user_kitchen_member"("p_user_id" "uuid", "p_kitchen_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."join_kitchen_with_invite"("invite_code_to_join" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."join_kitchen_with_invite"("invite_code_to_join" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_kitchen_with_invite"("invite_code_to_join" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."overwrite_preparation_with_components"("_prep_component_id" "uuid", "_kitchen_id" "uuid", "_new_name" "text", "_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."overwrite_preparation_with_components"("_prep_component_id" "uuid", "_kitchen_id" "uuid", "_new_name" "text", "_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."overwrite_preparation_with_components"("_prep_component_id" "uuid", "_kitchen_id" "uuid", "_new_name" "text", "_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."prep_yield_change_guard"() TO "anon";
GRANT ALL ON FUNCTION "public"."prep_yield_change_guard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prep_yield_change_guard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_owner_leave"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_owner_leave"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_owner_leave"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_preparation_cycle"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_preparation_cycle"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_preparation_cycle"() TO "service_role";



GRANT ALL ON FUNCTION "public"."rc_prep_unit_guard"() TO "anon";
GRANT ALL ON FUNCTION "public"."rc_prep_unit_guard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rc_prep_unit_guard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."recalculate_parent_amounts_on_yield_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."recalculate_parent_amounts_on_yield_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_parent_amounts_on_yield_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."recipe_components_item_unit_guard"() TO "anon";
GRANT ALL ON FUNCTION "public"."recipe_components_item_unit_guard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."recipe_components_item_unit_guard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."recipes_enforce_component_pairing"() TO "anon";
GRANT ALL ON FUNCTION "public"."recipes_enforce_component_pairing"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."recipes_enforce_component_pairing"() TO "service_role";



GRANT ALL ON FUNCTION "public"."replace_recipe_components"("_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."replace_recipe_components"("_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."replace_recipe_components"("_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_recipe_type"("p_recipe_id" "uuid", "p_new_type" "public"."recipe_type") TO "anon";
GRANT ALL ON FUNCTION "public"."set_recipe_type"("p_recipe_id" "uuid", "p_new_type" "public"."recipe_type") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_recipe_type"("p_recipe_id" "uuid", "p_new_type" "public"."recipe_type") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at_metadata"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at_metadata"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at_metadata"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_components_update_fingerprint"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_components_update_fingerprint"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_components_update_fingerprint"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_preparations_set_fingerprint"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_preparations_set_fingerprint"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_preparations_set_fingerprint"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_recipe_components_update_fingerprint"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_recipe_components_update_fingerprint"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_recipe_components_update_fingerprint"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_recipes_set_fingerprint"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_recipes_set_fingerprint"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_recipes_set_fingerprint"() TO "service_role";



GRANT ALL ON FUNCTION "public"."transfer_kitchen_ownership"("p_kitchen_id" "uuid", "p_new_owner_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_kitchen_ownership"("p_kitchen_id" "uuid", "p_new_owner_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_kitchen_ownership"("p_kitchen_id" "uuid", "p_new_owner_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."unit_kind"("u" "public"."unit") TO "anon";
GRANT ALL ON FUNCTION "public"."unit_kind"("u" "public"."unit") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unit_kind"("u" "public"."unit") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_preparation_fingerprint"("_recipe_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."update_preparation_fingerprint"("_recipe_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_preparation_fingerprint"("_recipe_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_recipe_fingerprint"("_recipe_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."update_recipe_fingerprint"("_recipe_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_recipe_fingerprint"("_recipe_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_stripe_customer_links_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_stripe_customer_links_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_stripe_customer_links_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_preparation_components"("_prep_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_preparation_components"("_prep_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_preparation_components"("_prep_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."uuid_generate_v5"("namespace" "uuid", "name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."uuid_generate_v5"("namespace" "uuid", "name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."uuid_generate_v5"("namespace" "uuid", "name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."uuid_ns_dns"() TO "anon";
GRANT ALL ON FUNCTION "public"."uuid_ns_dns"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."uuid_ns_dns"() TO "service_role";



GRANT ALL ON FUNCTION "public"."verify_kitchen_owner_is_member"() TO "anon";
GRANT ALL ON FUNCTION "public"."verify_kitchen_owner_is_member"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."verify_kitchen_owner_is_member"() TO "service_role";












SET SESSION AUTHORIZATION "postgres";
RESET SESSION AUTHORIZATION;



SET SESSION AUTHORIZATION "postgres";
RESET SESSION AUTHORIZATION;


















GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."components" TO "anon";
GRANT ALL ON TABLE "public"."components" TO "authenticated";
GRANT ALL ON TABLE "public"."components" TO "service_role";



GRANT ALL ON TABLE "public"."kitchen" TO "anon";
GRANT ALL ON TABLE "public"."kitchen" TO "authenticated";
GRANT ALL ON TABLE "public"."kitchen" TO "service_role";



GRANT ALL ON TABLE "public"."kitchen_invites" TO "anon";
GRANT ALL ON TABLE "public"."kitchen_invites" TO "authenticated";
GRANT ALL ON TABLE "public"."kitchen_invites" TO "service_role";



GRANT ALL ON TABLE "public"."stripe_customer_links" TO "anon";
GRANT ALL ON TABLE "public"."stripe_customer_links" TO "authenticated";
GRANT ALL ON TABLE "public"."stripe_customer_links" TO "service_role";



GRANT ALL ON TABLE "public"."kitchen_subscription_status" TO "anon";
GRANT ALL ON TABLE "public"."kitchen_subscription_status" TO "authenticated";
GRANT ALL ON TABLE "public"."kitchen_subscription_status" TO "service_role";



GRANT ALL ON TABLE "public"."kitchen_users" TO "anon";
GRANT ALL ON TABLE "public"."kitchen_users" TO "authenticated";
GRANT ALL ON TABLE "public"."kitchen_users" TO "service_role";



GRANT ALL ON TABLE "public"."recipe_components" TO "anon";
GRANT ALL ON TABLE "public"."recipe_components" TO "authenticated";
GRANT ALL ON TABLE "public"."recipe_components" TO "service_role";



GRANT ALL ON TABLE "public"."recipes" TO "anon";
GRANT ALL ON TABLE "public"."recipes" TO "authenticated";
GRANT ALL ON TABLE "public"."recipes" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";
































--
-- Dumped schema changes for auth and storage
--

CREATE OR REPLACE TRIGGER "on_auth_user_created" AFTER INSERT ON "auth"."users" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_user"();



CREATE OR REPLACE TRIGGER "on_auth_user_deleted" BEFORE DELETE ON "auth"."users" FOR EACH ROW EXECUTE FUNCTION "public"."handle_deleted_user"();



CREATE OR REPLACE TRIGGER "sync_user_data_to_public" AFTER UPDATE OF "raw_user_meta_data", "email" ON "auth"."users" FOR EACH ROW EXECUTE FUNCTION "public"."handle_auth_user_updates"();



CREATE POLICY "Allow authenticated uploads to item-images" ON "storage"."objects" FOR INSERT TO "authenticated", "anon", "service_role" WITH CHECK ((("bucket_id" = 'item-images'::"text") AND ("auth"."uid"() IS NOT NULL)));



