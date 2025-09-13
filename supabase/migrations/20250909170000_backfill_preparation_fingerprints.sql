-- Backfill fingerprints for all existing preparation recipes
-- Recomputes fingerprint and fingerprint_plain for every 'Preparation' row

BEGIN;

DO $$
DECLARE
  r_id uuid;
BEGIN
  FOR r_id IN
    SELECT recipe_id
    FROM public.recipes
    WHERE recipe_type = 'Preparation'
  LOOP
    PERFORM public.update_preparation_fingerprint(r_id);
  END LOOP;
END $$;

COMMIT;


