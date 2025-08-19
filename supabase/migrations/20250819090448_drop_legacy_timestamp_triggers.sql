-- Drop legacy timestamp triggers and function that reference non-existent created_at field
-- These are causing PostgreSQL errors after schema redesign

BEGIN;

-- Drop triggers that reference created_at field
DROP TRIGGER IF EXISTS handle_dishes_times ON public.recipes;
DROP TRIGGER IF EXISTS handle_ingredients_times ON public.components;
DROP TRIGGER IF EXISTS handle_times_tg ON public.components;
DROP TRIGGER IF EXISTS handle_times_tg ON public.recipe_components;

-- Drop the function that these triggers use
DROP FUNCTION IF EXISTS public.handle_times();

-- Drop created_at and updated_at columns from recipes table
ALTER TABLE public.recipes DROP COLUMN IF EXISTS created_at;
ALTER TABLE public.recipes DROP COLUMN IF EXISTS updated_at;

-- Drop created_at and updated_at columns from components table
ALTER TABLE public.components DROP COLUMN IF EXISTS created_at;
ALTER TABLE public.components DROP COLUMN IF EXISTS updated_at;

COMMIT;