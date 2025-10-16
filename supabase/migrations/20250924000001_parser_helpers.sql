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
            'language', 'UNK',
            'components', COALESCE(comp_data.components, '[]'::jsonb),
            'directions', COALESCE(to_jsonb(r.directions), '[]'::jsonb),
            'time_minutes', EXTRACT(EPOCH FROM COALESCE(r.time, '0 minutes'::interval)) / 60,
            'cook_notes', r.cooking_notes,
            'serving_or_yield_amount', r.serving_or_yield_amount,
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
        FROM public.recipe_components rc
        JOIN public.components c ON rc.component_id = c.component_id
        LEFT JOIN public.recipes prep_recipe ON c.recipe_id = prep_recipe.recipe_id 
            AND prep_recipe.recipe_type = 'Preparation'
        WHERE rc.recipe_id = r.recipe_id
    ) comp_data ON true
    WHERE r.kitchen_id = p_kitchen_id 
    AND r.recipe_type = 'Preparation';
    
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO service_role;

-- Grant select on all existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO service_role;

-- Grant sequence permissions for new tables
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Grant execute permissions on parser functions
GRANT EXECUTE ON FUNCTION get_kitchen_preparations_for_parser(UUID) TO service_role;
