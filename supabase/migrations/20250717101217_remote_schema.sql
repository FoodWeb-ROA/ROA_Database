

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


-- Compatibility shim for environments without the supabase_functions schema
DO $$
BEGIN
    -- Create schema if missing
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'supabase_functions') THEN
        EXECUTE 'CREATE SCHEMA supabase_functions';
    END IF;

    -- Only create stub trigger function if a real one does not already exist
    IF to_regprocedure('supabase_functions.http_request()') IS NULL THEN
        EXECUTE $fn$
        CREATE OR REPLACE FUNCTION supabase_functions.http_request()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $BODY$
        DECLARE
            _url text := TG_ARGV[0];
            _method text := COALESCE(TG_ARGV[1], 'POST');
            _headers jsonb := COALESCE(TG_ARGV[2]::jsonb, '{}'::jsonb);
            _body jsonb := COALESCE(TG_ARGV[3]::jsonb, '{}'::jsonb);
            _timeout_ms integer := COALESCE(NULLIF(TG_ARGV[4], '')::int, 5000);
        BEGIN
            -- Best-effort HTTP call if pgsql-http extension is available; otherwise no-op
            BEGIN
                IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'http') THEN
                    PERFORM extensions.http_post(_url, _body::text, 'application/json');
                END IF;
            EXCEPTION WHEN OTHERS THEN
                -- swallow errors to avoid blocking DML
                NULL;
            END;

            IF TG_OP = 'DELETE' THEN
                RETURN OLD;
            ELSE
                RETURN NEW;
            END IF;
        END;
        $BODY$;
        $fn$;
    END IF;
END;
$$;






CREATE EXTENSION IF NOT EXISTS "hypopg" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "index_advisor" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."KitchenType" AS ENUM (
    'Personal',
    'Team'
);


ALTER TYPE "public"."KitchenType" OWNER TO "postgres";


CREATE TYPE "public"."unit_measurement_type" AS ENUM (
    'weight',
    'volume',
    'count',
    'preparation'
);


ALTER TYPE "public"."unit_measurement_type" OWNER TO "postgres";


CREATE TYPE "public"."unit_system" AS ENUM (
    'metric',
    'imperial'
);


ALTER TYPE "public"."unit_system" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."after_dish_component_deleted_trigger_fn"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RAISE NOTICE 'Dish component link deleted for ingredient_id: %. Checking for orphaning.', OLD.ingredient_id; -- CORRECTED: Assumes FK column is 'ingredient_id'
    PERFORM public.handle_ingredient_deletion_check(OLD.ingredient_id); -- CORRECTED: Assumes FK column is 'ingredient_id'
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."after_dish_component_deleted_trigger_fn"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."after_preparation_component_deleted_trigger_fn"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RAISE NOTICE 'Preparation component link deleted for ingredient_id: %. Checking for orphaning.', OLD.ingredient_id; -- CORRECTED: Assumes FK column is 'ingredient_id'
    PERFORM public.handle_ingredient_deletion_check(OLD.ingredient_id); -- CORRECTED: Assumes FK column is 'ingredient_id'
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."after_preparation_component_deleted_trigger_fn"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_unit_for_preparations"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    target_unit_id UUID;
    is_preparation_unit BOOLEAN;
BEGIN
    -- Check if the ingredient is also a preparation
    -- The assumption here is that if an ingredient's ID appears in the preparations table,
    -- it's considered a preparation.
    IF EXISTS (SELECT 1 FROM public.preparations WHERE preparation_id = NEW.ingredient_id) THEN
        -- Get the 'Preparation' unit_id (assuming 'Preparation' is a unit_name in your units table)
        SELECT unit_id INTO target_unit_id FROM public.units WHERE unit_name = 'Preparation' LIMIT 1;

        -- If the 'Preparation' unit exists
        IF target_unit_id IS NOT NULL THEN
            -- Check if the new ingredient's unit_id is the 'Preparation' unit
            is_preparation_unit := (NEW.unit_id = target_unit_id);

            IF NOT is_preparation_unit THEN
                RAISE EXCEPTION 'Ingredients that are also preparations (identified by ingredient_id being a preparation_id) must use the "Preparation" unit (ID: %). The current unit_id is %.', target_unit_id, NEW.unit_id;
            END IF;
        ELSE
            -- This case handles if 'Preparation' unit is not found, which might be an issue itself.
            RAISE WARNING 'The "Preparation" unit was not found in the units table. Unit check for preparation-ingredients cannot be enforced.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_unit_for_preparations"() OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."create_personal_kitchen"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    existing_kitchen_id uuid;
BEGIN
    -- look for an existing personal kitchen
    SELECT ku.kitchen_id
    INTO   existing_kitchen_id
    FROM   public.kitchen_users ku          -- <-- fully-qualified
    WHERE  ku.user_id = NEW.id;

    IF existing_kitchen_id IS NOT NULL THEN
        DELETE FROM public.kitchen         WHERE kitchen_id = existing_kitchen_id;
        DELETE FROM public.kitchen_users   WHERE kitchen_id = existing_kitchen_id;
    END IF;

    INSERT INTO public.kitchen (name, type)
    VALUES (NEW.email, 'Personal')
    RETURNING kitchen_id
    INTO existing_kitchen_id;

    -- Insert the user as an admin in their personal kitchen
    INSERT INTO public.kitchen_users (kitchen_id, user_id, is_admin)
    VALUES (existing_kitchen_id, NEW.id, TRUE);

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_personal_kitchen"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_dish"("p_dish_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
    -- Check if the user has permission (optional, depends on your RLS setup)
    -- Example: Ensure the dish belongs to the user's kitchen or they have a specific role
    -- if not exists (select 1 from dishes where dish_id = p_dish_id and kitchen_id = auth.jwt()->>'app_metadata.kitchen_id') then
    --     raise exception 'Permission denied to delete dish %', p_dish_id;
    -- end if;

    -- Delete components associated with the dish
    delete from public.dish_components dc
    where dc.dish_id = p_dish_id;

    -- Delete the dish itself
    delete from public.dishes d
    where d.dish_id = p_dish_id;

    -- Optionally, log the deletion or perform other actions
    -- raise notice 'Dish % deleted successfully.', p_dish_id;

exception
    when others then
        raise exception 'Error deleting dish %: %', p_dish_id, sqlerrm;
end;
$$;


ALTER FUNCTION "public"."delete_dish"("p_dish_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_dish_and_orphaned_components_trigger_fn"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    SET search_path = public, pg_temp;

    RAISE NOTICE 'Dish (id: %) deleted – removing its components.', OLD.dish_id;
    DELETE FROM public.dish_components WHERE dish_id = OLD.dish_id;
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."delete_dish_and_orphaned_components_trigger_fn"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_preparation"("p_preparation_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
    v_ingredient_name text;
begin
    -- Optional: Add permission checks similar to delete_dish if needed

    -- Get the name for logging/error messages before deleting
    select i.name into v_ingredient_name
    from public.ingredients i
    where i.ingredient_id = p_preparation_id;

    -- Delete ingredients used within the preparation
    delete from public.preparation_ingredients pi
    where pi.preparation_id = p_preparation_id;

    -- Delete the preparation details
    delete from public.preparations p
    where p.preparation_id = p_preparation_id;

    -- Delete the base ingredient entry for the preparation
    delete from public.ingredients i
    where i.ingredient_id = p_preparation_id;

    -- Log success
    -- raise notice 'Preparation % (%) deleted successfully.', v_ingredient_name, p_preparation_id;

exception
    when others then
        -- Use the fetched name in the error message if available
        raise exception 'Error deleting preparation % (%): %', 
            coalesce(v_ingredient_name, '') || 'ID:', 
            p_preparation_id, 
            sqlerrm;
end;
$$;


ALTER FUNCTION "public"."delete_preparation"("p_preparation_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_preparation_and_orphaned_components_trigger_fn"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    SET search_path = public, pg_temp;

    RAISE NOTICE 'Preparation (id: %) deleted – removing its components.', OLD.preparation_id;
    DELETE FROM public.preparation_components WHERE preparation_id = OLD.preparation_id;

    /* Preparation is also an ingredient, so delete its ingredient row too. */
    RAISE NOTICE 'Deleting ingredient entry for preparation (id: %).', OLD.preparation_id;
    DELETE FROM public.ingredients WHERE ingredient_id = OLD.preparation_id;

    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."delete_preparation_and_orphaned_components_trigger_fn"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_user_kitchen"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    DELETE FROM public.kitchen
    WHERE kitchen_id IN (
        SELECT ku.kitchen_id
        FROM public.kitchen_users ku
        WHERE ku.user_id = OLD.id
    );
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."delete_user_kitchen"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_one_user_per_personal_kitchen"() RETURNS "trigger"
    LANGUAGE "plpgsql"
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


CREATE OR REPLACE FUNCTION "public"."find_ingredients_by_slug"("_slugs" "text"[], "_kitchen" "uuid") RETURNS TABLE("slug" "text", "ingredient_id" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT slug_simple(name) AS slug,
         ingredient_id
    FROM public.ingredients
   WHERE kitchen_id = _kitchen
     AND slug_simple(name) = ANY(_slugs);
$$;


ALTER FUNCTION "public"."find_ingredients_by_slug"("_slugs" "text"[], "_kitchen" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_ingredients_fuzzy"("_slugs" "text"[], "_kitchen" "uuid", "_threshold" real DEFAULT 0.88) RETURNS TABLE("input_slug" "text", "ingredient_id" "uuid")
    LANGUAGE "sql" STABLE
    AS $$
with cand as (
  select s as input_slug, i.ingredient_id,
         similarity(slug_simple(i.name), s) as sim,
         row_number() over (partition by s order by similarity(slug_simple(i.name), s) desc) as rn
  from unnest(_slugs) s
       join public.ingredients i
         on i.kitchen_id = _kitchen
        and similarity(slug_simple(i.name), s) >= _threshold
)
select input_slug, ingredient_id
from cand
where rn = 1;
$$;


ALTER FUNCTION "public"."find_ingredients_fuzzy"("_slugs" "text"[], "_kitchen" "uuid", "_threshold" real) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_preparations_by_fingerprints"("_fps" "uuid"[], "_kitchen" "uuid") RETURNS TABLE("fingerprint" "uuid", "preparation_id" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT p.fingerprint, p.preparation_id
    FROM public.preparations p
    JOIN public.ingredients iprep ON iprep.ingredient_id = p.preparation_id
   WHERE iprep.kitchen_id = _kitchen
     AND p.fingerprint = ANY(_fps);
$$;


ALTER FUNCTION "public"."find_preparations_by_fingerprints"("_fps" "uuid"[], "_kitchen" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_preparations_by_plain"("_names" "text"[], "_kitchen" "uuid") RETURNS TABLE("fingerprint_plain" "text", "preparation_id" "uuid", "sim" numeric)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT p.fingerprint_plain,
         p.preparation_id,
         similarity(p.fingerprint_plain, q.plain) as sim
    FROM unnest(_names) AS q(plain)
    JOIN public.preparations p ON TRUE
    JOIN public.ingredients iprep ON iprep.ingredient_id = p.preparation_id
   WHERE iprep.kitchen_id = _kitchen
     AND (
          similarity(p.fingerprint_plain, q.plain) >= 0.75
         );
$$;


ALTER FUNCTION "public"."find_preparations_by_plain"("_names" "text"[], "_kitchen" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fp_namespace"() RETURNS "uuid"
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    AS $$
    select uuid_generate_v5(uuid_ns_dns(), 'roa-preparation-fingerprint');
$$;


ALTER FUNCTION "public"."fp_namespace"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_components_for_preparations"("_prep_ids" "uuid"[]) RETURNS TABLE("preparation_id" "uuid", "ingredient_id" "uuid", "amount" numeric, "unit_id" "uuid", "is_preparation" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT pc.preparation_id,
         pc.ingredient_id,
         pc.amount,
         pc.unit_id,
         EXISTS (SELECT 1 FROM public.preparations pr WHERE pr.preparation_id = pc.ingredient_id) AS is_preparation
    FROM public.preparation_components pc
   WHERE pc.preparation_id = ANY(_prep_ids);
$$;


ALTER FUNCTION "public"."get_components_for_preparations"("_prep_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_ingredient_deletion_check"("p_ingredient_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    is_used_in_dishes  boolean;
    is_used_in_preps   boolean;
    is_a_preparation   boolean;
BEGIN
    SET search_path = public, pg_temp;           -- safety for SECURITY DEFINER

    /* Is this id still referenced anywhere? */
    SELECT EXISTS (SELECT 1
                   FROM public.dish_components dc
                   WHERE dc.ingredient_id = p_ingredient_id)
    INTO  is_used_in_dishes;

    SELECT EXISTS (SELECT 1
                   FROM public.preparation_components pc
                   WHERE pc.ingredient_id = p_ingredient_id)
    INTO  is_used_in_preps;

    /* Does this id correspond to a preparation? */
    SELECT EXISTS (SELECT 1
                   FROM public.preparations p
                   WHERE p.preparation_id = p_ingredient_id)
    INTO  is_a_preparation;

    /* Keep preparations even if orphaned */
    IF is_a_preparation THEN
        RETURN;
    END IF;

    /* For raw ingredients, delete only if unused everywhere */
    IF NOT is_used_in_dishes AND NOT is_used_in_preps THEN
        RAISE NOTICE 'Orphaned raw ingredient (id: %) deleted.', p_ingredient_id;
        DELETE FROM public.ingredients WHERE ingredient_id = p_ingredient_id;
    END IF;
END;
$$;


ALTER FUNCTION "public"."handle_ingredient_deletion_check"("p_ingredient_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.users (user_id, user_email, user_fullname, user_language)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'language'
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_times"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
 BEGIN
 IF (TG_OP = 'INSERT') THEN
 NEW.created_at := now();
 NEW.updated_at := now();
 ELSEIF (TG_OP = 'UPDATE') THEN
 -- Only update updated_at if the row data has actually changed
 -- Prevent trigger loops or unnecessary updates
 IF OLD IS DISTINCT FROM NEW THEN
 NEW.created_at = OLD.created_at; -- Keep original creation time
 NEW.updated_at = now();
 END IF;
 END IF;
 RETURN NEW;
 END;
 $$;


ALTER FUNCTION "public"."handle_times"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."inventory_prep_consistency"() RETURNS "trigger"
    LANGUAGE "plpgsql"
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


CREATE OR REPLACE FUNCTION "public"."prevent_preparation_cycle"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    _cycle_found BOOLEAN := FALSE;
BEGIN
    -- Ignore deletes
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    /*
      Only run when the component we’re adding is itself a preparation.
      (Raw-ingredient rows can never create cycles.)
    */
    IF NOT EXISTS (
        SELECT 1
        FROM public.preparations p
        WHERE p.preparation_id = NEW.ingredient_id
    ) THEN
        RETURN NEW;
    END IF;

    /*
      Walk up the ancestor chain:
      starting from the *parent* we’re inserting into (NEW.preparation_id)
      and climbing via preparation_components.preparation_id → ingredient_id.
    */
    WITH RECURSIVE ancestors AS (
        SELECT pc.preparation_id                           AS ancestor_id,
               ARRAY[pc.preparation_id]                    AS path
        FROM   public.preparation_components pc
        WHERE  pc.ingredient_id = NEW.preparation_id

        UNION ALL

        SELECT pc.preparation_id,
               path || pc.preparation_id
        FROM   ancestors a
        JOIN   public.preparation_components pc
               ON pc.ingredient_id = a.ancestor_id
        WHERE  NOT pc.preparation_id = ANY(path)
    )
    SELECT TRUE
      INTO _cycle_found
      FROM ancestors
     WHERE ancestor_id = NEW.ingredient_id   -- would close the loop
     LIMIT 1;

    IF _cycle_found THEN
        RAISE EXCEPTION
          'Cycle detected: adding preparation % as a component of % would create a loop',
          NEW.ingredient_id, NEW.preparation_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_preparation_cycle"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_deleted_ingredients"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    p_ingredient_id uuid;
BEGIN
    SET search_path = public, pg_temp;

    /* Session-lifetime scratch table; survives for the tx, disappears on commit. */
    CREATE TEMP TABLE IF NOT EXISTS deleted_ingredients_temp
    ( ingredient_id uuid PRIMARY KEY )
    ON COMMIT DROP;

    /* Collect ids from the statement, ignore duplicates. */
    INSERT INTO deleted_ingredients_temp(ingredient_id)
    SELECT DISTINCT ot.ingredient_id
    FROM OLD_TABLE AS ot
    ON CONFLICT (ingredient_id) DO NOTHING;

    /* Process every unique id collected so far. */
    FOR p_ingredient_id IN
        SELECT dit.ingredient_id FROM deleted_ingredients_temp dit
    LOOP
        PERFORM public.handle_ingredient_deletion_check(p_ingredient_id);
    END LOOP;

    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."process_deleted_ingredients"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."slug_simple"("p_input" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $_$
  SELECT regexp_replace(
           regexp_replace(lower(trim(p_input)), '[^a-z0-9]+', '-', 'g'),
           '(es|s)$', '', 'g'
         );
$_$;


ALTER FUNCTION "public"."slug_simple"("p_input" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."tg_components_update_fingerprint"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  _prep_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    _prep_id := OLD.preparation_id;
  ELSE
    _prep_id := NEW.preparation_id;
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
    AS $$
BEGIN
  PERFORM public.update_preparation_fingerprint(NEW.preparation_id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."tg_preparations_set_fingerprint"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_kitchen_name_on_email_change"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    UPDATE public.kitchen
    SET name = NEW.email
    WHERE kitchen_id IN (
        SELECT ku.kitchen_id
        FROM public.kitchen_users ku
        WHERE ku.user_id = NEW.id
    );
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_kitchen_name_on_email_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_preparation_fingerprint"("_prep_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$DECLARE
    _plain text;
    _fp    uuid;
BEGIN
    /* Canonical plain fingerprint */
    SELECT
            COALESCE(
                string_agg(slug_simple(i.name), '-' ORDER BY slug_simple(i.name)),
                'empty'
            )
            || '|' ||
            regexp_replace(
                lower(array_to_string(p.directions, ' ')),
                '[^a-z]+', ' ', 'g'
            )
      INTO _plain
      FROM public.preparations p
      LEFT JOIN public.preparation_components pc
             ON pc.preparation_id = p.preparation_id
      LEFT JOIN public.ingredients i
             ON i.ingredient_id = pc.ingredient_id
     WHERE p.preparation_id = _prep_id
     GROUP BY p.directions;

    _plain := trim(_plain);

    /* UUID-v5 over that exact string */
    _fp := uuid_generate_v5(public.fp_namespace(), _plain);

    UPDATE public.preparations
       SET fingerprint       = _fp,
           fingerprint_plain = _plain
     WHERE preparation_id    = _prep_id
       AND (fingerprint IS DISTINCT FROM _fp
            OR fingerprint_plain IS DISTINCT FROM _plain);
END;$$;


ALTER FUNCTION "public"."update_preparation_fingerprint"("_prep_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
   NEW.updated_at = NOW(); 
   RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."uuid_generate_v5"("namespace" "uuid", "name" "text") RETURNS "uuid"
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    AS $_$
  SELECT extensions.uuid_generate_v5($1, $2);
$_$;


ALTER FUNCTION "public"."uuid_generate_v5"("namespace" "uuid", "name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."uuid_ns_dns"() RETURNS "uuid"
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    AS $$
  SELECT extensions.uuid_ns_dns();
$$;


ALTER FUNCTION "public"."uuid_ns_dns"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."dish_components" (
    "dish_id" "uuid" NOT NULL,
    "ingredient_id" "uuid" NOT NULL,
    "unit_id" "uuid" NOT NULL,
    "amount" real,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "piece_type" "text"
);

ALTER TABLE ONLY "public"."dish_components" REPLICA IDENTITY FULL;


ALTER TABLE "public"."dish_components" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dishes" (
    "dish_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "menu_section_id" "uuid",
    "dish_name" "text" NOT NULL,
    "total_time" interval DEFAULT '00:30:00'::interval NOT NULL,
    "serving_size" integer DEFAULT 1 NOT NULL,
    "cooking_notes" "text",
    "serving_unit_id" "uuid" NOT NULL,
    "serving_item" "text" DEFAULT NULL,
    "directions" "text"[],
    "num_servings" integer,
    "kitchen_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "image_updated_at" timestamp with time zone
);


ALTER TABLE ONLY "public"."dishes" REPLICA IDENTITY FULL;


ALTER TABLE "public"."dishes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ingredients" (
    "name" "text" NOT NULL,
    "ingredient_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "kitchen_id" "uuid" DEFAULT '816f8fdb-fedd-4e6e-899b-9c98513e49c5'::"uuid" NOT NULL
);

ALTER TABLE ONLY "public"."ingredients" REPLICA IDENTITY FULL;


ALTER TABLE "public"."ingredients" OWNER TO "postgres";


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


CREATE TABLE IF NOT EXISTS "public"."languages" (
    "ISO_Code" "text" NOT NULL,
    "name_english" "text" DEFAULT '{English}'::"text"[] NOT NULL,
    "name_in_language" "text" NOT NULL
);


ALTER TABLE "public"."languages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."menu_section" (
    "menu_section_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "kitchen_id" "uuid" NOT NULL
);

ALTER TABLE ONLY "public"."menu_section" REPLICA IDENTITY FULL;


ALTER TABLE "public"."menu_section" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."preparation_components" (
    "preparation_id" "uuid" NOT NULL,
    "ingredient_id" "uuid" NOT NULL,
    "amount" double precision,
    "unit_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "piece_type" "text"
);

ALTER TABLE ONLY "public"."preparation_components" REPLICA IDENTITY FULL;


ALTER TABLE "public"."preparation_components" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."preparations" (
    "preparation_id" "uuid" NOT NULL,
    "directions" "text"[] NOT NULL,
    "total_time" integer,
    "fingerprint" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "cooking_notes" "text",
    "image_updated_at" timestamp with time zone,
    "fingerprint_plain" "text"
);

ALTER TABLE ONLY "public"."preparations" REPLICA IDENTITY FULL;


ALTER TABLE "public"."preparations" OWNER TO "postgres";


COMMENT ON COLUMN "public"."preparations"."total_time" IS 'Estimated time in minutes required to make this specific preparation.';



CREATE TABLE IF NOT EXISTS "public"."units" (
    "unit_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "unit_name" "text" NOT NULL,
    "system" "public"."unit_system",
    "abbreviation" "text",
    "measurement_type" "public"."unit_measurement_type"
);


ALTER TABLE "public"."units" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "user_id" "uuid" NOT NULL,
    "user_fullname" "text",
    "user_email" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "public"."dish_components"
    ADD CONSTRAINT "dish_components_pkey" PRIMARY KEY ("dish_id", "ingredient_id");



ALTER TABLE ONLY "public"."dishes"
    ADD CONSTRAINT "dishes_name_kitchen_id_unique" UNIQUE ("dish_name", "kitchen_id");



ALTER TABLE ONLY "public"."ingredients"
    ADD CONSTRAINT "ingredients_ingredient_id_key" UNIQUE ("ingredient_id");



ALTER TABLE ONLY "public"."ingredients"
    ADD CONSTRAINT "ingredients_name_kitchen_id_key" UNIQUE ("name", "kitchen_id");



ALTER TABLE ONLY "public"."ingredients"
    ADD CONSTRAINT "ingredients_name_kitchen_id_unique" UNIQUE ("name", "kitchen_id");



ALTER TABLE ONLY "public"."ingredients"
    ADD CONSTRAINT "ingredients_pkey" PRIMARY KEY ("ingredient_id");



ALTER TABLE ONLY "public"."kitchen_invites"
    ADD CONSTRAINT "kitchen_invites_invite_code_key" UNIQUE ("invite_code");



ALTER TABLE ONLY "public"."kitchen_invites"
    ADD CONSTRAINT "kitchen_invites_pkey" PRIMARY KEY ("invite_id");



ALTER TABLE ONLY "public"."kitchen"
    ADD CONSTRAINT "kitchen_pkey" PRIMARY KEY ("kitchen_id");



ALTER TABLE ONLY "public"."kitchen_users"
    ADD CONSTRAINT "kitchen_users_pkey" PRIMARY KEY ("kitchen_id", "user_id");



ALTER TABLE ONLY "public"."languages"
    ADD CONSTRAINT "languages_ISO_Code_key" UNIQUE ("ISO_Code");



ALTER TABLE ONLY "public"."languages"
    ADD CONSTRAINT "languages_name_in_language_key" UNIQUE ("name_in_language");



ALTER TABLE ONLY "public"."languages"
    ADD CONSTRAINT "languages_names_english_key" UNIQUE ("name_english");



ALTER TABLE ONLY "public"."languages"
    ADD CONSTRAINT "languages_pkey" PRIMARY KEY ("ISO_Code");



ALTER TABLE ONLY "public"."menu_section"
    ADD CONSTRAINT "menu_section_name_kitchen_id_unique" UNIQUE ("name", "kitchen_id");



ALTER TABLE ONLY "public"."menu_section"
    ADD CONSTRAINT "menu_section_pkey" PRIMARY KEY ("menu_section_id");



ALTER TABLE ONLY "public"."preparation_components"
    ADD CONSTRAINT "preparation_ingredients_pkey" PRIMARY KEY ("preparation_id", "ingredient_id");



ALTER TABLE ONLY "public"."preparations"
    ADD CONSTRAINT "preparations_pkey" PRIMARY KEY ("preparation_id");



ALTER TABLE ONLY "public"."dishes"
    ADD CONSTRAINT "recipe_pkey" PRIMARY KEY ("dish_id");



ALTER TABLE ONLY "public"."ingredients"
    ADD CONSTRAINT "unique_kitchen_ingredient_name" UNIQUE ("name", "kitchen_id");



ALTER TABLE ONLY "public"."units"
    ADD CONSTRAINT "units_pkey" PRIMARY KEY ("unit_id");



ALTER TABLE ONLY "public"."units"
    ADD CONSTRAINT "units_unit_name_key" UNIQUE ("unit_name");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("user_id");



CREATE INDEX "idx_ingredients_name_slug_trgm" ON "public"."ingredients" USING "gin" ("public"."slug_simple"("name") "public"."gin_trgm_ops");



CREATE INDEX "idx_kitchen_invites_created_by" ON "public"."kitchen_invites" USING "btree" ("created_by");



CREATE INDEX "idx_kitchen_invites_invite_code" ON "public"."kitchen_invites" USING "btree" ("invite_code");



CREATE INDEX "idx_kitchen_invites_kitchen_id" ON "public"."kitchen_invites" USING "btree" ("kitchen_id");



CREATE INDEX "idx_preparations_fingerprint" ON "public"."preparations" USING "btree" ("fingerprint");



CREATE INDEX "idx_preparations_fingerprint_plain_trgm" ON "public"."preparations" USING "gin" ("fingerprint_plain" "public"."gin_trgm_ops");



CREATE OR REPLACE TRIGGER "after_dish_component_deleted_trigger" AFTER DELETE ON "public"."dish_components" REFERENCING OLD TABLE AS "old_table" FOR EACH STATEMENT EXECUTE FUNCTION "public"."process_deleted_ingredients"();



CREATE OR REPLACE TRIGGER "after_preparation_component_deleted_trigger" AFTER DELETE ON "public"."preparation_components" REFERENCING OLD TABLE AS "old_table" FOR EACH STATEMENT EXECUTE FUNCTION "public"."process_deleted_ingredients"();



CREATE OR REPLACE TRIGGER "delete_dish_and_orphaned_components_trigger" AFTER DELETE ON "public"."dishes" FOR EACH ROW EXECUTE FUNCTION "public"."delete_dish_and_orphaned_components_trigger_fn"();



CREATE OR REPLACE TRIGGER "delete_preparation_and_orphaned_components_trigger" AFTER DELETE ON "public"."preparations" FOR EACH ROW EXECUTE FUNCTION "public"."delete_preparation_and_orphaned_components_trigger_fn"();



CREATE OR REPLACE TRIGGER "enforce_unit_constraint" BEFORE INSERT OR UPDATE ON "public"."dish_components" FOR EACH ROW EXECUTE FUNCTION "public"."check_unit_for_preparations"();



CREATE OR REPLACE TRIGGER "enforce_unit_constraint" BEFORE INSERT OR UPDATE ON "public"."preparation_components" FOR EACH ROW EXECUTE FUNCTION "public"."check_unit_for_preparations"();



CREATE OR REPLACE TRIGGER "handle_dish_components_times" BEFORE INSERT OR UPDATE ON "public"."dish_components" FOR EACH ROW EXECUTE FUNCTION "public"."handle_times"();



CREATE OR REPLACE TRIGGER "handle_dishes_times" BEFORE INSERT OR UPDATE ON "public"."dishes" FOR EACH ROW EXECUTE FUNCTION "public"."handle_times"();



CREATE OR REPLACE TRIGGER "handle_ingredients_times" BEFORE INSERT OR UPDATE ON "public"."ingredients" FOR EACH ROW EXECUTE FUNCTION "public"."handle_times"();



CREATE OR REPLACE TRIGGER "handle_preparation_ingredients_times" BEFORE INSERT OR UPDATE ON "public"."preparation_components" FOR EACH ROW EXECUTE FUNCTION "public"."handle_times"();



CREATE OR REPLACE TRIGGER "handle_preparations_times" BEFORE INSERT OR UPDATE ON "public"."preparations" FOR EACH ROW EXECUTE FUNCTION "public"."handle_times"();



CREATE OR REPLACE TRIGGER "recipe-image-dishes" AFTER DELETE OR UPDATE ON "public"."dishes" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://roa-api-515418725737.us-central1.run.app/webhook', 'POST', '{"Content-type":"application/json","X-Supabase-Signature":"roa-supabase-webhook-secret"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "recipe-image-preparations" AFTER DELETE OR UPDATE ON "public"."preparations" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://roa-api-515418725737.us-central1.run.app/webhook', 'POST', '{"Content-type":"application/json","X-Supabase-Signature":"roa-supabase-webhook-secret"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "trg_components_update_fingerprint" AFTER INSERT OR DELETE OR UPDATE ON "public"."preparation_components" FOR EACH ROW EXECUTE FUNCTION "public"."tg_components_update_fingerprint"();



CREATE OR REPLACE TRIGGER "trg_enforce_one_user_per_personal_kitchen" BEFORE INSERT ON "public"."kitchen_users" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_one_user_per_personal_kitchen"();



CREATE OR REPLACE TRIGGER "trg_preparations_set_fingerprint" AFTER INSERT OR UPDATE ON "public"."preparations" FOR EACH ROW EXECUTE FUNCTION "public"."tg_preparations_set_fingerprint"();



CREATE OR REPLACE TRIGGER "trg_prevent_prep_cycle" BEFORE INSERT OR UPDATE ON "public"."preparation_components" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_preparation_cycle"();



ALTER TABLE ONLY "public"."dish_components"
    ADD CONSTRAINT "dish_ingredients_dish_id_fkey" FOREIGN KEY ("dish_id") REFERENCES "public"."dishes"("dish_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dishes"
    ADD CONSTRAINT "dishes_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dishes"
    ADD CONSTRAINT "dishes_serving_unit_fkey" FOREIGN KEY ("serving_unit_id") REFERENCES "public"."units"("unit_id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."dish_components"
    ADD CONSTRAINT "fk_components_dish" FOREIGN KEY ("dish_id") REFERENCES "public"."dishes"("dish_id");



ALTER TABLE ONLY "public"."dish_components"
    ADD CONSTRAINT "fk_components_ing" FOREIGN KEY ("ingredient_id") REFERENCES "public"."ingredients"("ingredient_id");



ALTER TABLE ONLY "public"."dish_components"
    ADD CONSTRAINT "fk_components_unit" FOREIGN KEY ("unit_id") REFERENCES "public"."units"("unit_id");



ALTER TABLE ONLY "public"."dishes"
    ADD CONSTRAINT "fk_dishes_unit" FOREIGN KEY ("serving_unit_id") REFERENCES "public"."units"("unit_id");



ALTER TABLE ONLY "public"."preparation_components"
    ADD CONSTRAINT "fk_prep_ingredients_ing" FOREIGN KEY ("ingredient_id") REFERENCES "public"."ingredients"("ingredient_id");



ALTER TABLE ONLY "public"."preparation_components"
    ADD CONSTRAINT "fk_prep_ingredients_prep" FOREIGN KEY ("preparation_id") REFERENCES "public"."preparations"("preparation_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."preparation_components"
    ADD CONSTRAINT "fk_prep_ingredients_unit" FOREIGN KEY ("unit_id") REFERENCES "public"."units"("unit_id");



ALTER TABLE ONLY "public"."ingredients"
    ADD CONSTRAINT "ingredients_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kitchen_invites"
    ADD CONSTRAINT "kitchen_invites_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kitchen_invites"
    ADD CONSTRAINT "kitchen_invites_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kitchen_users"
    ADD CONSTRAINT "kitchen_users_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kitchen_users"
    ADD CONSTRAINT "kitchen_users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."menu_section"
    ADD CONSTRAINT "menu_section_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "public"."kitchen"("kitchen_id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."preparation_components"
    ADD CONSTRAINT "preparation_ingredients_ingredient_id_fkey" FOREIGN KEY ("ingredient_id") REFERENCES "public"."ingredients"("ingredient_id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."preparation_components"
    ADD CONSTRAINT "preparation_ingredients_preparation_id_fkey" FOREIGN KEY ("preparation_id") REFERENCES "public"."ingredients"("ingredient_id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."preparation_components"
    ADD CONSTRAINT "preparation_ingredients_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."units"("unit_id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."preparations"
    ADD CONSTRAINT "preparations_preparation_id_fkey" FOREIGN KEY ("preparation_id") REFERENCES "public"."ingredients"("ingredient_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dish_components"
    ADD CONSTRAINT "recipe_ingredients_ingredient_id_fkey" FOREIGN KEY ("ingredient_id") REFERENCES "public"."ingredients"("ingredient_id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."dish_components"
    ADD CONSTRAINT "recipe_ingredients_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."units"("unit_id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."dishes"
    ADD CONSTRAINT "recipe_menu_section_id_fkey" FOREIGN KEY ("menu_section_id") REFERENCES "public"."menu_section"("menu_section_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can update kitchen names" ON "public"."kitchen" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."kitchen_users"
  WHERE (("kitchen_users"."user_id" = "auth"."uid"()) AND ("kitchen_users"."is_admin" = true) AND ("kitchen_users"."kitchen_id" = "kitchen"."kitchen_id")))));



CREATE POLICY "Allow admin to add users to their kitchen" ON "public"."kitchen_users" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_user_kitchen_admin"("auth"."uid"(), "kitchen_id"));



CREATE POLICY "Allow admin to remove other users from their kitchen" ON "public"."kitchen_users" FOR DELETE TO "authenticated" USING (("public"."is_user_kitchen_admin"("auth"."uid"(), "kitchen_id") AND ("user_id" <> "auth"."uid"())));



CREATE POLICY "Allow authenticated users to delete their kitchens where name m" ON "public"."kitchen" FOR DELETE TO "authenticated" USING (("public"."is_user_kitchen_member"("auth"."uid"(), "kitchen_id") AND ("name" = ( SELECT "auth"."email"() AS "email"))));



CREATE POLICY "Allow authenticated users to insert kitchens" ON "public"."kitchen" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to select from units" ON "public"."units" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to select languages" ON "public"."languages" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to select their kitchens" ON "public"."kitchen" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."kitchen_id" = "kitchen"."kitchen_id") AND ("ku"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Allow authenticated users to update their kitchens where name m" ON "public"."kitchen" FOR UPDATE TO "authenticated" USING (("public"."is_user_kitchen_member"("auth"."uid"(), "kitchen_id") AND ("name" = ( SELECT "auth"."email"() AS "email"))));



CREATE POLICY "Allow user to leave a kitchen (safeguarded against last admin l" ON "public"."kitchen_users" FOR DELETE TO "authenticated" USING ((("user_id" = "auth"."uid"()) AND (NOT (("is_admin" = true) AND ("public"."count_kitchen_admins"("kitchen_id") = 1)))));



CREATE POLICY "Allow users to see all members in their kitchens" ON "public"."kitchen_users" FOR SELECT TO "authenticated" USING ("public"."is_user_kitchen_member"("auth"."uid"(), "kitchen_id"));



CREATE POLICY "Enable delete access for the user based on their id" ON "public"."users" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Enable insert access for authenticated users" ON "public"."users" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Enable read access for all users" ON "public"."users" FOR SELECT USING (true);



CREATE POLICY "Enable update access for the user based on their id" ON "public"."users" FOR UPDATE WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Enable update for kitchen admins or self (safeguarded against n" ON "public"."kitchen_users" FOR UPDATE TO "authenticated" USING (("public"."is_user_kitchen_admin"("auth"."uid"(), "kitchen_id") OR ("user_id" = "auth"."uid"()))) WITH CHECK (("public"."count_kitchen_admins"("kitchen_id") >= 1));



CREATE POLICY "Kitchen admins can create invites for their kitchens" ON "public"."kitchen_invites" FOR INSERT TO "authenticated" WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."kitchen_id" = "kitchen_invites"."kitchen_id") AND ("ku"."user_id" = "auth"."uid"()) AND ("ku"."is_admin" = true)))) AND ("created_by" = "auth"."uid"())));



CREATE POLICY "Kitchen admins can update invites for their kitchens" ON "public"."kitchen_invites" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."kitchen_id" = "kitchen_invites"."kitchen_id") AND ("ku"."user_id" = "auth"."uid"()) AND ("ku"."is_admin" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."kitchen_id" = "kitchen_invites"."kitchen_id") AND ("ku"."user_id" = "auth"."uid"()) AND ("ku"."is_admin" = true)))));



CREATE POLICY "Kitchen admins can view invites for their kitchens" ON "public"."kitchen_invites" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."kitchen_id" = "kitchen_invites"."kitchen_id") AND ("ku"."user_id" = "auth"."uid"()) AND ("ku"."is_admin" = true)))));



ALTER TABLE "public"."dish_components" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "dish_components_delete" ON "public"."dish_components" FOR DELETE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "dish_components"."ingredient_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



CREATE POLICY "dish_components_insert" ON "public"."dish_components" FOR INSERT WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "dish_components"."ingredient_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



CREATE POLICY "dish_components_select" ON "public"."dish_components" FOR SELECT USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "dish_components"."ingredient_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



CREATE POLICY "dish_components_update" ON "public"."dish_components" FOR UPDATE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "dish_components"."ingredient_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id")))))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "dish_components"."ingredient_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



ALTER TABLE "public"."dishes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "dishes_delete" ON "public"."dishes" FOR DELETE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "dishes"."kitchen_id"))))));



CREATE POLICY "dishes_insert" ON "public"."dishes" FOR INSERT WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "dishes"."kitchen_id"))))));



CREATE POLICY "dishes_select" ON "public"."dishes" FOR SELECT USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "dishes"."kitchen_id"))))));



CREATE POLICY "dishes_update" ON "public"."dishes" FOR UPDATE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "dishes"."kitchen_id")))))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "dishes"."kitchen_id"))))));



ALTER TABLE "public"."ingredients" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ingredients_delete" ON "public"."ingredients" FOR DELETE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "ingredients"."kitchen_id"))))));



CREATE POLICY "ingredients_insert" ON "public"."ingredients" FOR INSERT WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "ingredients"."kitchen_id"))))));



CREATE POLICY "ingredients_select" ON "public"."ingredients" FOR SELECT USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "ingredients"."kitchen_id"))))));



CREATE POLICY "ingredients_update" ON "public"."ingredients" FOR UPDATE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "ingredients"."kitchen_id")))))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "ingredients"."kitchen_id"))))));



ALTER TABLE "public"."kitchen" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kitchen_invites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kitchen_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."languages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."menu_section" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "menu_section_delete" ON "public"."menu_section" FOR DELETE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "menu_section"."kitchen_id"))))));



CREATE POLICY "menu_section_insert" ON "public"."menu_section" FOR INSERT WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "menu_section"."kitchen_id"))))));



CREATE POLICY "menu_section_select" ON "public"."menu_section" FOR SELECT USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "menu_section"."kitchen_id"))))));



CREATE POLICY "menu_section_update" ON "public"."menu_section" FOR UPDATE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "menu_section"."kitchen_id")))))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."kitchen_users" "ku"
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "menu_section"."kitchen_id"))))));



ALTER TABLE "public"."preparation_components" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "preparation_components_delete" ON "public"."preparation_components" FOR DELETE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "p" ON (("p"."ingredient_id" = "preparation_components"."preparation_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "p"."kitchen_id")))) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "preparation_components"."ingredient_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



CREATE POLICY "preparation_components_insert" ON "public"."preparation_components" FOR INSERT WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "p" ON (("p"."ingredient_id" = "preparation_components"."preparation_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "p"."kitchen_id")))) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "preparation_components"."ingredient_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



CREATE POLICY "preparation_components_select" ON "public"."preparation_components" FOR SELECT USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "p" ON (("p"."ingredient_id" = "preparation_components"."preparation_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "p"."kitchen_id")))) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "preparation_components"."ingredient_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



CREATE POLICY "preparation_components_update" ON "public"."preparation_components" FOR UPDATE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "p" ON (("p"."ingredient_id" = "preparation_components"."preparation_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "p"."kitchen_id")))) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "preparation_components"."ingredient_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id")))))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "p" ON (("p"."ingredient_id" = "preparation_components"."preparation_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "p"."kitchen_id")))) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "preparation_components"."ingredient_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



ALTER TABLE "public"."preparations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "preparations_delete" ON "public"."preparations" FOR DELETE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "preparations"."preparation_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



CREATE POLICY "preparations_insert" ON "public"."preparations" FOR INSERT WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "preparations"."preparation_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



CREATE POLICY "preparations_select" ON "public"."preparations" FOR SELECT USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "preparations"."preparation_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



CREATE POLICY "preparations_update" ON "public"."preparations" FOR UPDATE USING ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "preparations"."preparation_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id")))))) WITH CHECK ((("auth"."uid"() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM ("public"."kitchen_users" "ku"
     JOIN "public"."ingredients" "i" ON (("i"."ingredient_id" = "preparations"."preparation_id")))
  WHERE (("ku"."user_id" = "auth"."uid"()) AND ("ku"."kitchen_id" = "i"."kitchen_id"))))));



ALTER TABLE "public"."units" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."dish_components";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."dishes";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."ingredients";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."kitchen";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."kitchen_users";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."menu_section";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."preparation_components";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."preparations";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "service_role";



































































































































































































































































































GRANT ALL ON FUNCTION "public"."after_dish_component_deleted_trigger_fn"() TO "anon";
GRANT ALL ON FUNCTION "public"."after_dish_component_deleted_trigger_fn"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."after_dish_component_deleted_trigger_fn"() TO "service_role";



GRANT ALL ON FUNCTION "public"."after_preparation_component_deleted_trigger_fn"() TO "anon";
GRANT ALL ON FUNCTION "public"."after_preparation_component_deleted_trigger_fn"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."after_preparation_component_deleted_trigger_fn"() TO "service_role";



GRANT ALL ON FUNCTION "public"."check_unit_for_preparations"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_unit_for_preparations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_unit_for_preparations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."count_kitchen_admins"("p_kitchen_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."count_kitchen_admins"("p_kitchen_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."count_kitchen_admins"("p_kitchen_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_personal_kitchen"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_personal_kitchen"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_personal_kitchen"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_dish"("p_dish_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_dish"("p_dish_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_dish"("p_dish_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_dish_and_orphaned_components_trigger_fn"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_dish_and_orphaned_components_trigger_fn"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_dish_and_orphaned_components_trigger_fn"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_preparation"("p_preparation_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_preparation"("p_preparation_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_preparation"("p_preparation_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_preparation_and_orphaned_components_trigger_fn"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_preparation_and_orphaned_components_trigger_fn"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_preparation_and_orphaned_components_trigger_fn"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_user_kitchen"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user_kitchen"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user_kitchen"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_one_user_per_personal_kitchen"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_one_user_per_personal_kitchen"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_one_user_per_personal_kitchen"() TO "service_role";



GRANT ALL ON FUNCTION "public"."find_ingredients_by_slug"("_slugs" "text"[], "_kitchen" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."find_ingredients_by_slug"("_slugs" "text"[], "_kitchen" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_ingredients_by_slug"("_slugs" "text"[], "_kitchen" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."find_ingredients_fuzzy"("_slugs" "text"[], "_kitchen" "uuid", "_threshold" real) TO "anon";
GRANT ALL ON FUNCTION "public"."find_ingredients_fuzzy"("_slugs" "text"[], "_kitchen" "uuid", "_threshold" real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_ingredients_fuzzy"("_slugs" "text"[], "_kitchen" "uuid", "_threshold" real) TO "service_role";



GRANT ALL ON FUNCTION "public"."find_preparations_by_fingerprints"("_fps" "uuid"[], "_kitchen" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."find_preparations_by_fingerprints"("_fps" "uuid"[], "_kitchen" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_preparations_by_fingerprints"("_fps" "uuid"[], "_kitchen" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."find_preparations_by_plain"("_names" "text"[], "_kitchen" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."find_preparations_by_plain"("_names" "text"[], "_kitchen" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_preparations_by_plain"("_names" "text"[], "_kitchen" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."fp_namespace"() TO "anon";
GRANT ALL ON FUNCTION "public"."fp_namespace"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fp_namespace"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_components_for_preparations"("_prep_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_components_for_preparations"("_prep_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_components_for_preparations"("_prep_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_ingredient_deletion_check"("p_ingredient_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."handle_ingredient_deletion_check"("p_ingredient_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_ingredient_deletion_check"("p_ingredient_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_times"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_times"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_times"() TO "service_role";



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



GRANT ALL ON FUNCTION "public"."prevent_preparation_cycle"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_preparation_cycle"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_preparation_cycle"() TO "service_role";



GRANT ALL ON FUNCTION "public"."process_deleted_ingredients"() TO "anon";
GRANT ALL ON FUNCTION "public"."process_deleted_ingredients"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_deleted_ingredients"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "postgres";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "anon";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "service_role";



GRANT ALL ON FUNCTION "public"."show_limit"() TO "postgres";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."slug_simple"("p_input" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."slug_simple"("p_input" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."slug_simple"("p_input" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_components_update_fingerprint"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_components_update_fingerprint"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_components_update_fingerprint"() TO "service_role";



GRANT ALL ON FUNCTION "public"."tg_preparations_set_fingerprint"() TO "anon";
GRANT ALL ON FUNCTION "public"."tg_preparations_set_fingerprint"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."tg_preparations_set_fingerprint"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_kitchen_name_on_email_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_kitchen_name_on_email_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_kitchen_name_on_email_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_preparation_fingerprint"("_prep_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."update_preparation_fingerprint"("_prep_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_preparation_fingerprint"("_prep_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."uuid_generate_v5"("namespace" "uuid", "name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."uuid_generate_v5"("namespace" "uuid", "name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."uuid_generate_v5"("namespace" "uuid", "name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."uuid_ns_dns"() TO "anon";
GRANT ALL ON FUNCTION "public"."uuid_ns_dns"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."uuid_ns_dns"() TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "service_role";






























GRANT ALL ON TABLE "public"."dish_components" TO "anon";
GRANT ALL ON TABLE "public"."dish_components" TO "authenticated";
GRANT ALL ON TABLE "public"."dish_components" TO "service_role";



GRANT ALL ON TABLE "public"."dishes" TO "anon";
GRANT ALL ON TABLE "public"."dishes" TO "authenticated";
GRANT ALL ON TABLE "public"."dishes" TO "service_role";



GRANT ALL ON TABLE "public"."ingredients" TO "anon";
GRANT ALL ON TABLE "public"."ingredients" TO "authenticated";
GRANT ALL ON TABLE "public"."ingredients" TO "service_role";



GRANT ALL ON TABLE "public"."kitchen" TO "anon";
GRANT ALL ON TABLE "public"."kitchen" TO "authenticated";
GRANT ALL ON TABLE "public"."kitchen" TO "service_role";



GRANT ALL ON TABLE "public"."kitchen_invites" TO "anon";
GRANT ALL ON TABLE "public"."kitchen_invites" TO "authenticated";
GRANT ALL ON TABLE "public"."kitchen_invites" TO "service_role";



GRANT ALL ON TABLE "public"."kitchen_users" TO "anon";
GRANT ALL ON TABLE "public"."kitchen_users" TO "authenticated";
GRANT ALL ON TABLE "public"."kitchen_users" TO "service_role";



GRANT ALL ON TABLE "public"."languages" TO "anon";
GRANT ALL ON TABLE "public"."languages" TO "authenticated";
GRANT ALL ON TABLE "public"."languages" TO "service_role";



GRANT ALL ON TABLE "public"."menu_section" TO "anon";
GRANT ALL ON TABLE "public"."menu_section" TO "authenticated";
GRANT ALL ON TABLE "public"."menu_section" TO "service_role";



GRANT ALL ON TABLE "public"."preparation_components" TO "anon";
GRANT ALL ON TABLE "public"."preparation_components" TO "authenticated";
GRANT ALL ON TABLE "public"."preparation_components" TO "service_role";



GRANT ALL ON TABLE "public"."preparations" TO "anon";
GRANT ALL ON TABLE "public"."preparations" TO "authenticated";
GRANT ALL ON TABLE "public"."preparations" TO "service_role";



GRANT ALL ON TABLE "public"."units" TO "anon";
GRANT ALL ON TABLE "public"."units" TO "authenticated";
GRANT ALL ON TABLE "public"."units" TO "service_role";



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

