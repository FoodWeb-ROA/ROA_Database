

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



CREATE EXTENSION IF NOT EXISTS "http" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "hypopg" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "index_advisor" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






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


COMMENT ON FUNCTION "public"."convert_amount_safe"("amount_val" numeric, "from_unit" "public"."unit", "to_unit" "public"."unit") IS 'Safely converts an amount from one unit to another using manual conversion factors.
  Returns NULL if units are incompatible (different measurement types).
  Handles count and preparation units by returning the original amount.
  Uses g as base unit for mass, ml as base unit for volume.';



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


COMMENT ON FUNCTION "public"."delete_recipe"("_recipe_id" "uuid", "_kitchen_id" "uuid") IS 'Deletes a recipe and automatically cleans up any orphaned raw ingredients. Preparations are never considered orphaned. Returns summary of deletion.';



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


COMMENT ON FUNCTION "public"."delete_user"() IS 'Handles complete user account deletion. Deletes the auth user, which triggers automatic cleanup: 1. Personal kitchen deletion (via on_auth_user_deleted trigger) 2. Team kitchen membership removal (via FK cascade) 3. Public user profile deletion (via FK cascade). Must be called by an authenticated user to delete their own account.';



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


COMMENT ON FUNCTION "public"."get_kitchen_categories_for_parser"("p_kitchen_id" "uuid") IS 'Returns a JSON array of category names for a given kitchen. Used by the recipe parser service to validate and suggest categories.';



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


COMMENT ON FUNCTION "public"."get_unit_kind"("unit_val" "public"."unit") IS 'Returns the measurement type (mass, volume, count, preparation) for a given unit enum value.';



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


COMMENT ON FUNCTION "public"."handle_auth_user_updates"() IS 'Syncs auth.users changes to public.users and updates personal kitchen names when email changes. Triggered by UPDATE on auth.users (raw_user_meta_data or email).';



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


COMMENT ON FUNCTION "public"."handle_deleted_user"() IS 'Automatically deletes a user''s personal kitchen and all associated data when the user is deleted from auth.users. Triggered BEFORE DELETE on auth.users to ensure personal kitchen is removed before cascade deletes occur.';



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


COMMENT ON FUNCTION "public"."handle_new_user"() IS 'Creates a new user record in public.users and automatically creates a personal kitchen for them. The personal kitchen is named after the user''s email address. Triggered by INSERT on auth.users.';



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


CREATE OR REPLACE FUNCTION "public"."join_kitchen_with_invite"("invite_code_to_join" "text") RETURNS "json"
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


COMMENT ON FUNCTION "public"."overwrite_preparation_with_components"("_prep_component_id" "uuid", "_kitchen_id" "uuid", "_new_name" "text", "_items" "jsonb") IS 'Updates a preparation''s name and replaces its children in a single transaction.';



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


COMMENT ON FUNCTION "public"."recalculate_parent_amounts_on_yield_change"() IS 'Recalculates parent recipe component amounts when a preparation''s yield unit measurement type changes. 
  Now properly converts component amounts to yield units before calculating ratios using manual conversion helpers.
  Example: 1000g component with 1kg yield correctly calculates ratio as 1.0, not 1000.0';



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


COMMENT ON FUNCTION "public"."replace_recipe_components"("_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") IS 'Atomically replaces a recipe''s components in one transaction with access checks. No trigger cleanup needed.';



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


COMMENT ON FUNCTION "public"."upsert_preparation_components"("_prep_recipe_id" "uuid", "_kitchen_id" "uuid", "_items" "jsonb") IS 'Atomically replaces a preparation''s recipe_components with validated items in one transaction. No trigger cleanup needed.';



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

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "category_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "kitchen_id" "uuid" NOT NULL
);

ALTER TABLE ONLY "public"."categories" REPLICA IDENTITY FULL;


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

ALTER TABLE ONLY "public"."components" REPLICA IDENTITY FULL;


ALTER TABLE "public"."components" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kitchen" (
    "kitchen_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" DEFAULT 'new_kitchen'::"text" NOT NULL,
    "type" "public"."KitchenType" DEFAULT 'Personal'::"public"."KitchenType" NOT NULL
);

ALTER TABLE ONLY "public"."kitchen" REPLICA IDENTITY FULL;


ALTER TABLE "public"."kitchen" OWNER TO "postgres";


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

ALTER TABLE ONLY "public"."kitchen_invites" REPLICA IDENTITY FULL;


ALTER TABLE "public"."kitchen_invites" OWNER TO "postgres";


COMMENT ON TABLE "public"."kitchen_invites" IS 'Stores invite codes for kitchens, allowing users to join specific kitchens.';



COMMENT ON COLUMN "public"."kitchen_invites"."invite_id" IS 'Unique identifier for the invite (Primary Key).';



COMMENT ON COLUMN "public"."kitchen_invites"."kitchen_id" IS 'Foreign key referencing the kitchen this invite belongs to. Cascades on kitchen deletion.';



COMMENT ON COLUMN "public"."kitchen_invites"."invite_code" IS 'The unique, typically 6-character, human-readable invite code.';



COMMENT ON COLUMN "public"."kitchen_invites"."created_by" IS 'Foreign key referencing the user (from auth.users) who created this invite. Cascades on user deletion.';



COMMENT ON COLUMN "public"."kitchen_invites"."created_at" IS 'Timestamp indicating when the invite was created.';



COMMENT ON COLUMN "public"."kitchen_invites"."expires_at" IS 'Optional timestamp indicating when the invite code will expire and no longer be usable.';



COMMENT ON COLUMN "public"."kitchen_invites"."is_active" IS 'Boolean indicating if the invite code is currently active and can be used. Defaults to true.';



COMMENT ON COLUMN "public"."kitchen_invites"."max_uses" IS 'Optional integer defining the maximum number of times this invite code can be used.';



COMMENT ON COLUMN "public"."kitchen_invites"."current_uses" IS 'Integer tracking how many times this invite code has been used. Defaults to 0.';



CREATE TABLE IF NOT EXISTS "public"."kitchen_users" (
    "kitchen_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "is_admin" boolean DEFAULT false NOT NULL
);

ALTER TABLE ONLY "public"."kitchen_users" REPLICA IDENTITY FULL;


ALTER TABLE "public"."kitchen_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."recipe_components" (
    "recipe_id" "uuid" NOT NULL,
    "component_id" "uuid" NOT NULL,
    "amount" numeric NOT NULL,
    "unit" "public"."unit" NOT NULL,
    "item" "text",
    CONSTRAINT "recipe_components_item_unit_check" CHECK ((("unit" = 'x'::"public"."unit") OR ("item" IS NULL)))
);

ALTER TABLE ONLY "public"."recipe_components" REPLICA IDENTITY FULL;


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

ALTER TABLE ONLY "public"."recipes" REPLICA IDENTITY FULL;


ALTER TABLE "public"."recipes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "user_id" "uuid" NOT NULL,
    "user_fullname" "text",
    "user_email" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);

ALTER TABLE ONLY "public"."users" REPLICA IDENTITY FULL;


ALTER TABLE "public"."users" OWNER TO "postgres";


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



ALTER TABLE ONLY "public"."components"
    ADD CONSTRAINT "unique_kitchen_ingredient_name" UNIQUE ("name", "kitchen_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("user_id");



CREATE INDEX "idx_categories_kitchen_id" ON "public"."categories" USING "btree" ("kitchen_id");



CREATE INDEX "idx_components_kitchen_id" ON "public"."components" USING "btree" ("kitchen_id");



CREATE INDEX "idx_components_kitchen_lowername" ON "public"."components" USING "btree" ("kitchen_id", "lower"("btrim"("name"))) WHERE ("component_type" = 'Raw_Ingredient'::"public"."component_type");



CREATE INDEX "idx_components_name_trgm_unicode" ON "public"."components" USING "gin" ("lower"("btrim"("name")) "extensions"."gin_trgm_ops") WHERE ("component_type" = 'Raw_Ingredient'::"public"."component_type");



CREATE INDEX "idx_components_recipe_id" ON "public"."components" USING "btree" ("recipe_id");



CREATE UNIQUE INDEX "idx_components_unique_prep_recipe" ON "public"."components" USING "btree" ("recipe_id") WHERE ("component_type" = 'Preparation'::"public"."component_type");



CREATE INDEX "idx_kitchen_invites_created_by" ON "public"."kitchen_invites" USING "btree" ("created_by");



CREATE INDEX "idx_kitchen_invites_invite_code" ON "public"."kitchen_invites" USING "btree" ("invite_code");



CREATE INDEX "idx_kitchen_invites_kitchen_id" ON "public"."kitchen_invites" USING "btree" ("kitchen_id");



CREATE INDEX "idx_kitchen_users_kitchen_id" ON "public"."kitchen_users" USING "btree" ("kitchen_id");



CREATE INDEX "idx_kitchen_users_user_id" ON "public"."kitchen_users" USING "btree" ("user_id");



CREATE INDEX "idx_recipe_components_component_id" ON "public"."recipe_components" USING "btree" ("component_id");



CREATE INDEX "idx_recipe_components_recipe_id" ON "public"."recipe_components" USING "btree" ("recipe_id");



CREATE INDEX "idx_recipes_category_id" ON "public"."recipes" USING "btree" ("category_id");



CREATE INDEX "idx_recipes_fingerprint" ON "public"."recipes" USING "btree" ("fingerprint");



CREATE INDEX "idx_recipes_fingerprint_plain_trgm" ON "public"."recipes" USING "gin" ("fingerprint_plain" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_recipes_kitchen_id" ON "public"."recipes" USING "btree" ("kitchen_id");



CREATE INDEX "recipe_components_unique_idx" ON "public"."recipe_components" USING "btree" ("recipe_id", "component_id");



CREATE INDEX "recipe_name_trgm_idx" ON "public"."recipes" USING "gin" ("lower"("recipe_name") "extensions"."gin_trgm_ops");



CREATE UNIQUE INDEX "unique_personal_kitchen_name" ON "public"."kitchen" USING "btree" ("name") WHERE ("type" = 'Personal'::"public"."KitchenType");



COMMENT ON INDEX "public"."unique_personal_kitchen_name" IS 'Ensures each Personal kitchen has a unique name (email). Team kitchens are not restricted by this constraint.';



CREATE OR REPLACE TRIGGER "recipe-images" AFTER DELETE OR UPDATE ON "public"."recipes" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://roa-api-515418725737.us-central1.run.app/webhook', 'POST', '{"Content-type":"application/json","X-Supabase-Signature":"roa-supabase-webhook-secret"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "tg_recipe_components_update_fingerprint" AFTER INSERT OR DELETE OR UPDATE ON "public"."recipe_components" FOR EACH ROW EXECUTE FUNCTION "public"."tg_components_update_fingerprint"();



CREATE CONSTRAINT TRIGGER "trg_components_enforce_recipe_pairing" AFTER INSERT OR UPDATE OF "component_type", "recipe_id" ON "public"."components" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."components_enforce_recipe_pairing"();



CREATE CONSTRAINT TRIGGER "trg_components_match_name_kitchen" AFTER INSERT OR UPDATE OF "name", "kitchen_id", "component_type", "recipe_id" ON "public"."components" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."enforce_prep_name_kitchen_match_from_components"();



CREATE OR REPLACE TRIGGER "trg_enforce_one_user_per_personal_kitchen" BEFORE INSERT ON "public"."kitchen_users" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_one_user_per_personal_kitchen"();



CREATE OR REPLACE TRIGGER "trg_prevent_prep_cycle" BEFORE INSERT OR UPDATE ON "public"."recipe_components" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_preparation_cycle"();



CREATE OR REPLACE TRIGGER "trg_rc_prep_unit_guard" BEFORE INSERT OR UPDATE ON "public"."recipe_components" FOR EACH ROW EXECUTE FUNCTION "public"."rc_prep_unit_guard"();



CREATE OR REPLACE TRIGGER "trg_recalculate_parent_amounts_on_yield_change" BEFORE UPDATE OF "serving_or_yield_unit", "serving_or_yield_amount" ON "public"."recipes" FOR EACH ROW WHEN ((("old"."serving_or_yield_unit" IS DISTINCT FROM "new"."serving_or_yield_unit") OR ("old"."serving_or_yield_amount" IS DISTINCT FROM "new"."serving_or_yield_amount"))) EXECUTE FUNCTION "public"."recalculate_parent_amounts_on_yield_change"();



COMMENT ON TRIGGER "trg_recalculate_parent_amounts_on_yield_change" ON "public"."recipes" IS 'Automatically recalculates parent recipe component amounts when a preparation''s yield unit measurement type changes (e.g., weight to volume). This REPLACES the old prep_yield_change_guard that blocked such changes. Instead of blocking, we now recalculate to maintain correct proportions.';



CREATE OR REPLACE TRIGGER "trg_recipe_components_item_unit" BEFORE INSERT OR UPDATE ON "public"."recipe_components" FOR EACH ROW EXECUTE FUNCTION "public"."recipe_components_item_unit_guard"();



CREATE OR REPLACE TRIGGER "trg_recipe_components_update_fingerprint" AFTER INSERT OR DELETE OR UPDATE ON "public"."recipe_components" FOR EACH ROW EXECUTE FUNCTION "public"."tg_recipe_components_update_fingerprint"();



CREATE CONSTRAINT TRIGGER "trg_recipes_enforce_component_pairing" AFTER INSERT OR UPDATE OF "recipe_type" ON "public"."recipes" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."recipes_enforce_component_pairing"();



CREATE CONSTRAINT TRIGGER "trg_recipes_match_name_kitchen" AFTER INSERT OR UPDATE OF "recipe_name", "kitchen_id", "recipe_type" ON "public"."recipes" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION "public"."enforce_prep_name_kitchen_match_from_recipes"();



CREATE OR REPLACE TRIGGER "trg_recipes_set_fingerprint" AFTER INSERT OR UPDATE OF "directions" ON "public"."recipes" FOR EACH ROW EXECUTE FUNCTION "public"."tg_recipes_set_fingerprint"();



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



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



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



ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."categories";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."components";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."kitchen";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."kitchen_invites";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."kitchen_users";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."recipe_components";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."recipes";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."users";









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



GRANT ALL ON FUNCTION "public"."create_preparation_with_component"("_kitchen" "uuid", "_name" "text", "_category" "uuid", "_directions" "text"[], "_time" interval, "_cooking_notes" "text", "_yield_unit" "public"."unit", "_yield_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."create_preparation_with_component"("_kitchen" "uuid", "_name" "text", "_category" "uuid", "_directions" "text"[], "_time" interval, "_cooking_notes" "text", "_yield_unit" "public"."unit", "_yield_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_preparation_with_component"("_kitchen" "uuid", "_name" "text", "_category" "uuid", "_directions" "text"[], "_time" interval, "_cooking_notes" "text", "_yield_unit" "public"."unit", "_yield_amount" numeric) TO "service_role";



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



GRANT ALL ON FUNCTION "public"."inventory_prep_consistency"() TO "anon";
GRANT ALL ON FUNCTION "public"."inventory_prep_consistency"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."inventory_prep_consistency"() TO "service_role";



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



GRANT ALL ON FUNCTION "public"."unit_kind"("u" "public"."unit") TO "anon";
GRANT ALL ON FUNCTION "public"."unit_kind"("u" "public"."unit") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unit_kind"("u" "public"."unit") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_preparation_fingerprint"("_recipe_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."update_preparation_fingerprint"("_recipe_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_preparation_fingerprint"("_recipe_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_recipe_fingerprint"("_recipe_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."update_recipe_fingerprint"("_recipe_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_recipe_fingerprint"("_recipe_id" "uuid") TO "service_role";



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









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;

--
-- Dumped schema changes for auth and storage
--

CREATE OR REPLACE TRIGGER "on_auth_user_created" AFTER INSERT ON "auth"."users" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_user"();



CREATE OR REPLACE TRIGGER "on_auth_user_deleted" BEFORE DELETE ON "auth"."users" FOR EACH ROW EXECUTE FUNCTION "public"."handle_deleted_user"();



CREATE OR REPLACE TRIGGER "sync_user_data_to_public" AFTER UPDATE OF "raw_user_meta_data", "email" ON "auth"."users" FOR EACH ROW EXECUTE FUNCTION "public"."handle_auth_user_updates"();



