-- GrubShelf Migration 021: Grocery search aliases & typos
-- Adds common aliases (ricebowl→rice) and typos (carrort→carrot) to search_keywords

UPDATE grocery_catalog
SET search_keywords = TRIM(COALESCE(search_keywords, '') || ' ricebowl')
WHERE name IN (
  'White Rice', 'Brown Rice', 'Basmati Rice', 'Jasmine Rice',
  'Wild Rice', 'Arborio Rice', 'Sushi Rice',
  'Parboiled Rice', 'Jollof Rice'
);

UPDATE grocery_catalog
SET search_keywords = TRIM(COALESCE(search_keywords, '') || ' carrort')
WHERE name = 'Carrot';

-- Additional common typos and aliases
UPDATE grocery_catalog
SET search_keywords = TRIM(COALESCE(search_keywords, '') || ' tomatos')
WHERE name = 'Tomato';

UPDATE grocery_catalog
SET search_keywords = TRIM(COALESCE(search_keywords, '') || ' potatos')
WHERE name = 'Potato';

UPDATE grocery_catalog
SET search_keywords = TRIM(COALESCE(search_keywords, '') || ' onoins')
WHERE name = 'Onion';

UPDATE grocery_catalog
SET search_keywords = TRIM(COALESCE(search_keywords, '') || ' garlick')
WHERE name = 'Garlic';

UPDATE grocery_catalog
SET search_keywords = TRIM(COALESCE(search_keywords, '') || ' brocoli')
WHERE name = 'Broccoli';

UPDATE grocery_catalog
SET search_keywords = TRIM(COALESCE(search_keywords, '') || ' tomatosauce')
WHERE name = 'Tomato Sauce';

UPDATE grocery_catalog
SET search_keywords = TRIM(COALESCE(search_keywords, '') || ' chickin')
WHERE name IN ('Chicken Breast', 'Chicken Thigh', 'Whole Chicken', 'Chicken Wings');
