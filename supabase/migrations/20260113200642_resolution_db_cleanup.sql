-- Resolution DB cleanup (updated):
-- - Treat recipes (Dishes + Preparations) identically for fingerprinting
-- - Consolidate redundant trigger paths
-- - Ensure fingerprints stay updated when:
--   * recipes change (directions / type)
--   * recipe_components change
--   * component names change

-- 1) Drop legacy triggers/functions (we are moving forward; no wrappers)
DROP TRIGGER IF EXISTS tg_recipe_components_update_fingerprint ON public.recipe_components;
DROP TRIGGER IF EXISTS trg_recipe_components_update_fingerprint ON public.recipe_components;
DROP TRIGGER IF EXISTS trg_recipes_set_fingerprint ON public.recipes;
DROP TRIGGER IF EXISTS trg_components_update_fingerprint ON public.components;

DROP FUNCTION IF EXISTS public.tg_components_update_fingerprint();
DROP FUNCTION IF EXISTS public.tg_preparations_set_fingerprint();
DROP FUNCTION IF EXISTS public.tg_recipe_components_update_fingerprint();
DROP FUNCTION IF EXISTS public.tg_recipes_set_fingerprint();
DROP FUNCTION IF EXISTS public.tg_component_name_update_recipe_fingerprints();

DROP FUNCTION IF EXISTS public.update_preparation_fingerprint(uuid);
DROP FUNCTION IF EXISTS public.update_recipe_fingerprint(uuid);

CREATE OR REPLACE FUNCTION public.update_recipe_fingerprint("_recipe_id" uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    _plain text;
    _fp    uuid;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.recipes r WHERE r.recipe_id = _recipe_id) THEN
        RETURN;
    END IF;

    SELECT COALESCE(
             string_agg(
               regexp_replace(lower(trim(c.name)), '\\s+', ' ', 'g'),
               ' ' ORDER BY regexp_replace(lower(trim(c.name)), '\\s+', ' ', 'g')
             ),
             'empty'
           )
           || '|'
           || regexp_replace(
             lower(array_to_string(coalesce(r.directions, ARRAY[]::text[]), ' ')),
             '[^[:alpha:]\\s]+',
             ' ',
             'g'
           )
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

ALTER FUNCTION public.update_recipe_fingerprint("_recipe_id" uuid) OWNER TO postgres;


-- 2) Consolidate trigger paths on recipe_components (keep a single trigger)
CREATE OR REPLACE FUNCTION public.tg_recipe_components_update_fingerprint() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
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

ALTER FUNCTION public.tg_recipe_components_update_fingerprint() OWNER TO postgres;

CREATE OR REPLACE TRIGGER trg_recipe_components_update_fingerprint
AFTER INSERT OR DELETE OR UPDATE
ON public.recipe_components
FOR EACH ROW
EXECUTE FUNCTION public.tg_recipe_components_update_fingerprint();


-- 3) Recipe-level trigger: update fingerprint when directions/type change
CREATE OR REPLACE FUNCTION public.tg_recipes_set_fingerprint() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  PERFORM public.update_recipe_fingerprint(NEW.recipe_id);
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.tg_recipes_set_fingerprint() OWNER TO postgres;

CREATE OR REPLACE TRIGGER trg_recipes_set_fingerprint
AFTER INSERT OR UPDATE OF directions, recipe_type
ON public.recipes
FOR EACH ROW
EXECUTE FUNCTION public.tg_recipes_set_fingerprint();


-- 4) Component name changes must update fingerprints for any recipes using that component
CREATE OR REPLACE FUNCTION public.tg_component_name_update_recipe_fingerprints() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  _rid uuid;
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  IF NEW.name IS NOT DISTINCT FROM OLD.name THEN
    RETURN NEW;
  END IF;

  FOR _rid IN
    SELECT DISTINCT rc.recipe_id
    FROM public.recipe_components rc
    WHERE rc.component_id = NEW.component_id
  LOOP
    PERFORM public.update_recipe_fingerprint(_rid);
  END LOOP;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.tg_component_name_update_recipe_fingerprints() OWNER TO postgres;

CREATE OR REPLACE TRIGGER trg_components_update_fingerprint
AFTER UPDATE OF name
ON public.components
FOR EACH ROW
EXECUTE FUNCTION public.tg_component_name_update_recipe_fingerprints();


-- 5) Keep pair integrity: both fingerprint columns are set together or both NULL
ALTER TABLE public.recipes
  DROP CONSTRAINT IF EXISTS recipes_fingerprints_pair;

ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_fingerprints_pair
  CHECK (
    (fingerprint IS NULL AND fingerprint_plain IS NULL)
    OR (fingerprint IS NOT NULL AND fingerprint_plain IS NOT NULL)
  );


-- 6) Recompute all recipe fingerprints once (best-effort)
DO $$
DECLARE
  _rid uuid;
BEGIN
  FOR _rid IN
    SELECT recipe_id FROM public.recipes
  LOOP
    PERFORM public.update_recipe_fingerprint(_rid);
  END LOOP;
END;
$$;
