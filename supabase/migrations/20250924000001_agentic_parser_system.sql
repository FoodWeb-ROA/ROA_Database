-- Agentic Parser System Implementation: Database Infrastructure
-- This migration implements the database changes needed for the Agentic Parser System
-- as outlined in the Agentic Parser System Implementation Plan

-- =============================================================================
-- STEP 1: Create RLS policies for parser service access
-- =============================================================================

-- Enable RLS on new tables

-- Policy for recipes table (parser service needs read access to all preparations)
CREATE POLICY "Parser service can read all recipes" 
ON recipes FOR SELECT 
TO service_role 
USING (true);

-- Policy for recipe_components table (parser service needs read access for preparation structure)
CREATE POLICY "Parser service can read all recipe components" 
ON recipe_components FOR SELECT 
TO service_role 
USING (true);

-- =============================================================================
-- STEP 2: Function to get preparations for parser in required format
-- =============================================================================

CREATE OR REPLACE FUNCTION get_kitchen_preparations_for_parser(
    p_kitchen_id UUID
) 
RETURNS JSONB 
SET "search_path" TO ''
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', r.recipe_id::text,
            'recipe_name', r.recipe_name,
            'recipe_type', 'Preparation',
            'language', COALESCE(r.language, 'EN'),
            'components', COALESCE(comp_data.components, '[]'::jsonb),
            'directions', COALESCE(r.directions, '[]'::jsonb),
            'time_minutes', EXTRACT(EPOCH FROM COALESCE(r.time, '0 minutes'::interval)) / 60,
            'cook_notes', r.cook_notes,
            'serving_size_yield', r.serving_size_yield,
            'serving_or_yield_unit', r.serving_or_yield_unit
        )
    ) INTO result
    FROM public.recipes r
    LEFT JOIN LATERAL (
        SELECT jsonb_agg(
            CASE 
                WHEN prep_recipe.recipe_id IS NOT NULL THEN
                    jsonb_build_object(
                        'component_type', 'ComponentPreparation',
                        'recipe_id', prep_recipe.recipe_id::text,
                        'amount', rc.amount,
                        'unit', rc.unit,
                        'source', 'database'
                    )
                ELSE
                    jsonb_build_object(
                        'component_type', 'RawIngredient',
                        'name', c.name,
                        'amount', rc.amount,
                        'unit', rc.unit,
                        'item', rc.item
                    )
            END
        ) AS components
        FROM recipe_components rc
        JOIN components c ON rc.component_id = c.component_id
        LEFT JOIN public.recipes prep_recipe ON c.recipe_id = prep_recipe.recipe_id 
            AND prep_recipe.recipe_type = 'Preparation'
        WHERE rc.recipe_id = r.recipe_id
    ) comp_data ON true
    WHERE r.kitchen_id = p_kitchen_id 
    AND r.recipe_type = 'Preparation';
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- STEP 3: Cache invalidation notification system
-- =============================================================================

CREATE OR REPLACE FUNCTION notify_parser_cache_invalidation()
RETURNS TRIGGER AS $$
DECLARE
    kitchen_uuid UUID;
BEGIN
    -- Get kitchen_id from the affected record
    IF TG_TABLE_NAME = 'recipes' THEN
        kitchen_uuid := COALESCE(NEW.kitchen_id, OLD.kitchen_id);
    ELSIF TG_TABLE_NAME = 'recipe_components' THEN
        -- For recipe_components, we need to lookup the kitchen_id via recipes table
        SELECT kitchen_id INTO kitchen_uuid
        FROM recipes 
        WHERE recipe_id = COALESCE(NEW.recipe_id, OLD.recipe_id);
    END IF;
    
    -- Only notify for preparation-related changes
    IF TG_TABLE_NAME = 'recipes' AND COALESCE(NEW.recipe_type, OLD.recipe_type) = 'Preparation' THEN
        -- Notification will be picked up by parser service realtime listeners
        PERFORM pg_notify('parser_cache_invalidate', json_build_object(
            'table', TG_TABLE_NAME,
            'operation', TG_OP,
            'kitchen_id', kitchen_uuid,
            'recipe_id', COALESCE(NEW.recipe_id, OLD.recipe_id),
            'recipe_name', COALESCE(NEW.recipe_name, OLD.recipe_name),
            'timestamp', extract(epoch from now())
        )::text);
    ELSIF TG_TABLE_NAME = 'recipe_components' THEN
        -- All recipe_components changes could affect preparations
        -- Check if the affected recipe is a preparation
        IF EXISTS (
            SELECT 1 FROM recipes 
            WHERE recipe_id = COALESCE(NEW.recipe_id, OLD.recipe_id) 
            AND recipe_type = 'Preparation'
        ) THEN
            PERFORM pg_notify('parser_cache_invalidate', json_build_object(
                'table', TG_TABLE_NAME,
                'operation', TG_OP,
                'kitchen_id', kitchen_uuid,
                'recipe_id', COALESCE(NEW.recipe_id, OLD.recipe_id),
                'timestamp', extract(epoch from now())
            )::text);
        END IF;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
EXCEPTION 
    WHEN OTHERS THEN
        -- Log error but don't fail the transaction
        RAISE WARNING 'Cache invalidation notification failed: %', SQLERRM;
        RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- STEP 4: Create triggers for cache invalidation notifications
-- =============================================================================

-- Drop existing triggers if they exist to avoid conflicts
DROP TRIGGER IF EXISTS trigger_cache_invalidation_recipes ON recipes;
DROP TRIGGER IF EXISTS trigger_cache_invalidation_recipe_components ON recipe_components;

-- Create triggers for cache invalidation notifications
CREATE TRIGGER trigger_cache_invalidation_recipes
    AFTER INSERT OR UPDATE OR DELETE ON recipes
    FOR EACH ROW EXECUTE FUNCTION notify_parser_cache_invalidation();

CREATE TRIGGER trigger_cache_invalidation_recipe_components
    AFTER INSERT OR UPDATE OR DELETE ON recipe_components
    FOR EACH ROW EXECUTE FUNCTION notify_parser_cache_invalidation();


-- =============================================================================
-- STEP 6: Grant necessary permissions for parser service
-- =============================================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO service_role;

-- Grant select on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO service_role;

-- Grant sequence permissions for new tables
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Grant execute permissions on parser functions
GRANT EXECUTE ON FUNCTION get_kitchen_preparations_for_parser(UUID) TO service_role;
