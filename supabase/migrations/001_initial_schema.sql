-- GrubShelf Initial Schema Migration
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)

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

-- 6. Composite indexes for common queries
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
