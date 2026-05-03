-- =============================================================
-- GrubShelf: ALL MIGRATIONS COMBINED (001 + 002 + 003)
-- Paste this entire script into Supabase SQL Editor and run once
-- =============================================================

-- =============================================================
-- MIGRATION 001: Initial Schema
-- =============================================================

-- 1. Households table
CREATE TABLE households (
    household_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    plan_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Users table
CREATE TABLE users (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    household_id UUID REFERENCES households(household_id) ON DELETE SET NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'member')) DEFAULT 'member',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Pantry items table
CREATE TABLE pantry_items (
    item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 120),
    quantity DOUBLE PRECISION NOT NULL CHECK (quantity >= 0),
    unit TEXT NOT NULL CHECK (unit IN ('g', 'kg', 'ml', 'l', 'pcs')),
    category TEXT NOT NULL CHECK (char_length(category) BETWEEN 1 AND 40),
    expiry_date TIMESTAMPTZ,
    cost_per_unit_minor INTEGER CHECK (cost_per_unit_minor >= 0),
    low_stock_threshold DOUBLE PRECISION NOT NULL DEFAULT 1,
    created_by UUID NOT NULL REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    archived BOOLEAN NOT NULL DEFAULT false
);

-- 4. Shopping items table
CREATE TABLE shopping_items (
    item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    quantity DOUBLE PRECISION NOT NULL CHECK (quantity >= 0),
    unit TEXT CHECK (unit IN ('g', 'kg', 'ml', 'l', 'pcs')),
    completed BOOLEAN NOT NULL DEFAULT false,
    created_by UUID NOT NULL REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Transactions table
CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    item_id UUID REFERENCES pantry_items(item_id) ON DELETE SET NULL,
    quantity_purchased DOUBLE PRECISION NOT NULL,
    total_cost_minor INTEGER NOT NULL,
    cost_per_unit_minor INTEGER NOT NULL,
    purchase_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    store_name TEXT CHECK (char_length(store_name) <= 80)
);

-- 6. Composite indexes
CREATE INDEX idx_pantry_household_expiry ON pantry_items (household_id, expiry_date);
CREATE INDEX idx_shopping_household_completed ON shopping_items (household_id, completed);
CREATE INDEX idx_transactions_household_date ON transactions (household_id, purchase_date);

-- 7. Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_users
    BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_pantry_items
    BEFORE UPDATE ON pantry_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_shopping_items
    BEFORE UPDATE ON shopping_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 8. Row Level Security
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE pantry_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE shopping_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Helper: get current user's household_id
CREATE OR REPLACE FUNCTION get_my_household_id()
RETURNS UUID AS $$
    SELECT household_id FROM users WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper: check if current user is admin
CREATE OR REPLACE FUNCTION is_household_admin()
RETURNS BOOLEAN AS $$
    SELECT role = 'admin' FROM users WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Users policies
CREATE POLICY "Users can read own row"
    ON users FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update own row"
    ON users FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users can insert own row"
    ON users FOR INSERT WITH CHECK (user_id = auth.uid());

-- Households policies
CREATE POLICY "Members can read own household"
    ON households FOR SELECT USING (household_id = get_my_household_id());

CREATE POLICY "Anyone can create a household"
    ON households FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can update household"
    ON households FOR UPDATE USING (
        household_id = get_my_household_id() AND is_household_admin()
    );

CREATE POLICY "Admins can delete household"
    ON households FOR DELETE USING (
        household_id = get_my_household_id() AND is_household_admin()
    );

-- Pantry items policies
CREATE POLICY "Members can read household pantry"
    ON pantry_items FOR SELECT USING (household_id = get_my_household_id());

CREATE POLICY "Members can insert pantry items"
    ON pantry_items FOR INSERT WITH CHECK (household_id = get_my_household_id());

CREATE POLICY "Members can update pantry items"
    ON pantry_items FOR UPDATE USING (household_id = get_my_household_id());

CREATE POLICY "Admins can delete pantry items"
    ON pantry_items FOR DELETE USING (
        household_id = get_my_household_id() AND is_household_admin()
    );

-- Shopping items policies
CREATE POLICY "Members can read household shopping"
    ON shopping_items FOR SELECT USING (household_id = get_my_household_id());

CREATE POLICY "Members can insert shopping items"
    ON shopping_items FOR INSERT WITH CHECK (household_id = get_my_household_id());

CREATE POLICY "Members can update shopping items"
    ON shopping_items FOR UPDATE USING (household_id = get_my_household_id());

CREATE POLICY "Admins can delete shopping items"
    ON shopping_items FOR DELETE USING (
        household_id = get_my_household_id() AND is_household_admin()
    );

-- Transactions policies
CREATE POLICY "Members can read household transactions"
    ON transactions FOR SELECT USING (household_id = get_my_household_id());

CREATE POLICY "Members can insert transactions"
    ON transactions FOR INSERT WITH CHECK (household_id = get_my_household_id());

-- Enable realtime for sync
ALTER PUBLICATION supabase_realtime ADD TABLE pantry_items;
ALTER PUBLICATION supabase_realtime ADD TABLE shopping_items;

-- =============================================================
-- MIGRATION 002: Shopping Lists & Grocery Catalog
-- =============================================================

-- 1. Grocery catalog table (read-only reference)
CREATE TABLE grocery_catalog (
    catalog_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    default_category TEXT NOT NULL,
    default_unit TEXT NOT NULL CHECK (default_unit IN ('g', 'kg', 'ml', 'l', 'pcs')),
    search_keywords TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_grocery_catalog_name ON grocery_catalog (lower(name));

-- RLS: any authenticated user can SELECT only
ALTER TABLE grocery_catalog ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read catalog"
    ON grocery_catalog FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- 2. Shopping lists table
CREATE TABLE shopping_lists (
    list_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
    created_by UUID NOT NULL REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_shopping_lists_household ON shopping_lists (household_id);

CREATE TRIGGER set_updated_at_shopping_lists
    BEFORE UPDATE ON shopping_lists FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE shopping_lists ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read household lists"
    ON shopping_lists FOR SELECT USING (household_id = get_my_household_id());

CREATE POLICY "Members can insert lists"
    ON shopping_lists FOR INSERT WITH CHECK (household_id = get_my_household_id());

CREATE POLICY "Members can update lists"
    ON shopping_lists FOR UPDATE USING (household_id = get_my_household_id());

CREATE POLICY "Members can delete lists"
    ON shopping_lists FOR DELETE USING (household_id = get_my_household_id());

ALTER PUBLICATION supabase_realtime ADD TABLE shopping_lists;

-- 3. Add columns to shopping_items
ALTER TABLE shopping_items
    ADD COLUMN list_id UUID REFERENCES shopping_lists(list_id) ON DELETE CASCADE,
    ADD COLUMN category TEXT;

CREATE INDEX idx_shopping_items_list_completed ON shopping_items (list_id, completed);

-- 4. Update shopping_items delete policy: members can delete (needed for transfer flow)
DROP POLICY "Admins can delete shopping items" ON shopping_items;

CREATE POLICY "Members can delete shopping items"
    ON shopping_items FOR DELETE USING (household_id = get_my_household_id());

-- =============================================================
-- MIGRATION 003: Seed Grocery Catalog (200+ items)
-- =============================================================

INSERT INTO grocery_catalog (name, default_category, default_unit, search_keywords) VALUES
-- Fruits
('Apple', 'Fruits', 'pcs', 'fruit red green'),
('Banana', 'Fruits', 'pcs', 'fruit yellow'),
('Orange', 'Fruits', 'pcs', 'fruit citrus'),
('Strawberry', 'Fruits', 'pcs', 'fruit berry'),
('Blueberry', 'Fruits', 'pcs', 'fruit berry'),
('Raspberry', 'Fruits', 'pcs', 'fruit berry'),
('Grape', 'Fruits', 'kg', 'fruit'),
('Mango', 'Fruits', 'pcs', 'fruit tropical'),
('Pineapple', 'Fruits', 'pcs', 'fruit tropical'),
('Watermelon', 'Fruits', 'pcs', 'fruit melon'),
('Lemon', 'Fruits', 'pcs', 'fruit citrus'),
('Lime', 'Fruits', 'pcs', 'fruit citrus'),
('Avocado', 'Fruits', 'pcs', 'fruit'),
('Peach', 'Fruits', 'pcs', 'fruit stone'),
('Pear', 'Fruits', 'pcs', 'fruit'),
('Plum', 'Fruits', 'pcs', 'fruit stone'),
('Cherry', 'Fruits', 'kg', 'fruit stone'),
('Kiwi', 'Fruits', 'pcs', 'fruit tropical'),
('Coconut', 'Fruits', 'pcs', 'fruit tropical'),
('Grapefruit', 'Fruits', 'pcs', 'fruit citrus'),

-- Vegetables
('Tomato', 'Vegetables', 'pcs', 'vegetable red'),
('Potato', 'Vegetables', 'kg', 'vegetable starch'),
('Onion', 'Vegetables', 'pcs', 'vegetable'),
('Garlic', 'Vegetables', 'pcs', 'vegetable'),
('Carrot', 'Vegetables', 'pcs', 'vegetable root'),
('Broccoli', 'Vegetables', 'pcs', 'vegetable green'),
('Spinach', 'Vegetables', 'g', 'vegetable leafy green'),
('Lettuce', 'Vegetables', 'pcs', 'vegetable leafy green salad'),
('Cucumber', 'Vegetables', 'pcs', 'vegetable green'),
('Bell Pepper', 'Vegetables', 'pcs', 'vegetable pepper capsicum'),
('Mushroom', 'Vegetables', 'g', 'vegetable fungi'),
('Zucchini', 'Vegetables', 'pcs', 'vegetable squash'),
('Sweet Potato', 'Vegetables', 'kg', 'vegetable starch'),
('Corn', 'Vegetables', 'pcs', 'vegetable'),
('Green Beans', 'Vegetables', 'g', 'vegetable'),
('Cauliflower', 'Vegetables', 'pcs', 'vegetable'),
('Celery', 'Vegetables', 'pcs', 'vegetable stalk'),
('Asparagus', 'Vegetables', 'g', 'vegetable'),
('Kale', 'Vegetables', 'g', 'vegetable leafy green'),
('Cabbage', 'Vegetables', 'pcs', 'vegetable'),
('Eggplant', 'Vegetables', 'pcs', 'vegetable aubergine'),
('Ginger', 'Vegetables', 'g', 'vegetable root spice'),
('Jalapeño', 'Vegetables', 'pcs', 'vegetable pepper hot'),
('Radish', 'Vegetables', 'pcs', 'vegetable root'),
('Beetroot', 'Vegetables', 'pcs', 'vegetable root'),

-- Dairy
('Whole Milk', 'Dairy', 'l', 'dairy milk'),
('Semi-Skimmed Milk', 'Dairy', 'l', 'dairy milk low fat'),
('Skimmed Milk', 'Dairy', 'l', 'dairy milk fat free'),
('Oat Milk', 'Dairy', 'l', 'dairy alternative plant milk'),
('Almond Milk', 'Dairy', 'l', 'dairy alternative plant milk'),
('Butter', 'Dairy', 'g', 'dairy spread'),
('Cheddar Cheese', 'Dairy', 'g', 'dairy cheese'),
('Mozzarella', 'Dairy', 'g', 'dairy cheese italian'),
('Parmesan', 'Dairy', 'g', 'dairy cheese italian hard'),
('Cream Cheese', 'Dairy', 'g', 'dairy cheese spread'),
('Feta Cheese', 'Dairy', 'g', 'dairy cheese greek'),
('Greek Yogurt', 'Dairy', 'g', 'dairy yogurt'),
('Natural Yogurt', 'Dairy', 'g', 'dairy yogurt plain'),
('Double Cream', 'Dairy', 'ml', 'dairy cream'),
('Single Cream', 'Dairy', 'ml', 'dairy cream'),
('Sour Cream', 'Dairy', 'ml', 'dairy cream'),
('Eggs', 'Dairy', 'pcs', 'dairy eggs protein'),
('Cottage Cheese', 'Dairy', 'g', 'dairy cheese'),
('Gouda Cheese', 'Dairy', 'g', 'dairy cheese dutch'),
('Brie', 'Dairy', 'g', 'dairy cheese french soft'),

-- Meat
('Chicken Breast', 'Meat', 'kg', 'meat poultry'),
('Chicken Thigh', 'Meat', 'kg', 'meat poultry'),
('Whole Chicken', 'Meat', 'kg', 'meat poultry'),
('Chicken Wings', 'Meat', 'kg', 'meat poultry'),
('Ground Beef', 'Meat', 'kg', 'meat mince'),
('Beef Steak', 'Meat', 'kg', 'meat steak sirloin'),
('Beef Roast', 'Meat', 'kg', 'meat roast'),
('Pork Chop', 'Meat', 'kg', 'meat pork'),
('Pork Loin', 'Meat', 'kg', 'meat pork'),
('Bacon', 'Meat', 'g', 'meat pork breakfast'),
('Ham', 'Meat', 'g', 'meat pork deli'),
('Sausage', 'Meat', 'pcs', 'meat pork'),
('Turkey Breast', 'Meat', 'kg', 'meat poultry deli'),
('Ground Turkey', 'Meat', 'kg', 'meat poultry mince'),
('Lamb Chop', 'Meat', 'kg', 'meat lamb'),
('Lamb Leg', 'Meat', 'kg', 'meat lamb roast'),
('Salami', 'Meat', 'g', 'meat deli italian'),
('Pepperoni', 'Meat', 'g', 'meat deli italian'),
('Prosciutto', 'Meat', 'g', 'meat deli italian'),
('Beef Mince', 'Meat', 'kg', 'meat ground'),

-- Seafood
('Salmon Fillet', 'Seafood', 'kg', 'fish seafood'),
('Tuna Steak', 'Seafood', 'kg', 'fish seafood'),
('Canned Tuna', 'Seafood', 'pcs', 'fish seafood tinned'),
('Shrimp', 'Seafood', 'kg', 'seafood prawn shellfish'),
('Cod Fillet', 'Seafood', 'kg', 'fish seafood white'),
('Haddock', 'Seafood', 'kg', 'fish seafood white'),
('Sea Bass', 'Seafood', 'kg', 'fish seafood'),
('Tilapia', 'Seafood', 'kg', 'fish seafood white'),
('Crab', 'Seafood', 'kg', 'seafood shellfish'),
('Lobster', 'Seafood', 'kg', 'seafood shellfish'),
('Mussels', 'Seafood', 'kg', 'seafood shellfish'),
('Sardines', 'Seafood', 'pcs', 'fish seafood tinned'),
('Anchovies', 'Seafood', 'g', 'fish seafood'),
('Calamari', 'Seafood', 'kg', 'seafood squid'),
('Clams', 'Seafood', 'kg', 'seafood shellfish'),

-- Grains
('White Rice', 'Grains', 'kg', 'grain rice'),
('Brown Rice', 'Grains', 'kg', 'grain rice whole'),
('Basmati Rice', 'Grains', 'kg', 'grain rice'),
('Jasmine Rice', 'Grains', 'kg', 'grain rice'),
('Spaghetti', 'Grains', 'g', 'grain pasta'),
('Penne', 'Grains', 'g', 'grain pasta'),
('Fusilli', 'Grains', 'g', 'grain pasta'),
('Macaroni', 'Grains', 'g', 'grain pasta'),
('Linguine', 'Grains', 'g', 'grain pasta'),
('Lasagna Sheets', 'Grains', 'g', 'grain pasta'),
('White Bread', 'Grains', 'pcs', 'grain bread'),
('Whole Wheat Bread', 'Grains', 'pcs', 'grain bread whole'),
('Sourdough Bread', 'Grains', 'pcs', 'grain bread'),
('Tortilla', 'Grains', 'pcs', 'grain wrap flatbread'),
('Naan Bread', 'Grains', 'pcs', 'grain bread indian'),
('Oats', 'Grains', 'kg', 'grain cereal breakfast'),
('Cornflakes', 'Grains', 'g', 'grain cereal breakfast'),
('Granola', 'Grains', 'g', 'grain cereal breakfast'),
('Flour', 'Grains', 'kg', 'grain baking'),
('Couscous', 'Grains', 'g', 'grain'),
('Quinoa', 'Grains', 'g', 'grain seed'),
('Bagel', 'Grains', 'pcs', 'grain bread'),

-- Snacks
('Potato Chips', 'Snacks', 'g', 'snack crisp'),
('Tortilla Chips', 'Snacks', 'g', 'snack nacho'),
('Popcorn', 'Snacks', 'g', 'snack'),
('Pretzels', 'Snacks', 'g', 'snack'),
('Trail Mix', 'Snacks', 'g', 'snack nuts'),
('Almonds', 'Snacks', 'g', 'snack nut'),
('Cashews', 'Snacks', 'g', 'snack nut'),
('Peanuts', 'Snacks', 'g', 'snack nut'),
('Walnuts', 'Snacks', 'g', 'snack nut'),
('Dark Chocolate', 'Snacks', 'g', 'snack chocolate'),
('Milk Chocolate', 'Snacks', 'g', 'snack chocolate'),
('Cookies', 'Snacks', 'pcs', 'snack biscuit'),
('Crackers', 'Snacks', 'g', 'snack'),
('Granola Bar', 'Snacks', 'pcs', 'snack energy bar'),
('Dried Fruit', 'Snacks', 'g', 'snack fruit'),
('Rice Cakes', 'Snacks', 'pcs', 'snack'),
('Hummus', 'Snacks', 'g', 'snack dip chickpea'),
('Salsa', 'Snacks', 'g', 'snack dip tomato'),
('Guacamole', 'Snacks', 'g', 'snack dip avocado'),

-- Beverages
('Water', 'Beverages', 'l', 'beverage drink'),
('Sparkling Water', 'Beverages', 'l', 'beverage drink carbonated'),
('Orange Juice', 'Beverages', 'l', 'beverage juice'),
('Apple Juice', 'Beverages', 'l', 'beverage juice'),
('Cranberry Juice', 'Beverages', 'l', 'beverage juice'),
('Coffee Beans', 'Beverages', 'g', 'beverage coffee'),
('Ground Coffee', 'Beverages', 'g', 'beverage coffee'),
('Instant Coffee', 'Beverages', 'g', 'beverage coffee'),
('Black Tea', 'Beverages', 'pcs', 'beverage tea bags'),
('Green Tea', 'Beverages', 'pcs', 'beverage tea bags'),
('Herbal Tea', 'Beverages', 'pcs', 'beverage tea bags'),
('Cola', 'Beverages', 'l', 'beverage soda'),
('Lemonade', 'Beverages', 'l', 'beverage'),
('Coconut Water', 'Beverages', 'l', 'beverage drink'),
('Sports Drink', 'Beverages', 'l', 'beverage energy'),
('Smoothie', 'Beverages', 'ml', 'beverage fruit'),

-- Frozen
('Frozen Pizza', 'Frozen', 'pcs', 'frozen meal'),
('Frozen Peas', 'Frozen', 'g', 'frozen vegetable'),
('Frozen Corn', 'Frozen', 'g', 'frozen vegetable'),
('Frozen Broccoli', 'Frozen', 'g', 'frozen vegetable'),
('Frozen Mixed Vegetables', 'Frozen', 'g', 'frozen vegetable'),
('Frozen Berries', 'Frozen', 'g', 'frozen fruit'),
('Frozen Strawberries', 'Frozen', 'g', 'frozen fruit'),
('Fish Fingers', 'Frozen', 'pcs', 'frozen fish'),
('Frozen Chicken Nuggets', 'Frozen', 'g', 'frozen meat poultry'),
('Frozen French Fries', 'Frozen', 'g', 'frozen potato chips'),
('Ice Cream', 'Frozen', 'ml', 'frozen dessert'),
('Frozen Waffles', 'Frozen', 'pcs', 'frozen breakfast'),
('Frozen Dumplings', 'Frozen', 'g', 'frozen meal asian'),
('Frozen Shrimp', 'Frozen', 'g', 'frozen seafood'),
('Frozen Bread Rolls', 'Frozen', 'pcs', 'frozen bread'),

-- Condiments
('Olive Oil', 'Condiments', 'ml', 'condiment oil cooking'),
('Vegetable Oil', 'Condiments', 'ml', 'condiment oil cooking'),
('Coconut Oil', 'Condiments', 'ml', 'condiment oil cooking'),
('Soy Sauce', 'Condiments', 'ml', 'condiment sauce asian'),
('Ketchup', 'Condiments', 'ml', 'condiment sauce tomato'),
('Mustard', 'Condiments', 'ml', 'condiment sauce'),
('Mayonnaise', 'Condiments', 'ml', 'condiment sauce'),
('Hot Sauce', 'Condiments', 'ml', 'condiment sauce spicy'),
('Vinegar', 'Condiments', 'ml', 'condiment'),
('Balsamic Vinegar', 'Condiments', 'ml', 'condiment'),
('Honey', 'Condiments', 'g', 'condiment sweetener'),
('Maple Syrup', 'Condiments', 'ml', 'condiment sweetener'),
('Salt', 'Condiments', 'g', 'condiment seasoning'),
('Black Pepper', 'Condiments', 'g', 'condiment seasoning spice'),
('Paprika', 'Condiments', 'g', 'condiment seasoning spice'),
('Cumin', 'Condiments', 'g', 'condiment seasoning spice'),
('Cinnamon', 'Condiments', 'g', 'condiment seasoning spice'),
('Oregano', 'Condiments', 'g', 'condiment herb'),
('Basil', 'Condiments', 'g', 'condiment herb'),
('Tomato Paste', 'Condiments', 'g', 'condiment sauce tomato'),
('Worcestershire Sauce', 'Condiments', 'ml', 'condiment sauce'),
('BBQ Sauce', 'Condiments', 'ml', 'condiment sauce'),
('Peanut Butter', 'Condiments', 'g', 'condiment spread'),
('Jam', 'Condiments', 'g', 'condiment spread'),
('Nutella', 'Condiments', 'g', 'condiment spread chocolate'),

-- Other
('Sugar', 'Other', 'kg', 'baking sweetener'),
('Brown Sugar', 'Other', 'kg', 'baking sweetener'),
('Baking Powder', 'Other', 'g', 'baking'),
('Baking Soda', 'Other', 'g', 'baking'),
('Vanilla Extract', 'Other', 'ml', 'baking flavoring'),
('Cocoa Powder', 'Other', 'g', 'baking chocolate'),
('Cornstarch', 'Other', 'g', 'baking thickener'),
('Gelatin', 'Other', 'g', 'baking'),
('Canned Tomatoes', 'Other', 'pcs', 'tinned tomato'),
('Canned Beans', 'Other', 'pcs', 'tinned legume'),
('Chickpeas', 'Other', 'pcs', 'tinned legume'),
('Lentils', 'Other', 'g', 'legume'),
('Coconut Milk', 'Other', 'ml', 'tinned cooking asian'),
('Chicken Broth', 'Other', 'ml', 'stock soup'),
('Vegetable Broth', 'Other', 'ml', 'stock soup'),
('Tofu', 'Other', 'g', 'protein plant soy'),
('Tempeh', 'Other', 'g', 'protein plant soy'),
('Paper Towels', 'Other', 'pcs', 'household cleaning'),
('Dish Soap', 'Other', 'ml', 'household cleaning'),
('Trash Bags', 'Other', 'pcs', 'household cleaning');

-- =============================================================
-- MIGRATION 012: Add transferred column to shopping_items
-- =============================================================
ALTER TABLE shopping_items ADD COLUMN IF NOT EXISTS transferred BOOLEAN NOT NULL DEFAULT false;

-- =============================================================
-- MIGRATION 013: Create delete_user_data RPC function
-- =============================================================
CREATE OR REPLACE FUNCTION public.delete_user_data(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_household_id UUID;
    v_member_count INT;
BEGIN
    SELECT household_id INTO v_household_id
    FROM public.users
    WHERE user_id = p_user_id;

    DELETE FROM public.shopping_items WHERE created_by = p_user_id;
    DELETE FROM public.shopping_lists WHERE created_by = p_user_id;
    DELETE FROM public.transactions WHERE household_id = v_household_id
        AND item_id IN (SELECT item_id FROM public.pantry_items WHERE created_by = p_user_id);
    DELETE FROM public.pantry_items WHERE created_by = p_user_id;
    DELETE FROM public.household_invites WHERE invited_by = p_user_id;

    IF v_household_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_member_count
        FROM public.users
        WHERE household_id = v_household_id AND user_id != p_user_id;

        IF v_member_count = 0 THEN
            DELETE FROM public.households WHERE household_id = v_household_id;
        END IF;
    END IF;

    DELETE FROM public.users WHERE user_id = p_user_id;
    DELETE FROM auth.users WHERE id = p_user_id;
END;
$$;

-- =============================================================
-- MIGRATION 014: Usage tracking and reminder fields
-- =============================================================
ALTER TABLE pantry_items ADD COLUMN IF NOT EXISTS last_quantity_update_date TIMESTAMPTZ DEFAULT now();
ALTER TABLE pantry_items ADD COLUMN IF NOT EXISTS expected_usage_cycle_days INT;
ALTER TABLE pantry_items ADD COLUMN IF NOT EXISTS reminder_status TEXT NOT NULL DEFAULT 'active'
    CHECK (reminder_status IN ('active', 'snoozed', 'dismissed'));
ALTER TABLE pantry_items ADD COLUMN IF NOT EXISTS reminder_snoozed_until TIMESTAMPTZ;

UPDATE pantry_items SET last_quantity_update_date = updated_at
    WHERE last_quantity_update_date IS NULL OR last_quantity_update_date = now();

CREATE INDEX IF NOT EXISTS idx_pantry_items_usage_tracking
    ON pantry_items (household_id, reminder_status, last_quantity_update_date);

-- =============================================================
-- MIGRATION 022: Household barcode labels (saved pantry names per scan)
-- =============================================================
CREATE TABLE IF NOT EXISTS household_barcode_labels (
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    barcode TEXT NOT NULL CHECK (
        char_length(barcode) BETWEEN 8 AND 14
        AND barcode ~ '^[0-9]+$'
    ),
    display_name TEXT NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 120),
    category TEXT NOT NULL CHECK (char_length(category) BETWEEN 1 AND 40),
    catalog_item_id UUID REFERENCES grocery_catalog(catalog_item_id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (household_id, barcode)
);

CREATE INDEX IF NOT EXISTS idx_household_barcode_labels_household
    ON household_barcode_labels (household_id);

DROP TRIGGER IF EXISTS set_updated_at_household_barcode_labels ON household_barcode_labels;
CREATE TRIGGER set_updated_at_household_barcode_labels
    BEFORE UPDATE ON household_barcode_labels FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE household_barcode_labels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members can read household barcode labels" ON household_barcode_labels;
CREATE POLICY "Members can read household barcode labels"
    ON household_barcode_labels FOR SELECT USING (household_id = get_my_household_id());

DROP POLICY IF EXISTS "Members can insert household barcode labels" ON household_barcode_labels;
CREATE POLICY "Members can insert household barcode labels"
    ON household_barcode_labels FOR INSERT WITH CHECK (household_id = get_my_household_id());

DROP POLICY IF EXISTS "Members can update household barcode labels" ON household_barcode_labels;
CREATE POLICY "Members can update household barcode labels"
    ON household_barcode_labels FOR UPDATE USING (household_id = get_my_household_id());

DROP POLICY IF EXISTS "Members can delete household barcode labels" ON household_barcode_labels;
CREATE POLICY "Members can delete household barcode labels"
    ON household_barcode_labels FOR DELETE USING (household_id = get_my_household_id());

-- =============================================================
-- MIGRATION 023: Pantry storage location
-- =============================================================

ALTER TABLE pantry_items
ADD COLUMN IF NOT EXISTS storage_location TEXT NOT NULL DEFAULT 'shelf'
CHECK (storage_location IN ('fridge', 'shelf'));

COMMENT ON COLUMN pantry_items.storage_location IS 'Where the item is stored: fridge or shelf';

-- =============================================================
-- MIGRATION 025: Pantry item photos
-- =============================================================

ALTER TABLE pantry_items
ADD COLUMN IF NOT EXISTS photo_path TEXT;

COMMENT ON COLUMN pantry_items.photo_path IS 'Supabase Storage object path for pantry item photo (bucket pantry-item-photos).';

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'pantry-item-photos',
    'pantry-item-photos',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Members can read pantry item photos" ON storage.objects;
CREATE POLICY "Members can read pantry item photos"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'pantry-item-photos'
        AND (storage.foldername(name))[1] = get_my_household_id()::text
    );

DROP POLICY IF EXISTS "Members can upload pantry item photos" ON storage.objects;
CREATE POLICY "Members can upload pantry item photos"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'pantry-item-photos'
        AND (storage.foldername(name))[1] = get_my_household_id()::text
    );

DROP POLICY IF EXISTS "Members can update pantry item photos" ON storage.objects;
CREATE POLICY "Members can update pantry item photos"
    ON storage.objects FOR UPDATE TO authenticated
    USING (
        bucket_id = 'pantry-item-photos'
        AND (storage.foldername(name))[1] = get_my_household_id()::text
    )
    WITH CHECK (
        bucket_id = 'pantry-item-photos'
        AND (storage.foldername(name))[1] = get_my_household_id()::text
    );

DROP POLICY IF EXISTS "Members can delete pantry item photos" ON storage.objects;
CREATE POLICY "Members can delete pantry item photos"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'pantry-item-photos'
        AND (storage.foldername(name))[1] = get_my_household_id()::text
    );

-- =============================================================
-- DONE! Includes migrations through 025.
-- For existing projects, run individual 022_ / 023_ / 025_ scripts in the
-- SQL Editor if you do not re-run this full script.
-- =============================================================
