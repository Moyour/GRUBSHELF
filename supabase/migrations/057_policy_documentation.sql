-- GrubShelf Migration 057: Policy and function documentation comments

COMMENT ON POLICY "Owner can delete household" ON households IS
'Only the household owner (is_owner = TRUE) can delete the entire household.';

COMMENT ON POLICY "Admins can insert approved pantry items" ON pantry_items IS
'Admins insert pantry items directly as approved.';

COMMENT ON POLICY "Members can insert pending pantry items" ON pantry_items IS
'Non-admin members submit pantry items as pending for admin approval.';

COMMENT ON POLICY "Admins can update pantry items" ON pantry_items IS
'Admins may update any pantry item in their household.';

COMMENT ON POLICY "Members can update own pending pantry items" ON pantry_items IS
'Members may edit only their own pending pantry items.';

COMMENT ON POLICY "Admins can delete pantry items" ON pantry_items IS
'Only admins can delete pantry items.';

COMMENT ON POLICY "Admins can insert approved shopping items" ON shopping_items IS
'Admins insert shopping items directly as approved.';

COMMENT ON POLICY "Members can insert pending shopping items" ON shopping_items IS
'Non-admin members submit shopping items as pending for admin approval.';

COMMENT ON POLICY "Admins can update shopping items" ON shopping_items IS
'Admins may update any shopping item in their household.';

COMMENT ON POLICY "Members can update own pending shopping items" ON shopping_items IS
'Members may edit only their own pending shopping items.';

COMMENT ON POLICY "Admins can delete shopping items" ON shopping_items IS
'Only admins can delete shopping items (transfer flow uses admin or legacy member delete policy).';

COMMENT ON POLICY "Users with permission can update household" ON households IS
'Household settings updates require admin role or can_modify_budget permission.';

COMMENT ON FUNCTION is_household_owner IS
'Returns TRUE when the authenticated user is the primary household owner.';

COMMENT ON FUNCTION is_household_admin IS
'Returns TRUE when the authenticated user has role admin in their household.';

COMMENT ON FUNCTION get_pending_items_for_approval IS
'Returns pending pantry and shopping items for admin review, oldest first.';

COMMENT ON FUNCTION get_member_activity_stats IS
'Returns per-member contribution and approval statistics for the current household.';
