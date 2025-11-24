-- Migration: Add unique constraint for Personal kitchen names
-- Purpose: Prevent duplicate Personal kitchen names (which are emails by construction)
-- Date: 2025-10-20

-- Step 1: Clean up existing duplicate Personal kitchens
-- Keep only the oldest kitchen (by kitchen_id) for each name where type = 'Personal'
-- This ensures data integrity before adding the unique constraint

DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete duplicate Personal kitchens, keeping only the one with the smallest kitchen_id (oldest)
    WITH duplicates AS (
        SELECT 
            kitchen_id,
            name,
            type,
            ROW_NUMBER() OVER (PARTITION BY name ORDER BY kitchen_id ASC) as rn
        FROM public.kitchen
        WHERE type = 'Personal'
    )
    DELETE FROM public.kitchen
    WHERE kitchen_id IN (
        SELECT kitchen_id 
        FROM duplicates 
        WHERE rn > 1
    );
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    IF deleted_count > 0 THEN
        RAISE NOTICE 'Deleted % duplicate Personal kitchen(s)', deleted_count;
    ELSE
        RAISE NOTICE 'No duplicate Personal kitchens found';
    END IF;
END $$;

-- Step 2: Create a unique partial index on kitchen.name where type = 'Personal'
-- This ensures only one Personal kitchen can exist with a given name (email)
-- while allowing multiple Team kitchens to share the same name if needed
CREATE UNIQUE INDEX IF NOT EXISTS unique_personal_kitchen_name 
ON public.kitchen (name) 
WHERE type = 'Personal';

-- Add a comment explaining the constraint
COMMENT ON INDEX public.unique_personal_kitchen_name IS 
'Ensures each Personal kitchen has a unique name (email). Team kitchens are not restricted by this constraint.';
