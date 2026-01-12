
ALTER TABLE public.recipe_components
ADD COLUMN IF NOT EXISTS kitchen_id uuid;

UPDATE public.recipe_components rc
SET kitchen_id = r.kitchen_id
FROM public.recipes r
WHERE r.recipe_id = rc.recipe_id
  AND rc.kitchen_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_recipes_recipe_id_kitchen_id_unique
ON public.recipes (recipe_id, kitchen_id);

ALTER TABLE public.recipe_components
ALTER COLUMN kitchen_id SET NOT NULL;

CREATE OR REPLACE FUNCTION public.tg_set_recipe_components_kitchen_id()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $$
DECLARE
  v_kitchen_id uuid;
BEGIN
  SELECT r.kitchen_id
  INTO v_kitchen_id
  FROM public.recipes r
  WHERE r.recipe_id = NEW.recipe_id;

  IF v_kitchen_id IS NULL THEN
    RAISE EXCEPTION 'Recipe % not found; cannot derive kitchen_id for recipe_components', NEW.recipe_id;
  END IF;

  NEW.kitchen_id := v_kitchen_id;
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.tg_set_recipe_components_kitchen_id() OWNER TO postgres;

DROP TRIGGER IF EXISTS trg_set_recipe_components_kitchen_id ON public.recipe_components;
CREATE TRIGGER trg_set_recipe_components_kitchen_id
BEFORE INSERT OR UPDATE OF recipe_id ON public.recipe_components
FOR EACH ROW
EXECUTE FUNCTION public.tg_set_recipe_components_kitchen_id();

ALTER TABLE public.recipe_components
DROP CONSTRAINT IF EXISTS recipe_components_recipe_id_kitchen_id_fkey;

ALTER TABLE public.recipe_components
DROP CONSTRAINT IF EXISTS recipe_components_recipe_id_fkey;

ALTER TABLE public.recipe_components
ADD CONSTRAINT recipe_components_recipe_id_kitchen_id_fkey
FOREIGN KEY (recipe_id, kitchen_id)
REFERENCES public.recipes (recipe_id, kitchen_id)
ON UPDATE CASCADE
ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_recipe_components_kitchen_id
ON public.recipe_components USING btree (kitchen_id);

CREATE INDEX IF NOT EXISTS idx_recipe_components_kitchen_id_recipe_id
ON public.recipe_components USING btree (kitchen_id, recipe_id);

ALTER TABLE public.recipe_components ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'recipe_components'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.recipe_components', pol.policyname);
  END LOOP;
END
$$;

CREATE POLICY "Parser service can read all recipe components"
ON public.recipe_components
FOR SELECT
TO service_role
USING (true);

CREATE POLICY recipe_components_select
ON public.recipe_components
FOR SELECT
TO authenticated
USING (
  public.is_user_kitchen_member((SELECT auth.uid()), kitchen_id)
);

CREATE POLICY recipe_components_insert
ON public.recipe_components
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.recipes r
    WHERE r.recipe_id = recipe_components.recipe_id
      AND public.is_user_kitchen_member((SELECT auth.uid()), r.kitchen_id)
      AND public.is_kitchen_write_allowed(r.kitchen_id)
  )
);

CREATE POLICY recipe_components_update
ON public.recipe_components
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.recipes r
    WHERE r.recipe_id = recipe_components.recipe_id
      AND public.is_user_kitchen_member((SELECT auth.uid()), r.kitchen_id)
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.recipes r
    WHERE r.recipe_id = recipe_components.recipe_id
      AND public.is_user_kitchen_member((SELECT auth.uid()), r.kitchen_id)
      AND public.is_kitchen_write_allowed(r.kitchen_id)
  )
);

CREATE POLICY recipe_components_delete
ON public.recipe_components
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.recipes r
    WHERE r.recipe_id = recipe_components.recipe_id
      AND public.is_user_kitchen_member((SELECT auth.uid()), r.kitchen_id)
      AND public.is_kitchen_write_allowed(r.kitchen_id)
  )
);
