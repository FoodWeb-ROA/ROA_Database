-- Unify recipe/preparation fingerprint RPCs and backfill fingerprints

-- Drop legacy RPCs now that we have unified ones
DROP FUNCTION IF EXISTS public.find_preparations_by_fingerprints(uuid[], uuid);
DROP FUNCTION IF EXISTS public.find_preparations_by_plain(text[], uuid, real);
DROP FUNCTION IF EXISTS public.find_recipes_by_fingerprints(uuid[], uuid);
DROP FUNCTION IF EXISTS public.find_recipes_by_plain(text[], uuid, real);

-- 1) Unified exact-match by fingerprint
CREATE OR REPLACE FUNCTION public.find_by_fingerprints(
  _fps uuid[],
  _kitchen uuid,
  _only_preparations boolean DEFAULT false
) RETURNS TABLE(
  fingerprint uuid,
  recipe_id uuid,
  component_id uuid,
  recipe_type public.recipe_type
) LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public'
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

-- 2) Unified fuzzy-match by fingerprint_plain
CREATE OR REPLACE FUNCTION public.find_by_plain(
  _names text[],
  _kitchen uuid,
  _threshold real DEFAULT 0.75,
  _only_preparations boolean DEFAULT false
) RETURNS TABLE(
  fingerprint_plain text,
  recipe_id uuid,
  component_id uuid,
  recipe_type public.recipe_type,
  sim numeric
) LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public'
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

-- 3) Backfill/refresh fingerprints so exact UUID matches work consistently
DO $$
DECLARE r RECORD;
BEGIN
  -- Recompute fingerprint_plain and fingerprint for all recipes to ensure consistency
  FOR r IN SELECT recipe_id FROM public.recipes LOOP
    PERFORM public.update_recipe_fingerprint(r.recipe_id);
  END LOOP;
END $$;

-- Grants
GRANT ALL ON FUNCTION public.find_by_fingerprints(_fps uuid[], _kitchen uuid, _only_preparations boolean) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.find_by_plain(_names text[], _kitchen uuid, _threshold real, _only_preparations boolean) TO anon, authenticated, service_role;

-- 4) Ensure required triggers still keep fingerprints in sync
--    (idempotent re-statement to avoid regressions)
CREATE OR REPLACE TRIGGER tg_recipe_components_update_fingerprint
AFTER INSERT OR DELETE OR UPDATE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.tg_components_update_fingerprint();

CREATE OR REPLACE TRIGGER trg_recipe_components_update_fingerprint
AFTER INSERT OR DELETE OR UPDATE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.tg_recipe_components_update_fingerprint();

CREATE OR REPLACE TRIGGER trg_recipes_set_fingerprint
AFTER INSERT OR UPDATE OF directions ON public.recipes
FOR EACH ROW EXECUTE FUNCTION public.tg_recipes_set_fingerprint();


