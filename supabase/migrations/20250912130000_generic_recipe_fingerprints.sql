-- Generic recipe fingerprinting (Dish + Preparation) and lookup RPCs
-- Idempotent: drop/replace functions and triggers; safe on re-run

BEGIN;

-- BTree index for exact fingerprint lookup
CREATE INDEX IF NOT EXISTS idx_recipes_fingerprint
    ON public.recipes USING btree (fingerprint);

-- Trigram index for plain fingerprint fuzzy lookup
DROP INDEX IF EXISTS idx_recipes_fingerprint_plain_trgm;
CREATE INDEX IF NOT EXISTS idx_recipes_fingerprint_plain_trgm
    ON public.recipes USING gin (fingerprint_plain extensions.gin_trgm_ops);

-- 1) Generic Unicode-safe fingerprint updater (applies to ALL recipes)
DROP FUNCTION IF EXISTS public.update_recipe_fingerprint(uuid);
CREATE OR REPLACE FUNCTION public.update_recipe_fingerprint(_recipe_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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

-- 2) Trigger helpers
-- Drop existing triggers first to release dependency, then replace functions
DROP TRIGGER IF EXISTS trg_recipe_components_update_fingerprint ON public.recipe_components;
DROP TRIGGER IF EXISTS trg_recipes_set_fingerprint ON public.recipes;

-- Components table changes → refresh parent recipe fingerprint
DROP FUNCTION IF EXISTS public.tg_recipe_components_update_fingerprint();
CREATE OR REPLACE FUNCTION public.tg_recipe_components_update_fingerprint()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
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

-- Recipes row changes (directions) → refresh fingerprint
DROP FUNCTION IF EXISTS public.tg_recipes_set_fingerprint();
CREATE OR REPLACE FUNCTION public.tg_recipes_set_fingerprint()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    PERFORM public.update_recipe_fingerprint(NEW.recipe_id);
    RETURN NEW;
END;
$$;

-- Attach triggers idempotently
CREATE TRIGGER trg_recipe_components_update_fingerprint
AFTER INSERT OR UPDATE OR DELETE ON public.recipe_components
FOR EACH ROW EXECUTE FUNCTION public.tg_recipe_components_update_fingerprint();

CREATE TRIGGER trg_recipes_set_fingerprint
AFTER INSERT OR UPDATE OF directions ON public.recipes
FOR EACH ROW EXECUTE FUNCTION public.tg_recipes_set_fingerprint();

-- 4) RPCs for lookups
-- Exact match by UUID fingerprints
DROP FUNCTION IF EXISTS public.find_recipes_by_fingerprints(uuid[], uuid);
CREATE OR REPLACE FUNCTION public.find_recipes_by_fingerprints(
  _fps uuid[],
  _kitchen uuid
)
RETURNS TABLE(fingerprint uuid, recipe_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT r.fingerprint, r.recipe_id
    FROM public.recipes r
   WHERE r.kitchen_id = _kitchen
     AND r.fingerprint IS NOT NULL
     AND r.fingerprint = ANY(_fps);
$$;

-- Fuzzy match by plain fingerprint string with configurable threshold
DROP FUNCTION IF EXISTS public.find_recipes_by_plain(text[], uuid, real);
CREATE OR REPLACE FUNCTION public.find_recipes_by_plain(
  _names text[],
  _kitchen uuid,
  _threshold real DEFAULT 0.75
)
RETURNS TABLE(fingerprint_plain text, recipe_id uuid, sim numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH q AS (
    SELECT unnest(_names) AS plain
  )
  SELECT r.fingerprint_plain,
         r.recipe_id,
         extensions.similarity(r.fingerprint_plain, q.plain) AS sim
    FROM q
    JOIN public.recipes r ON r.kitchen_id = _kitchen
   WHERE r.fingerprint_plain IS NOT NULL
     AND extensions.similarity(r.fingerprint_plain, q.plain) >= _threshold
   ORDER BY sim DESC;
$$;

GRANT EXECUTE ON FUNCTION public.find_recipes_by_fingerprints(uuid[], uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.find_recipes_by_plain(text[], uuid, real) TO anon, authenticated, service_role;

COMMIT;


