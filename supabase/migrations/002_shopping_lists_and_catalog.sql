-- FoodPan Migration 002: Shopping Lists & Grocery Catalog
-- Adds multiple shopping lists, grocery catalog for search, and shopping item enhancements

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
