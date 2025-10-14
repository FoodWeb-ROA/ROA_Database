-- ============================================================================
-- Fix get_kitchen_preparations_for_parser schema references
-- ============================================================================
-- The function has SET "search_path" TO '' which requires explicit schema
-- qualification for all table references. This was missing, causing 
-- "relation 'recipes' does not exist" errors.
-- ============================================================================

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
