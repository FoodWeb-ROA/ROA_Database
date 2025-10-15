-- ============================================================================
-- Enable Realtime on parsing_results Table
-- ============================================================================
-- This migration enables Supabase Realtime on the parsing_results table
-- so frontend clients receive instant notifications when parsing completes.
-- Also updates RLS policies to allow users to delete their own results
-- after ingestion (cleanup).
-- ============================================================================

-- 1. Enable Realtime publication
-- ============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.parsing_results;

-- 2. Update RLS policies
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own parsing results" ON public.parsing_results;
DROP POLICY IF EXISTS "Service role can manage all parsing results" ON public.parsing_results;

-- Policy: Users can SELECT their own results
CREATE POLICY "Users can view their own parsing results"
  ON public.parsing_results
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can DELETE their own results (cleanup after ingestion)
CREATE POLICY "Users can delete their own parsing results"
  ON public.parsing_results
  FOR DELETE
  USING (auth.uid() = user_id);

-- Policy: Service role has full access (for backend workers)
CREATE POLICY "Service role can manage all parsing results"
  ON public.parsing_results
  FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');

-- 3. Add composite index for efficient queries
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_parsing_results_kitchen_user 
  ON public.parsing_results(kitchen_id, user_id, completed_at DESC);

-- 4. Update existing schema if needed
-- ============================================================================
-- Ensure recipe_data column exists and is JSONB for efficient storage
DO $$
BEGIN
  -- Check if recipe_data column exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'parsing_results'
    AND column_name = 'recipe_data'
  ) THEN
    -- Add recipe_data column as JSONB
    ALTER TABLE public.parsing_results ADD COLUMN recipe_data JSONB;
  END IF;
END $$;

COMMENT ON TABLE public.parsing_results IS 'Stores completed/failed parsing results. Frontend receives via Realtime and deletes after ingestion.';
COMMENT ON COLUMN public.parsing_results.recipe_data IS 'Raw recipe JSON array from parser. Frontend preprocesses and stores in Redux.';
