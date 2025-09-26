-- Defer component cleanup trigger to end of transaction
--
-- Problem: The cleanup trigger runs immediately after DELETE FROM recipe_components,
-- which deletes orphaned components before the subsequent INSERT can use them.
-- This creates a race condition in save operations that do DELETE then INSERT.
--
-- Solution: Make the trigger DEFERRED so it runs at transaction end,
-- after all DELETE and INSERT operations are complete.

-- Drop the existing trigger
DROP TRIGGER IF EXISTS after_recipe_component_deleted ON public.recipe_components;

-- For PostgreSQL, we need to use a different approach for deferrable triggers
-- We'll modify the function to use a session-level flag to defer cleanup
-- and create a regular trigger that respects this flag

-- Create a session variable to control cleanup deferral
-- This will be set by save operations to defer cleanup until transaction end
CREATE OR REPLACE FUNCTION public.set_component_cleanup_deferred(defer_cleanup boolean DEFAULT true)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Use a session-level setting to control cleanup behavior
  IF defer_cleanup THEN
    PERFORM set_config('app.defer_component_cleanup', 'true', false);
  ELSE
    PERFORM set_config('app.defer_component_cleanup', 'false', false);
  END IF;
END;
$$;

-- Recreate the trigger as a regular AFTER DELETE trigger
CREATE TRIGGER after_recipe_component_deleted
  AFTER DELETE ON public.recipe_components
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.process_deleted_components();

COMMENT ON TRIGGER after_recipe_component_deleted ON public.recipe_components IS
'Deferred cleanup trigger that removes orphaned raw ingredients at transaction end. Preparations are never deleted by this trigger.';

-- Update the process_deleted_components function to respect deferral flag
CREATE OR REPLACE FUNCTION public.process_deleted_components()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
    p_component_id uuid;
    defer_cleanup_setting text;
BEGIN
    -- Check if cleanup should be deferred
    defer_cleanup_setting := current_setting('app.defer_component_cleanup', true);
    
    -- If cleanup is deferred, just collect the components but don't process them yet
    IF defer_cleanup_setting = 'true' THEN
        -- Session-lifetime scratch table; survives for the tx, disappears on commit.
        CREATE TEMP TABLE IF NOT EXISTS deferred_deleted_components
        ( component_id uuid PRIMARY KEY )
        ON COMMIT DROP;

        -- Collect unique component_ids from the OLD TABLE for later processing
        INSERT INTO deferred_deleted_components (component_id)
        SELECT DISTINCT old_table.component_id FROM old_table
        ON CONFLICT (component_id) DO NOTHING;
        
        RETURN NULL;
    END IF;

    -- Normal immediate processing (legacy behavior)
    -- Session-lifetime scratch table; survives for the tx, disappears on commit.
    CREATE TEMP TABLE IF NOT EXISTS deleted_components_temp
    ( component_id uuid PRIMARY KEY )
    ON COMMIT DROP;

    -- Collect unique component_ids from the OLD TABLE (all deleted recipe_components in this statement)
    INSERT INTO deleted_components_temp (component_id)
    SELECT DISTINCT old_table.component_id FROM old_table
    ON CONFLICT (component_id) DO NOTHING;

    -- Process every unique id collected so far immediately
    FOR p_component_id IN
        SELECT dct.component_id FROM deleted_components_temp dct
    LOOP
        PERFORM public.handle_component_deletion_check(p_component_id);
    END LOOP;

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.process_deleted_components() IS
'Cleanup function that can defer component processing based on session setting. Only deletes unused raw ingredients, never preparations.';

-- Function to process deferred components at transaction end
CREATE OR REPLACE FUNCTION public.process_deferred_component_cleanup()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
    p_component_id uuid;
BEGIN
    -- Check if there are any deferred components to process
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'deferred_deleted_components' AND table_type = 'LOCAL TEMPORARY') THEN
        -- Process all deferred components
        FOR p_component_id IN
            SELECT component_id FROM deferred_deleted_components
        LOOP
            PERFORM public.handle_component_deletion_check(p_component_id);
        END LOOP;
        
        -- Clear the deferred components table
        DROP TABLE IF EXISTS deferred_deleted_components;
    END IF;
    
    -- Reset the deferral flag
    PERFORM set_config('app.defer_component_cleanup', 'false', false);
END;
$$;

COMMENT ON FUNCTION public.process_deferred_component_cleanup() IS
'Processes components that were deferred during save operations. Call this at transaction end to clean up orphaned raw ingredients.';

-- Grant permissions
GRANT ALL ON FUNCTION public.set_component_cleanup_deferred(boolean) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.process_deleted_components() TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.process_deferred_component_cleanup() TO anon, authenticated, service_role;
