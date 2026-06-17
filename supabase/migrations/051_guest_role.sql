-- GrubShelf Migration 051: Guest role read-only policies
-- role CHECK already includes guest from migration 041

DROP POLICY IF EXISTS "Members can read household pantry" ON pantry_items;

CREATE POLICY "Household users can read pantry items"
    ON pantry_items FOR SELECT
    USING (
        household_id = get_my_household_id()
        AND (
            NOT EXISTS (
                SELECT 1 FROM users
                WHERE user_id = auth.uid() AND role = 'guest'
            )
            OR approval_status = 'approved'
        )
    );

DROP POLICY IF EXISTS "Members can read household shopping" ON shopping_items;

CREATE POLICY "Household users can read shopping items"
    ON shopping_items FOR SELECT
    USING (
        household_id = get_my_household_id()
        AND NOT EXISTS (
            SELECT 1 FROM users
            WHERE user_id = auth.uid() AND role = 'guest'
        )
    );

DROP POLICY IF EXISTS "Members can read household lists" ON shopping_lists;

CREATE POLICY "Household users can read shopping lists"
    ON shopping_lists FOR SELECT
    USING (
        household_id = get_my_household_id()
        AND NOT EXISTS (
            SELECT 1 FROM users
            WHERE user_id = auth.uid() AND role = 'guest'
        )
    );

-- Guests cannot insert/update/delete (existing write policies require admin or member paths)

COMMENT ON POLICY "Household users can read pantry items" ON pantry_items IS
'Members and admins see all items; guests see approved items only.';
