-- GrubShelf Migration 058: Performance indexes for permissions and notifications

CREATE INDEX IF NOT EXISTS idx_pantry_household_approval
    ON pantry_items (household_id, approval_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_shopping_household_approval
    ON shopping_items (household_id, approval_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_pantry_creator_pending
    ON pantry_items (created_by)
    WHERE approval_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_shopping_creator_pending
    ON shopping_items (created_by)
    WHERE approval_status = 'pending';

CREATE INDEX IF NOT EXISTS idx_notifications_type_unread
    ON notifications (user_id, type, read)
    WHERE read = FALSE;

CREATE INDEX IF NOT EXISTS idx_users_role_household
    ON users (household_id, role);
