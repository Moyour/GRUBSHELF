-- GrubShelf Migration 038: Restrict household deletion to owner only

DROP POLICY IF EXISTS "Admins can delete household" ON households;

CREATE POLICY "Owner can delete household"
    ON households FOR DELETE
    USING (
        household_id = get_my_household_id()
        AND is_household_owner()
    );

COMMENT ON POLICY "Owner can delete household" ON households IS
'Only the household owner (is_owner = TRUE) can delete the entire household.';
