-- Unicode-safe preparation fingerprints and name-based ingredient fuzzy RPCs
-- Idempotent: functions are replaced if exist

BEGIN;

-- Fully deprecate slug-based helpers
-- Drop any dependent functional indexes first, then drop the functions
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'i'
      AND n.nspname = 'public'
      AND c.relname = 'idx_ingredients_name_slug_trgm'
  ) THEN
    EXECUTE 'DROP INDEX IF EXISTS public.idx_ingredients_name_slug_trgm';
  END IF;
END $$;

DROP FUNCTION IF EXISTS public.slug_simple(text);
DROP FUNCTION IF EXISTS public.find_ingredients_by_slug(text[], uuid);
DROP FUNCTION IF EXISTS public.find_ingredients_fuzzy(text[], uuid, real);

-- 1) Update preparation fingerprint builder to avoid slugging and preserve non-English chars
DROP FUNCTION IF EXISTS public.update_preparation_fingerprint(uuid);
CREATE OR REPLACE FUNCTION public.update_preparation_fingerprint(_recipe_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

-- 2) Name-based ingredient exact match (Unicode-safe)
DROP FUNCTION IF EXISTS public.find_ingredients_by_name_exact(text[], uuid);
CREATE OR REPLACE FUNCTION public.find_ingredients_by_name_exact(
  _names   text[],
  _kitchen uuid
)
RETURNS TABLE(input_name text, ingredient_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
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

-- 3) Name-based ingredient fuzzy match (Unicode-safe, top-1 per input)
DROP FUNCTION IF EXISTS public.find_ingredients_by_name_fuzzy(text[], uuid, real);
CREATE OR REPLACE FUNCTION public.find_ingredients_by_name_fuzzy(
  _names     text[],
  _kitchen   uuid,
  _threshold real DEFAULT 0.75
)
RETURNS TABLE(input_name text, ingredient_id uuid)
LANGUAGE sql STABLE
SET search_path = public
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

GRANT EXECUTE ON FUNCTION public.find_ingredients_by_name_exact(text[], uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.find_ingredients_by_name_fuzzy(text[], uuid, real) TO anon, authenticated, service_role;

COMMIT;


