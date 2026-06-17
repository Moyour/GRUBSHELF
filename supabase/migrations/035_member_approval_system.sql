-- GrubShelf Migration 035: Member approval system for pantry and shopping items
-- Members submit items as pending; admins insert approved items directly.

-- ============================================================
-- 1. Approval columns on pantry_items
-- ============================================================
ALTER TABLE pantry_items
    ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL
        DEFAULT 'approved'
        CHECK (approval_status IN ('approved', 'pending', 'rejected')),
    ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_pantry_items_approval_status
    ON pantry_items (household_id, approval_status);

-- ============================================================
-- 2. Approval columns on shopping_items
-- ============================================================
ALTER TABLE shopping_items
    ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL
        DEFAULT 'approved'
        CHECK (approval_status IN ('approved', 'pending', 'rejected')),
    ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_shopping_items_approval_status
    ON shopping_items (household_id, approval_status);

-- Backfill existing rows
UPDATE pantry_items SET approval_status = 'approved' WHERE approval_status IS NULL;
UPDATE shopping_items SET approval_status = 'approved' WHERE approval_status IS NULL;

-- ============================================================
-- 3. Helper: is current user the creator of an item
-- ============================================================
CREATE OR REPLACE FUNCTION is_item_creator(p_created_by UUID)
RETURNS BOOLEAN AS $$
    SELECT p_created_by = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- 4. Pantry items RLS policies
-- ============================================================
DROP POLICY IF EXISTS "Members can insert pantry items" ON pantry_items;
DROP POLICY IF EXISTS "Members can update pantry items" ON pantry_items;
DROP POLICY IF EXISTS "Admins can delete pantry items" ON pantry_items;

CREATE POLICY "Admins can insert approved pantry items"
    ON pantry_items FOR INSERT
    WITH CHECK (
        household_id = get_my_household_id()
        AND is_household_admin()
        AND approval_status = 'approved'
    );

CREATE POLICY "Members can insert pending pantry items"
    ON pantry_items FOR INSERT
    WITH CHECK (
        household_id = get_my_household_id()
        AND NOT is_household_admin()
        AND approval_status = 'pending'
        AND created_by = auth.uid()
    );

CREATE POLICY "Admins can update pantry items"
    ON pantry_items FOR UPDATE
    USING (
        household_id = get_my_household_id()
        AND is_household_admin()
    );

CREATE POLICY "Members can update own pending pantry items"
    ON pantry_items FOR UPDATE
    USING (
        household_id = get_my_household_id()
        AND NOT is_household_admin()
        AND approval_status = 'pending'
        AND is_item_creator(created_by)
    );

CREATE POLICY "Admins can delete pantry items"
    ON pantry_items FOR DELETE
    USING (
        household_id = get_my_household_id()
        AND is_household_admin()
    );

-- Members can read all household pantry rows (approved + pending + rejected for own visibility)
-- Existing "Members can read household pantry" policy unchanged.

-- ============================================================
-- 5. Shopping items RLS policies
-- ============================================================
DROP POLICY IF EXISTS "Members can insert shopping items" ON shopping_items;
DROP POLICY IF EXISTS "Members can update shopping items" ON shopping_items;
DROP POLICY IF EXISTS "Members can delete shopping items" ON shopping_items;

CREATE POLICY "Admins can insert approved shopping items"
    ON shopping_items FOR INSERT
    WITH CHECK (
        household_id = get_my_household_id()
        AND is_household_admin()
        AND approval_status = 'approved'
    );

CREATE POLICY "Members can insert pending shopping items"
    ON shopping_items FOR INSERT
    WITH CHECK (
        household_id = get_my_household_id()
        AND NOT is_household_admin()
        AND approval_status = 'pending'
        AND created_by = auth.uid()
    );

CREATE POLICY "Admins can update shopping items"
    ON shopping_items FOR UPDATE
    USING (
        household_id = get_my_household_id()
        AND is_household_admin()
    );

CREATE POLICY "Members can update own pending shopping items"
    ON shopping_items FOR UPDATE
    USING (
        household_id = get_my_household_id()
        AND NOT is_household_admin()
        AND approval_status = 'pending'
        AND is_item_creator(created_by)
    );

CREATE POLICY "Admins can delete shopping items"
    ON shopping_items FOR DELETE
    USING (
        household_id = get_my_household_id()
        AND is_household_admin()
    );
