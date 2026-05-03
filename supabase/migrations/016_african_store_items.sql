-- GrubShelf Migration 016: African Store Items (UK)
-- Adds items commonly sold in African stores, using existing categories where they fit
-- and creating new categories (African Staples, African Spices) for African-specific items

-- Ensure unique constraint on name for ON CONFLICT
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'grocery_catalog_name_key'
  ) THEN
    ALTER TABLE grocery_catalog ADD CONSTRAINT grocery_catalog_name_key UNIQUE (name);
  END IF;
END $$;

INSERT INTO grocery_catalog (name, default_category, default_unit, search_keywords) VALUES

-- ===================== AFRICAN STAPLES (new category) =====================
('Fufu Flour', 'African Staples', 'kg', 'fufu cassava plantain yam'),
('Garri', 'African Staples', 'kg', 'garri cassava eba'),
('Eba', 'African Staples', 'kg', 'eba garri cassava'),
('Pounded Yam Flour', 'African Staples', 'kg', 'pounded yam iyan'),
('Semolina', 'African Staples', 'kg', 'semolina pap akamu'),
('Oatmeal Pap', 'African Staples', 'kg', 'pap oatmeal akamu'),
('Parboiled Rice', 'Grains', 'kg', 'rice parboiled long grain'),
('Jollof Rice', 'Grains', 'kg', 'rice jollof nigerian'),

-- ===================== GRAINS (existing) =====================
('Couscous', 'Grains', 'g', 'grain couscous'),
('Wheat Flour', 'Grains', 'kg', 'grain flour baking'),

-- ===================== VEGETABLES (existing) =====================
('Okra', 'Vegetables', 'g', 'vegetable okra ladies fingers'),
('Bitter Leaf', 'Vegetables', 'g', 'vegetable bitter leaf efirin'),
('Ugu', 'Vegetables', 'g', 'vegetable pumpkin leaves'),
('Waterleaf', 'Vegetables', 'g', 'vegetable waterleaf'),
('Scotch Bonnet', 'Vegetables', 'pcs', 'vegetable pepper hot'),
('Garden Eggs', 'Vegetables', 'pcs', 'vegetable eggplant african'),
('Egusi', 'Vegetables', 'g', 'vegetable melon seeds'),
('Ogbono', 'Vegetables', 'g', 'vegetable ogbono soup thickener'),

-- ===================== AFRICAN SPICES & SEASONINGS (new category) =====================
('Suya Spice', 'African Spices', 'g', 'suya spice yaji seasoning'),
('Yaji', 'African Spices', 'g', 'yaji suya spice seasoning'),
('Maggi Cubes', 'African Spices', 'pcs', 'maggi stock cube seasoning'),
('Knorr Cubes', 'African Spices', 'pcs', 'knorr stock cube seasoning'),
('Ground Crayfish', 'African Spices', 'g', 'crayfish seasoning'),
('Dry Pepper', 'African Spices', 'g', 'pepper ground spice'),
('Alligator Pepper', 'African Spices', 'g', 'alligator pepper spice'),
('Ehuru', 'African Spices', 'g', 'ehuru calabash nutmeg spice'),
('Uziza', 'African Spices', 'g', 'uziza spice leaves'),
('Utazi', 'African Spices', 'g', 'utazi spice leaves'),
('Scent Leaves', 'African Spices', 'g', 'scent leaves efirin basil'),

-- ===================== CONDIMENTS (existing) =====================
('Palm Oil', 'Condiments', 'ml', 'oil palm red cooking'),
('Red Palm Oil', 'Condiments', 'ml', 'oil palm red'),
('Groundnut Oil', 'Condiments', 'ml', 'oil groundnut peanut'),

-- ===================== OTHER / CANNED (existing) =====================
('Black-Eyed Peas', 'Other', 'g', 'beans black eyed peas'),
('Honey Beans', 'Other', 'g', 'beans honey'),
('Brown Beans', 'Other', 'g', 'beans brown'),
('Canned Sardines', 'Seafood', 'pcs', 'fish sardines tinned'),
('Canned Mackerel', 'Seafood', 'pcs', 'fish mackerel tinned'),
('Evaporated Milk', 'Dairy', 'ml', 'dairy milk canned'),
('Condensed Milk', 'Dairy', 'ml', 'dairy milk sweetened canned'),
('Coconut Milk', 'Other', 'ml', 'tinned coconut cooking'),
('Plantain Chips', 'Snacks', 'g', 'snack plantain chips'),
('Indomie', 'Other', 'pcs', 'noodles instant indomie'),

-- ===================== BEVERAGES (existing) =====================
('Malta Guinness', 'Beverages', 'ml', 'beverage malt drink'),
('Amstel Malta', 'Beverages', 'ml', 'beverage malt drink'),
('Chapman', 'Beverages', 'ml', 'beverage chapman cocktail'),
('Zobo', 'Beverages', 'g', 'beverage zobo hibiscus'),
('Milo', 'Beverages', 'g', 'beverage chocolate malt'),
('Ovaltine', 'Beverages', 'g', 'beverage chocolate malt'),

-- ===================== SNACKS (existing) =====================
('Chin Chin', 'Snacks', 'g', 'snack chin chin'),
('Puff Puff Mix', 'Snacks', 'g', 'snack puff puff'),
('Groundnuts', 'Snacks', 'g', 'snack peanuts groundnuts'),
('Kuli Kuli', 'Snacks', 'g', 'snack kuli kuli'),
('Suya', 'Snacks', 'g', 'snack suya meat'),
('Meat Pie', 'Snacks', 'pcs', 'snack meat pie'),
('Sausage Roll', 'Snacks', 'pcs', 'snack sausage roll'),

-- ===================== MEAT (existing) =====================
('Stockfish', 'Seafood', 'kg', 'fish stockfish dried'),
('Smoked Fish', 'Seafood', 'kg', 'fish smoked dried'),
('Dry Fish', 'Seafood', 'kg', 'fish dried'),
('Ponmo', 'Meat', 'kg', 'meat cow skin ponmo'),
('Shaki', 'Meat', 'kg', 'meat tripe shaki'),
('Oxtail', 'Meat', 'kg', 'meat oxtail'),
('Goat Meat', 'Meat', 'kg', 'meat goat')

ON CONFLICT (name) DO NOTHING;
