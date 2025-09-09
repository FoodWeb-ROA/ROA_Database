-- Add covering indexes for reported unindexed foreign keys
-- Safe to re-run with IF NOT EXISTS

BEGIN;

-- categories(menu_section_kitchen_id_fkey) → categories.kitchen_id
CREATE INDEX IF NOT EXISTS idx_categories_kitchen_id
  ON public.categories(kitchen_id);

-- components(components_recipe_id_fk) → components.recipe_id
CREATE INDEX IF NOT EXISTS idx_components_recipe_id
  ON public.components(recipe_id);

-- components(ingredients_kitchen_id_fkey) → components.kitchen_id
CREATE INDEX IF NOT EXISTS idx_components_kitchen_id
  ON public.components(kitchen_id);

-- kitchen_users(kitchen_users_kitchen_id_fkey) → kitchen_users.kitchen_id
CREATE INDEX IF NOT EXISTS idx_kitchen_users_kitchen_id
  ON public.kitchen_users(kitchen_id);

-- kitchen_users(kitchen_users_user_id_fkey) → kitchen_users.user_id
CREATE INDEX IF NOT EXISTS idx_kitchen_users_user_id
  ON public.kitchen_users(user_id);

-- recipe_components(recipe_components_component_id_fkey) → recipe_components.component_id
CREATE INDEX IF NOT EXISTS idx_recipe_components_component_id
  ON public.recipe_components(component_id);

-- recipe_components(recipe_components_recipe_id_fkey) → recipe_components.recipe_id
CREATE INDEX IF NOT EXISTS idx_recipe_components_recipe_id
  ON public.recipe_components(recipe_id);

-- recipes(dishes_kitchen_id_fkey) → recipes.kitchen_id
CREATE INDEX IF NOT EXISTS idx_recipes_kitchen_id
  ON public.recipes(kitchen_id);

-- recipes(recipe_category_id_fkey) → recipes.category_id
CREATE INDEX IF NOT EXISTS idx_recipes_category_id
  ON public.recipes(category_id);

COMMIT;


