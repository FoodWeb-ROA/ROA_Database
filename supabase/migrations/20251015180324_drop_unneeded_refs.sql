DROP TRIGGER IF EXISTS trigger_cache_invalidation_recipes ON recipes;
DROP TRIGGER IF EXISTS trigger_cache_invalidation_recipe_components ON recipe_components;
DROP FUNCTION IF EXISTS public.notify_parser_cache_invalidation();