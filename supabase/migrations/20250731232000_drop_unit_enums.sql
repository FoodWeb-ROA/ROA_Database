-- Drop unused enum types if they exist
-- Migration generated 2025-07-31 23:20

BEGIN;

-- Drop unit_measurement_type enum if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'unit_measurement_type') THEN
        DROP TYPE public.unit_measurement_type;
    END IF;
END $$;

-- Drop unit_system enum if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'unit_system') THEN
        DROP TYPE public.unit_system;
    END IF;
END $$;

COMMIT;
