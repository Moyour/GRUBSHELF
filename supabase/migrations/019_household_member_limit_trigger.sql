-- Migration 019: Enforce household member limit at DB level
-- Prevents any household from exceeding 20 members via trigger

CREATE OR REPLACE FUNCTION public.check_household_member_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_member_count INT;
BEGIN
    IF NEW.household_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_member_count
        FROM public.users
        WHERE household_id = NEW.household_id;

        IF v_member_count >= 20 THEN
            RAISE EXCEPTION 'Household has reached the maximum of 20 members';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_household_member_limit
    BEFORE INSERT OR UPDATE OF household_id ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.check_household_member_limit();
