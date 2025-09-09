-- Set search_path = '' for security on all public functions flagged by linter
-- Safe to run multiple times; guards on existence

BEGIN;

-- helper DO block template repeated per function

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'recipe_components_item_unit_guard'
      AND pg_get_function_identity_arguments(p.oid) = ''
  ) THEN
    EXECUTE $m$ALTER FUNCTION public.recipe_components_item_unit_guard() SET search_path TO ''$m$;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='get_components_for_recipes'
      AND pg_get_function_identity_arguments(p.oid)='uuid[]'
  ) THEN
    EXECUTE $m$ALTER FUNCTION public.get_components_for_recipes(uuid[]) SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='is_user_kitchen_member'
               AND pg_get_function_identity_arguments(p.oid)='uuid, uuid') THEN
    EXECUTE $m$ALTER FUNCTION public.is_user_kitchen_member(uuid, uuid) SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='is_user_kitchen_admin'
               AND pg_get_function_identity_arguments(p.oid)='uuid, uuid') THEN
    EXECUTE $m$ALTER FUNCTION public.is_user_kitchen_admin(uuid, uuid) SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='count_kitchen_admins'
               AND pg_get_function_identity_arguments(p.oid)='uuid') THEN
    EXECUTE $m$ALTER FUNCTION public.count_kitchen_admins(uuid) SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='enforce_one_user_per_personal_kitchen'
               AND pg_get_function_identity_arguments(p.oid)='') THEN
    EXECUTE $m$ALTER FUNCTION public.enforce_one_user_per_personal_kitchen() SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='handle_component_deletion_check'
               AND pg_get_function_identity_arguments(p.oid)='uuid') THEN
    EXECUTE $m$ALTER FUNCTION public.handle_component_deletion_check(uuid) SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='handle_ingredient_deletion_check'
               AND pg_get_function_identity_arguments(p.oid)='uuid') THEN
    EXECUTE $m$ALTER FUNCTION public.handle_ingredient_deletion_check(uuid) SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='process_deleted_components'
               AND pg_get_function_identity_arguments(p.oid)='') THEN
    EXECUTE $m$ALTER FUNCTION public.process_deleted_components() SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='check_unit_for_preparations'
               AND pg_get_function_identity_arguments(p.oid)='') THEN
    EXECUTE $m$ALTER FUNCTION public.check_unit_for_preparations() SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='find_preparations_by_plain'
               AND pg_get_function_identity_arguments(p.oid)='text[], uuid, real') THEN
    EXECUTE $m$ALTER FUNCTION public.find_preparations_by_plain(text[], uuid, real) SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='tg_recipe_components_update_fingerprint'
               AND pg_get_function_identity_arguments(p.oid)='') THEN
    EXECUTE $m$ALTER FUNCTION public.tg_recipe_components_update_fingerprint() SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='tg_recipes_set_fingerprint'
               AND pg_get_function_identity_arguments(p.oid)='') THEN
    EXECUTE $m$ALTER FUNCTION public.tg_recipes_set_fingerprint() SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='prevent_preparation_cycle'
               AND pg_get_function_identity_arguments(p.oid)='') THEN
    EXECUTE $m$ALTER FUNCTION public.prevent_preparation_cycle() SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='find_preparations_by_fingerprints'
               AND pg_get_function_identity_arguments(p.oid)='uuid[], uuid') THEN
    EXECUTE $m$ALTER FUNCTION public.find_preparations_by_fingerprints(uuid[], uuid) SET search_path TO ''$m$;
  END IF;
END $$;

-- There may be two overloads for update_preparation_fingerprint
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='update_preparation_fingerprint'
               AND pg_get_function_identity_arguments(p.oid)='uuid') THEN
    EXECUTE $m$ALTER FUNCTION public.update_preparation_fingerprint(uuid) SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='find_ingredients_by_name_exact'
               AND pg_get_function_identity_arguments(p.oid)='text[], uuid') THEN
    EXECUTE $m$ALTER FUNCTION public.find_ingredients_by_name_exact(text[], uuid) SET search_path TO ''$m$;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname='public' AND p.proname='find_ingredients_by_name_fuzzy'
               AND pg_get_function_identity_arguments(p.oid)='text[], uuid, real') THEN
    EXECUTE $m$ALTER FUNCTION public.find_ingredients_by_name_fuzzy(text[], uuid, real) SET search_path TO ''$m$;
  END IF;
END $$;

COMMIT;


