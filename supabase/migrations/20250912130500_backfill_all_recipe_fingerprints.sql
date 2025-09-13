-- Backfill fingerprints for all recipes (Dish + Preparation)
-- Idempotent: recomputes using generic updater

BEGIN;

DO $$
DECLARE
  r_id uuid;
BEGIN
  FOR r_id IN
    SELECT recipe_id
    FROM public.recipes
  LOOP
    PERFORM public.update_recipe_fingerprint(r_id);
  END LOOP;
END $$;

COMMIT;


