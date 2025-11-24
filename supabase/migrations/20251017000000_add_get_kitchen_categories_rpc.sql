-- Add RPC function to get kitchen categories for parser
-- This provides a consistent interface alongside get_kitchen_preparations_for_parser

-- =============================================================================
-- Create function to get categories for parser
-- =============================================================================

CREATE OR REPLACE FUNCTION get_kitchen_categories_for_parser(
    p_kitchen_id UUID
) 
RETURNS JSONB 
SET "search_path" TO ''
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- Return a JSON array of category names for the kitchen
    SELECT jsonb_agg(c.name ORDER BY c.name)
    INTO result
    FROM public.categories c
    WHERE c.kitchen_id = p_kitchen_id;
    
    -- Return empty array if no categories found
    RETURN COALESCE(result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Grant permissions
-- =============================================================================

-- Grant execute permissions to service_role (used by parser service)
GRANT EXECUTE ON FUNCTION get_kitchen_categories_for_parser(UUID) TO service_role;

-- Also grant to authenticated users in case frontend needs it
GRANT EXECUTE ON FUNCTION get_kitchen_categories_for_parser(UUID) TO authenticated;

-- =============================================================================
-- Add comment for documentation
-- =============================================================================

COMMENT ON FUNCTION get_kitchen_categories_for_parser(UUID) IS 
'Returns a JSON array of category names for a given kitchen. Used by the recipe parser service to validate and suggest categories.';
