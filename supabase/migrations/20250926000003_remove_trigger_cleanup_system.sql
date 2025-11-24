-- Remove trigger-based orphan cleanup system completely
-- Replace with explicit delete_recipe RPC that handles orphan cleanup
--
-- This eliminates all race conditions by removing automatic triggers
-- and handling deletion + cleanup in a single, controlled RPC call.

-- 1. Drop all existing cleanup triggers
DROP TRIGGER IF EXISTS after_recipe_component_deleted ON public.recipe_components;

-- 2. Drop all existing cleanup functions
DROP FUNCTION IF EXISTS public.process_deleted_components();
DROP FUNCTION IF EXISTS public.process_deferred_component_cleanup();
DROP FUNCTION IF EXISTS public.set_component_cleanup_deferred(boolean);
DROP FUNCTION IF EXISTS public.handle_component_deletion_check(uuid);
DROP FUNCTION IF EXISTS public.handle_ingredient_deletion_check(uuid);

-- 3. Drop old recipe deletion functions
DROP FUNCTION IF EXISTS public.delete_recipe(uuid);
DROP FUNCTION IF EXISTS public.delete_dish(uuid);
DROP FUNCTION IF EXISTS public.delete_preparation(uuid);

-- 4. Create new comprehensive delete_recipe RPC
CREATE OR REPLACE FUNCTION public.delete_recipe(
  _recipe_id uuid,
  _kitchen_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
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

COMMENT ON FUNCTION public.delete_recipe(uuid, uuid) IS
'Deletes a recipe and automatically cleans up any orphaned raw ingredients. Preparations are never considered orphaned. Returns summary of deletion.';

-- 5. Grant permissions
GRANT ALL ON FUNCTION public.delete_recipe(uuid, uuid) TO anon, authenticated, service_role;
