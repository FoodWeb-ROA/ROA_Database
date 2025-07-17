-- ROA Application Seed Data --
-- Target Kitchen ID: 816f8fdb-fedd-4e6e-899b-9c98513e49c5

-- 1. Ensure Menu Sections Exist
-- Create if not present, otherwise do nothing (Menu sections less likely to need updates via seed)
INSERT INTO menu_section (name, kitchen_id) VALUES 
  ('All Courses', '816f8fdb-fedd-4e6e-899b-9c98513e49c5'),
  ('Main', '816f8fdb-fedd-4e6e-899b-9c98513e49c5'),
  ('Appetiser', '816f8fdb-fedd-4e6e-899b-9c98513e49c5'),
  ('Pastry', '816f8fdb-fedd-4e6e-899b-9c98513e49c5'),
  ('Sides', '816f8fdb-fedd-4e6e-899b-9c98513e49c5')
ON CONFLICT (name, kitchen_id) DO NOTHING;

-- 2. Ingredients (Raw and Base for Preparations)
-- Removed unit_id, amount, synonyms, storage_location
INSERT INTO ingredients (name)
VALUES
-- Raw Ingredients - Produce
('Chicken Breast'),
('Yellow Onion'),
('Carrot'),
('Celery'),
('Garlic'),
('Tomato'),
('Russet Potato'),
('Lettuce'),
('Baby Spinach'),
('Bell Pepper'),
('Lemon'),
('Lime'),
('Avocado'),
('Cucumber'),
('Broccoli'),
('Zucchini'),
('Eggplant'),
('Mushrooms'),
('Ginger'),
('Scallions'),

-- Raw Ingredients - Pantry/Dairy/Other
('Olive Oil'),
('Sea Salt'),
('Black Pepper'),
('Spaghetti'),
('Penne'),
('Sugar'),
('Brown Sugar'),
('All-Purpose Flour'),
('Butter'),
('Egg'),
('Milk'),
('Heavy Cream'),
('Parmesan Cheese'),
('Chocolate Chips'),
('Vanilla Extract'),
('Baking Soda'),
('Red Wine Vinegar'),
('Dijon Mustard'),
('Chicken Broth'),
('Beef Broth'),
('Vegetable Broth'),
('Soy Sauce'),
('Honey'),
('Basmati Rice'),
('Canned Diced Tomatoes'),
('Tomato Paste'),
('Beef Sirloin'),
('Beef Chuck'),
('Pork Shoulder'),
('Cod Fillet'),
('Salmon Fillet'),
('Shrimp'),
('Mozzarella Cheese'),
('Cheddar Cheese'),
('Quinoa'),
('Lentils'),
('Chickpeas'),
('Coconut Milk'),
('Curry Powder'),
('Turmeric'),
('Cumin Seeds'),
('Coriander Seeds'),
('Bay Leaves'),
('Fresh Basil'),
('Fresh Thyme'),
('Fresh Rosemary'),
('Dry Red Wine'),
('Dry White Wine'),
('BBQ Sauce'),
('Hamburger Buns'),

-- Base Ingredients for Preparations 
('Mirepoix Prep Base'),
('Pizza Dough Prep Base'),
('Tomato Sauce Prep Base'),
('Vinaigrette Prep Base'),
('Alfredo Sauce Prep Base'),
('Rich Beef Stock Prep Base'),
('Demi-Glace Prep Base'), 
('Vegetable Stock Prep Base'), 
('Herb Butter Prep Base');


-- 3. Preparations (Reference Ingredients Refined)
-- Removed amount_unit_id. Removed yield and yield_unit_id as yield is now implicit 1x.

-- Mirepoix
INSERT INTO preparations (preparation_id, directions, total_time, fingerprint, cooking_notes)
SELECT i.ingredient_id, ARRAY['Finely dice onion, carrot, and celery (2:1:1 ratio)', 'Sweat vegetables in butter or oil until softened'], 15, md5('Yellow Onion'||'Carrot'||'Celery'||'Butter'), 'Yields approx. 215g of mirepoix.'
FROM ingredients i WHERE i.name = 'Mirepoix Prep Base'
ON CONFLICT (preparation_id) DO UPDATE SET 
  directions = EXCLUDED.directions, 
  total_time = EXCLUDED.total_time, 
  fingerprint = EXCLUDED.fingerprint,
  cooking_notes = EXCLUDED.cooking_notes;

-- Pizza Dough
INSERT INTO preparations (preparation_id, directions, total_time, fingerprint, cooking_notes)
SELECT i.ingredient_id, ARRAY['Combine flour, yeast, salt, water, oil', 'Knead until smooth', 'Proof until doubled'], 90, md5('All-Purpose Flour'||'Sea Salt'||'Yeast'||'Water'||'Olive Oil'), 'Yields approx. 300g of dough, enough for one 12-inch pizza.'
FROM ingredients i WHERE i.name = 'Pizza Dough Prep Base'
ON CONFLICT (preparation_id) DO UPDATE SET 
  directions = EXCLUDED.directions, 
  total_time = EXCLUDED.total_time, 
  fingerprint = EXCLUDED.fingerprint,
  cooking_notes = EXCLUDED.cooking_notes;

-- Tomato Sauce
INSERT INTO preparations (preparation_id, directions, total_time, fingerprint, cooking_notes)
SELECT i.ingredient_id, ARRAY['Sauté onion and garlic in olive oil', 'Add canned tomatoes', 'Simmer for 20 minutes', 'Season with salt and pepper. Optional: add basil'], 30, md5('Yellow Onion'||'Garlic'||'Olive Oil'||'Canned Diced Tomatoes'||'Sea Salt'||'Black Pepper'), 'Yields approx. 500ml of sauce.'
FROM ingredients i WHERE i.name = 'Tomato Sauce Prep Base'
ON CONFLICT (preparation_id) DO UPDATE SET 
  directions = EXCLUDED.directions, 
  total_time = EXCLUDED.total_time, 
  fingerprint = EXCLUDED.fingerprint,
  cooking_notes = EXCLUDED.cooking_notes;

-- Basic Vinaigrette
INSERT INTO preparations (preparation_id, directions, total_time, fingerprint, cooking_notes)
SELECT i.ingredient_id, ARRAY['Whisk vinegar and mustard', 'Slowly whisk in olive oil', 'Season with salt and pepper'], 5, md5('Red Wine Vinegar'||'Dijon Mustard'||'Olive Oil'||'Sea Salt'||'Black Pepper'), 'Yields approx. 240ml of vinaigrette.'
FROM ingredients i WHERE i.name = 'Vinaigrette Prep Base'
ON CONFLICT (preparation_id) DO UPDATE SET 
  directions = EXCLUDED.directions, 
  total_time = EXCLUDED.total_time, 
  fingerprint = EXCLUDED.fingerprint,
  cooking_notes = EXCLUDED.cooking_notes;

-- Alfredo Sauce
INSERT INTO preparations (preparation_id, directions, total_time, fingerprint, cooking_notes)
SELECT i.ingredient_id, ARRAY['Gently heat heavy cream and butter', 'Whisk in grated Parmesan cheese until melted and smooth', 'Season with salt and pepper'], 10, md5('Heavy Cream'||'Butter'||'Parmesan Cheese'||'Garlic'||'Sea Salt'||'Black Pepper'), 'Yields approx. 300ml of Alfredo sauce.'
FROM ingredients i WHERE i.name = 'Alfredo Sauce Prep Base'
ON CONFLICT (preparation_id) DO UPDATE SET 
  directions = EXCLUDED.directions, 
  total_time = EXCLUDED.total_time, 
  fingerprint = EXCLUDED.fingerprint,
  cooking_notes = EXCLUDED.cooking_notes;

-- Rich Beef Stock
INSERT INTO preparations (preparation_id, directions, total_time, fingerprint, cooking_notes)
SELECT i.ingredient_id, ARRAY['Roast beef bones and vegetables (mirepoix)', 'Add water and aromatics (bay leaf, thyme)', 'Simmer for 4-6 hours, skimming occasionally', 'Strain thoroughly'], 360, md5('Beef Broth'||'Mirepoix Prep Base'||'Bay Leaves'||'Fresh Thyme'), 'Yields approx. 1 Liter of rich stock.'
FROM ingredients i WHERE i.name = 'Rich Beef Stock Prep Base'
ON CONFLICT (preparation_id) DO UPDATE SET 
  directions = EXCLUDED.directions, 
  total_time = EXCLUDED.total_time, 
  fingerprint = EXCLUDED.fingerprint,
  cooking_notes = EXCLUDED.cooking_notes;

-- Enhanced Demi-Glace
INSERT INTO preparations (preparation_id, directions, total_time, fingerprint, cooking_notes)
SELECT i.ingredient_id, ARRAY['Reduce Rich Beef Stock by half over medium heat', 'Add a splash of red wine (optional) and reduce further until syrupy', 'Strain again if needed'], 120, md5('Rich Beef Stock Prep Base'||'Dry Red Wine'), 'Yields approx. 200ml of demi-glace.'
FROM ingredients i WHERE i.name = 'Demi-Glace Prep Base'
ON CONFLICT (preparation_id) DO UPDATE SET 
  directions = EXCLUDED.directions, 
  total_time = EXCLUDED.total_time, 
  fingerprint = EXCLUDED.fingerprint,
  cooking_notes = EXCLUDED.cooking_notes;

-- Vegetable Stock
INSERT INTO preparations (preparation_id, directions, total_time, fingerprint, cooking_notes)
SELECT i.ingredient_id, ARRAY['Combine vegetable scraps (onion, carrot, celery ends), water, peppercorns, bay leaf', 'Simmer for 1 hour', 'Strain'], 75, md5('Yellow Onion'||'Carrot'||'Celery'||'Black Pepper'||'Bay Leaves'), 'Yields approx. 1 Liter of vegetable stock.'
FROM ingredients i WHERE i.name = 'Vegetable Stock Prep Base'
ON CONFLICT (preparation_id) DO UPDATE SET 
  directions = EXCLUDED.directions, 
  total_time = EXCLUDED.total_time, 
  fingerprint = EXCLUDED.fingerprint,
  cooking_notes = EXCLUDED.cooking_notes;

-- Herb Butter
INSERT INTO preparations (preparation_id, directions, total_time, fingerprint, cooking_notes)
SELECT i.ingredient_id, ARRAY['Soften butter', 'Finely chop fresh herbs (e.g., parsley, thyme, rosemary)', 'Mix herbs into butter with a pinch of salt', 'Roll into a log using plastic wrap and chill until firm'], 15, md5('Butter'||'Fresh Basil'||'Fresh Thyme'||'Fresh Rosemary'||'Sea Salt'), 'Yields approx. 113g (1 stick) of herb butter.'
FROM ingredients i WHERE i.name = 'Herb Butter Prep Base'
ON CONFLICT (preparation_id) DO UPDATE SET 
  directions = EXCLUDED.directions, 
  total_time = EXCLUDED.total_time, 
  fingerprint = EXCLUDED.fingerprint,
  cooking_notes = EXCLUDED.cooking_notes;

-- 4. Preparation Ingredients
-- Clear existing first to avoid duplicates if script is run multiple times
DELETE FROM preparation_components;

-- Mirepoix Prep Base Ingredients
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Mirepoix Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Yellow Onion'), 100, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Mirepoix Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Carrot'), 50, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Mirepoix Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Celery'), 50, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Mirepoix Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Butter'), 15, (SELECT unit_id FROM units WHERE abbreviation = 'g');

-- Pizza Dough Prep Base Ingredients
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Pizza Dough Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'All-Purpose Flour'), 300, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Pizza Dough Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Sea Salt'), 5, (SELECT unit_id FROM units WHERE abbreviation = 'g');
-- Add water, yeast, oil if defined as ingredients

-- Tomato Sauce Prep Base Ingredients
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Tomato Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Yellow Onion'), 0.5, (SELECT unit_id FROM units WHERE unit_name = 'Pieces');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Tomato Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Garlic'), 2, (SELECT unit_id FROM units WHERE unit_name = 'Pieces');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Tomato Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Olive Oil'), 30, (SELECT unit_id FROM units WHERE unit_name = 'Milliliter');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Tomato Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Canned Diced Tomatoes'), 28, (SELECT unit_id FROM units WHERE abbreviation = 'oz');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Tomato Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Sea Salt'), 5, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Tomato Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Black Pepper'), 2, (SELECT unit_id FROM units WHERE abbreviation = 'g');

-- Vinaigrette Prep Base Ingredients
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Vinaigrette Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Red Wine Vinegar'), 60, (SELECT unit_id FROM units WHERE unit_name = 'Milliliter');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Vinaigrette Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Dijon Mustard'), 5, (SELECT unit_id FROM units WHERE abbreviation = 'ml');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Vinaigrette Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Olive Oil'), 180, (SELECT unit_id FROM units WHERE unit_name = 'Milliliter');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Vinaigrette Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Sea Salt'), 3, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Vinaigrette Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Black Pepper'), 1, (SELECT unit_id FROM units WHERE abbreviation = 'g');

-- Alfredo Sauce Prep Base Ingredients
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Alfredo Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Heavy Cream'), 250, (SELECT unit_id FROM units WHERE unit_name = 'Milliliter');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Alfredo Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Butter'), 30, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Alfredo Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Parmesan Cheese'), 50, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Alfredo Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Garlic'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Pieces');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Alfredo Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Sea Salt'), 2, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Alfredo Sauce Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Black Pepper'), 1, (SELECT unit_id FROM units WHERE abbreviation = 'g');

-- Rich Beef Stock Prep Base Ingredients
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Rich Beef Stock Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Beef Broth'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Liter');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Rich Beef Stock Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Mirepoix Prep Base'), 150, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Rich Beef Stock Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Bay Leaves'), 2, (SELECT unit_id FROM units WHERE unit_name = 'Pieces');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Rich Beef Stock Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Fresh Thyme'), 3, (SELECT unit_id FROM units WHERE unit_name = 'Pieces');

-- Demi-Glace Prep Base Ingredients
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Demi-Glace Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Rich Beef Stock Prep Base'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Liter');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Demi-Glace Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Dry Red Wine'), 120, (SELECT unit_id FROM units WHERE unit_name = 'Milliliter');

-- Vegetable Stock Prep Base Ingredients
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Vegetable Stock Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Yellow Onion'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Pieces');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Vegetable Stock Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Carrot'), 2, (SELECT unit_id FROM units WHERE unit_name = 'Pieces');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Vegetable Stock Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Celery'), 2, (SELECT unit_id FROM units WHERE unit_name = 'Pieces');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Vegetable Stock Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Black Pepper'), 10, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Vegetable Stock Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Bay Leaves'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Pieces');

-- Herb Butter Prep Base Ingredients
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Herb Butter Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Butter'), 113, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Herb Butter Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Fresh Thyme'), 2, (SELECT unit_id FROM units WHERE abbreviation = 'tbsp');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Herb Butter Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Fresh Rosemary'), 1, (SELECT unit_id FROM units WHERE abbreviation = 'tbsp');
INSERT INTO preparation_components (preparation_id, ingredient_id, amount, unit_id)
SELECT (SELECT ingredient_id FROM ingredients WHERE name = 'Herb Butter Prep Base'), (SELECT ingredient_id FROM ingredients WHERE name = 'Sea Salt'), 2, (SELECT unit_id FROM units WHERE abbreviation = 'g');

-- 5. Dishes (Assign to specific sections)
-- Clear existing first to ensure menu_section_id is updated if needed
DELETE FROM dishes;

-- Main Courses
INSERT INTO dishes (dish_name, menu_section_id, directions, total_time, num_servings, serving_size, serving_unit_id, serving_item, cooking_notes, kitchen_id)
SELECT 'Chicken Fettuccine Alfredo', (SELECT menu_section_id FROM menu_section WHERE name = 'Main' AND kitchen_id = '816f8fdb-fedd-4e6e-899b-9c98513e49c5'), E'1. Cook fettuccine pasta according to package directions.\n2. While pasta cooks, season chicken breast with salt and pepper.\n3. Grill or pan-sear chicken until cooked through. Let rest, then slice.\n4. Gently heat Alfredo Sauce in a saucepan.\n5. Drain cooked pasta and add to the sauce pan.\n6. Add sliced chicken and toss gently to combine.\n7. Serve immediately, garnished with grated Parmesan cheese.', '00:35:00', 2, 400, (SELECT unit_id FROM units WHERE abbreviation = 'g'), 'plate', 'Ensure sauce is warm but not boiling to prevent separation.', '816f8fdb-fedd-4e6e-899b-9c98513e49c5';

INSERT INTO dishes (dish_name, menu_section_id, directions, total_time, num_servings, serving_size, serving_unit_id, serving_item, cooking_notes, kitchen_id)
SELECT 'Classic Margherita Pizza', (SELECT menu_section_id FROM menu_section WHERE name = 'Main' AND kitchen_id = '816f8fdb-fedd-4e6e-899b-9c98513e49c5'), E'1. Preheat oven to 500°F (260°C) with a pizza stone inside if available.\n2. Gently stretch Pizza Dough into a 12-inch round on a lightly floured surface.\n3. Spread Tomato Sauce thinly over the dough, leaving a small border.\n4. Tear fresh mozzarella and distribute evenly over the sauce.\n5. Arrange fresh basil leaves on top.\n6. Carefully transfer pizza to the preheated stone or a baking sheet.\n7. Bake for 8-12 minutes, until crust is golden brown and cheese is bubbly and slightly browned.', '00:20:00', 1, 1, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'pizza', 'Use a pizza stone and high heat for best crust results.', '816f8fdb-fedd-4e6e-899b-9c98513e49c5';

INSERT INTO dishes (dish_name, menu_section_id, directions, total_time, num_servings, serving_size, serving_unit_id, serving_item, cooking_notes, kitchen_id)
SELECT 'Steak with Enhanced Demi-Glace', (SELECT menu_section_id FROM menu_section WHERE name = 'Main' AND kitchen_id = '816f8fdb-fedd-4e6e-899b-9c98513e49c5'), E'1. Season sirloin steak generously with salt and pepper.\n2. Sear steak in a hot, oven-safe skillet with a bit of oil for 2-3 minutes per side.\n3. Transfer skillet to a preheated 400°F (200°C) oven and cook to desired doneness (e.g., 5-7 min for medium-rare).\n4. Remove steak from skillet and let rest on a cutting board for 10 minutes.\n5. While steak rests, gently warm Enhanced Demi-Glace in a small saucepan.\n6. Slice steak against the grain and serve topped with the warm demi-glace.', '00:25:00', 1, 8, (SELECT unit_id FROM units WHERE abbreviation = 'oz'), 'steak', 'Resting the steak is crucial for tenderness. Serve with roasted potatoes or vegetables.', '816f8fdb-fedd-4e6e-899b-9c98513e49c5';

INSERT INTO dishes (dish_name, menu_section_id, directions, total_time, num_servings, serving_size, serving_unit_id, serving_item, cooking_notes, kitchen_id)
SELECT 'Roasted Chicken Breast', (SELECT menu_section_id FROM menu_section WHERE name = 'Main' AND kitchen_id = '816f8fdb-fedd-4e6e-899b-9c98513e49c5'), E'1. Preheat oven to 400°F (200°C).\n2. Pat chicken breasts dry and season generously with salt, pepper, and optionally chopped fresh rosemary or thyme.\n3. Heat an oven-safe skillet over medium-high heat with olive oil.\n4. Sear chicken breasts skin-side down (if applicable) for 3-4 minutes until golden.\n5. Flip chicken and transfer skillet to the preheated oven.\n6. Roast for 15-20 minutes, or until internal temperature reaches 165°F (74°C).\n7. Let rest for 5-10 minutes before slicing.', '00:30:00', 1, 6, (SELECT unit_id FROM units WHERE abbreviation = 'oz'), 'breast', 'Can add root vegetables like carrots or potatoes to the skillet during roasting.', '816f8fdb-fedd-4e6e-899b-9c98513e49c5';

INSERT INTO dishes (dish_name, menu_section_id, directions, total_time, num_servings, serving_size, serving_unit_id, serving_item, cooking_notes, kitchen_id)
SELECT 'Beef Stew with Rich Stock', (SELECT menu_section_id FROM menu_section WHERE name = 'Main' AND kitchen_id = '816f8fdb-fedd-4e6e-899b-9c98513e49c5'), E'1. Pat beef chuck dry and season with salt and pepper. Sear in batches in a hot Dutch oven until browned. Set aside.\n2. Add Mirepoix Prep Base to the pot and sauté until softened, about 5-7 minutes.\n3. Stir in tomato paste and cook for 1 minute.\n4. Deglaze the pot with Dry Red Wine, scraping up any browned bits.\n5. Return beef to the pot. Add Rich Beef Stock Prep Base, diced potatoes, carrots, and bay leaf.\n6. Bring to a simmer, then cover and cook on low heat (or in a 325°F/160°C oven) for 2-3 hours, or until beef is fork-tender.\n7. Remove bay leaf before serving.', '03:00:00', 6, 350, (SELECT unit_id FROM units WHERE abbreviation = 'g'), 'bowl', 'Stew develops more flavor if made a day ahead. Thicken with a flour or cornstarch slurry at the end if desired.', '816f8fdb-fedd-4e6e-899b-9c98513e49c5';

INSERT INTO dishes (dish_name, menu_section_id, directions, total_time, num_servings, serving_size, serving_unit_id, serving_item, cooking_notes, kitchen_id)
SELECT 'Pulled Pork Sandwiches', (SELECT menu_section_id FROM menu_section WHERE name = 'Main' AND kitchen_id = '816f8fdb-fedd-4e6e-899b-9c98513e49c5'), E'1. Pat pork shoulder dry. Rub generously with desired spices (e.g., paprika, brown sugar, salt, pepper, garlic powder).\n2. Place pork in a slow cooker. Cook on low for 8-10 hours or on high for 4-5 hours, until fork-tender.\n3. Remove pork from slow cooker and shred using two forks. Discard excess fat.\n4. Mix shredded pork with BBQ Sauce to taste.\n5. Serve warm on Hamburger Buns.', '08:30:00', 8, 150, (SELECT unit_id FROM units WHERE abbreviation = 'g'), 'sandwich', 'Excellent served with coleslaw and pickles. Can also be cooked in a Dutch oven at low temperature.', '816f8fdb-fedd-4e6e-899b-9c98513e49c5';

INSERT INTO dishes (dish_name, menu_section_id, directions, total_time, num_servings, serving_size, serving_unit_id, serving_item, cooking_notes, kitchen_id)
SELECT 'Coconut Lentil Curry', (SELECT menu_section_id FROM menu_section WHERE name = 'Main' AND kitchen_id = '816f8fdb-fedd-4e6e-899b-9c98513e49c5'), E'1. Heat oil in a large pot or Dutch oven over medium heat.\n2. Add chopped Yellow Onion and sauté until softened, about 5 minutes.\n3. Add minced Garlic and grated Ginger, sauté for 1 minute more until fragrant.\n4. Stir in Curry Powder, Turmeric, Cumin Seeds, and Coriander Seeds. Cook for 1 minute, stirring constantly.\n5. Add rinsed Lentils, Coconut Milk, Vegetable Stock Prep Base, and Canned Diced Tomatoes (undrained).\n6. Bring to a simmer, then reduce heat, cover, and cook for 25-30 minutes, or until lentils are tender.\n7. Season with salt and pepper to taste. Stir in fresh spinach until wilted (optional).\n8. Serve hot.', '00:45:00', 4, 300, (SELECT unit_id FROM units WHERE unit_name = 'Milliliter'), 'bowl', 'Serve with Basmati Rice or naan bread. Garnish with fresh cilantro.', '816f8fdb-fedd-4e6e-899b-9c98513e49c5';

-- Sides
INSERT INTO dishes (dish_name, menu_section_id, directions, total_time, num_servings, serving_size, serving_unit_id, serving_item, cooking_notes, kitchen_id)
SELECT 'Simple Side Salad', (SELECT menu_section_id FROM menu_section WHERE name = 'Sides' AND kitchen_id = '816f8fdb-fedd-4e6e-899b-9c98513e49c5'), E'1. Wash and thoroughly dry lettuce leaves.\n2. Tear or chop lettuce into bite-sized pieces.\n3. In a large bowl, toss lettuce gently with Basic Vinaigrette just before serving.', '00:10:00', 1, 1, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'bowl', 'Add other vegetables like cucumber, tomato, or bell pepper as desired. Dress salad just before serving to prevent wilting.', '816f8fdb-fedd-4e6e-899b-9c98513e49c5';

-- Pastry/Dessert
INSERT INTO dishes (dish_name, menu_section_id, directions, total_time, num_servings, serving_size, serving_unit_id, serving_item, cooking_notes, kitchen_id)
SELECT 'Chocolate Chip Cookies', (SELECT menu_section_id FROM menu_section WHERE name = 'Pastry' AND kitchen_id = '816f8fdb-fedd-4e6e-899b-9c98513e49c5'), E'1. Preheat oven to 375°F (190°C).\n2. In a large bowl, cream together softened butter, granulated sugar, and brown sugar until light and fluffy.\n3. Beat in eggs one at a time, then stir in vanilla extract.\n4. In a separate bowl, whisk together flour, baking soda, and salt.\n5. Gradually add the dry ingredients to the wet ingredients, mixing until just combined.\n6. Stir in chocolate chips.\n7. Drop rounded tablespoons of dough onto ungreased baking sheets.\n8. Bake for 10-12 minutes, or until edges are golden brown.\n9. Let cool on baking sheets for a few minutes before transferring to a wire rack to cool completely.', '00:25:00', 24, 1, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'cookie', 'Do not overmix the dough once flour is added. For chewier cookies, slightly underbake.', '816f8fdb-fedd-4e6e-899b-9c98513e49c5';

-- 6. Dish Components
-- Clear existing first
DELETE FROM dish_components;

-- Chicken Fettuccine Alfredo Components
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chicken Fettuccine Alfredo'), (SELECT ingredient_id FROM ingredients WHERE name = 'Spaghetti'), 200, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chicken Fettuccine Alfredo'), (SELECT ingredient_id FROM ingredients WHERE name = 'Chicken Breast'), 150, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chicken Fettuccine Alfredo'), (SELECT ingredient_id FROM ingredients WHERE name = 'Alfredo Sauce Prep Base'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Preparation');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chicken Fettuccine Alfredo'), (SELECT ingredient_id FROM ingredients WHERE name = 'Parmesan Cheese'), 20, (SELECT unit_id FROM units WHERE abbreviation = 'g');

-- Classic Margherita Pizza Components
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Classic Margherita Pizza'), (SELECT ingredient_id FROM ingredients WHERE name = 'Pizza Dough Prep Base'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Preparation');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Classic Margherita Pizza'), (SELECT ingredient_id FROM ingredients WHERE name = 'Tomato Sauce Prep Base'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Preparation');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Classic Margherita Pizza'), (SELECT ingredient_id FROM ingredients WHERE name = 'Mozzarella Cheese'), 125, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id, piece_type)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Classic Margherita Pizza'), (SELECT ingredient_id FROM ingredients WHERE name = 'Fresh Basil'), 5, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'leaf';

-- Steak with Enhanced Demi-Glace Components
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Steak with Enhanced Demi-Glace'), (SELECT ingredient_id FROM ingredients WHERE name = 'Beef Sirloin'), 8, (SELECT unit_id FROM units WHERE abbreviation = 'oz');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Steak with Enhanced Demi-Glace'), (SELECT ingredient_id FROM ingredients WHERE name = 'Demi-Glace Prep Base'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Preparation');

-- Roasted Chicken Breast Components
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Roasted Chicken Breast'), (SELECT ingredient_id FROM ingredients WHERE name = 'Chicken Breast'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Pound');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Roasted Chicken Breast'), (SELECT ingredient_id FROM ingredients WHERE name = 'Sea Salt'), 2, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Roasted Chicken Breast'), (SELECT ingredient_id FROM ingredients WHERE name = 'Black Pepper'), 1, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id, piece_type)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Roasted Chicken Breast'), (SELECT ingredient_id FROM ingredients WHERE name = 'Fresh Rosemary'), 2, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'sprig';
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Roasted Chicken Breast'), (SELECT ingredient_id FROM ingredients WHERE name = 'Olive Oil'), 15, (SELECT unit_id FROM units WHERE unit_name = 'Milliliter');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Roasted Chicken Breast'), (SELECT ingredient_id FROM ingredients WHERE name = 'Mirepoix Prep Base'), 0.5, (SELECT unit_id FROM units WHERE unit_name = 'Preparation');

-- Simple Side Salad Components
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id, piece_type)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Simple Side Salad'), (SELECT ingredient_id FROM ingredients WHERE name = 'Lettuce'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'head';
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Simple Side Salad'), (SELECT ingredient_id FROM ingredients WHERE name = 'Vinaigrette Prep Base'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Preparation');

-- Chocolate Chip Cookie Components
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chocolate Chip Cookies'), (SELECT ingredient_id FROM ingredients WHERE name = 'Butter'), 226, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chocolate Chip Cookies'), (SELECT ingredient_id FROM ingredients WHERE name = 'Sugar'), 100, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chocolate Chip Cookies'), (SELECT ingredient_id FROM ingredients WHERE name = 'Brown Sugar'), 100, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id, piece_type)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chocolate Chip Cookies'), (SELECT ingredient_id FROM ingredients WHERE name = 'Egg'), 2, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'large';
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chocolate Chip Cookies'), (SELECT ingredient_id FROM ingredients WHERE name = 'All-Purpose Flour'), 250, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chocolate Chip Cookies'), (SELECT ingredient_id FROM ingredients WHERE name = 'Baking Soda'), 0.5, (SELECT unit_id FROM units WHERE abbreviation = 'tsp');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chocolate Chip Cookies'), (SELECT ingredient_id FROM ingredients WHERE name = 'Sea Salt'), 2, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chocolate Chip Cookies'), (SELECT ingredient_id FROM ingredients WHERE name = 'Vanilla Extract'), 1, (SELECT unit_id FROM units WHERE abbreviation = 'tsp');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Chocolate Chip Cookies'), (SELECT ingredient_id FROM ingredients WHERE name = 'Chocolate Chips'), 340, (SELECT unit_id FROM units WHERE abbreviation = 'g');

-- Beef Stew with Rich Stock Components
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Beef Stew with Rich Stock'), (SELECT ingredient_id FROM ingredients WHERE name = 'Beef Chuck'), 2, (SELECT unit_id FROM units WHERE unit_name = 'Pound');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Beef Stew with Rich Stock'), (SELECT ingredient_id FROM ingredients WHERE name = 'Mirepoix Prep Base'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Preparation');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Beef Stew with Rich Stock'), (SELECT ingredient_id FROM ingredients WHERE name = 'Russet Potato'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Pound');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id, piece_type)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Beef Stew with Rich Stock'), (SELECT ingredient_id FROM ingredients WHERE name = 'Carrot'), 2, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'large';
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Beef Stew with Rich Stock'), (SELECT ingredient_id FROM ingredients WHERE name = 'Rich Beef Stock Prep Base'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Preparation');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Beef Stew with Rich Stock'), (SELECT ingredient_id FROM ingredients WHERE name = 'Tomato Paste'), 2, (SELECT unit_id FROM units WHERE abbreviation = 'oz');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Beef Stew with Rich Stock'), (SELECT ingredient_id FROM ingredients WHERE name = 'Dry Red Wine'), 150, (SELECT unit_id FROM units WHERE unit_name = 'Milliliter');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id, piece_type)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Beef Stew with Rich Stock'), (SELECT ingredient_id FROM ingredients WHERE name = 'Bay Leaves'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'leaf';
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id, piece_type)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Beef Stew with Rich Stock'), (SELECT ingredient_id FROM ingredients WHERE name = 'Fresh Thyme'), 3, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'sprig';

-- Pulled Pork Sandwiches Components
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Pulled Pork Sandwiches'), (SELECT ingredient_id FROM ingredients WHERE name = 'Pork Shoulder'), 3, (SELECT unit_id FROM units WHERE unit_name = 'Pound');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Pulled Pork Sandwiches'), (SELECT ingredient_id FROM ingredients WHERE name = 'BBQ Sauce'), 250, (SELECT unit_id FROM units WHERE unit_name = 'Milliliter');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id, piece_type)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Pulled Pork Sandwiches'), (SELECT ingredient_id FROM ingredients WHERE name = 'Hamburger Buns'), 8, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'bun';
-- Add spices if listed as separate ingredients

-- Coconut Lentil Curry Components
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Lentils'), 250, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Coconut Milk'), 400, (SELECT unit_id FROM units WHERE unit_name = 'Milliliter');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Vegetable Stock Prep Base'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Preparation');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id, piece_type)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Yellow Onion'), 1, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'medium';
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id, piece_type)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Garlic'), 3, (SELECT unit_id FROM units WHERE unit_name = 'Pieces'), 'clove';
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Ginger'), 15, (SELECT unit_id FROM units WHERE abbreviation = 'g');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Curry Powder'), 2, (SELECT unit_id FROM units WHERE abbreviation = 'tbsp');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Turmeric'), 1, (SELECT unit_id FROM units WHERE abbreviation = 'tsp');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Cumin Seeds'), 1, (SELECT unit_id FROM units WHERE abbreviation = 'tsp');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Coriander Seeds'), 1, (SELECT unit_id FROM units WHERE abbreviation = 'tsp');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Canned Diced Tomatoes'), 14.5, (SELECT unit_id FROM units WHERE abbreviation = 'oz');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Olive Oil'), 1, (SELECT unit_id FROM units WHERE abbreviation = 'tbsp');
INSERT INTO dish_components (dish_id, ingredient_id, amount, unit_id)
SELECT (SELECT dish_id FROM dishes WHERE dish_name = 'Coconut Lentil Curry'), (SELECT ingredient_id FROM ingredients WHERE name = 'Baby Spinach'), 5, (SELECT unit_id FROM units WHERE abbreviation = 'oz');

-- Final Note: This seed script provides a more robust starting point.
-- Remember to adjust amounts, units, and specific ingredients based on actual recipes.
