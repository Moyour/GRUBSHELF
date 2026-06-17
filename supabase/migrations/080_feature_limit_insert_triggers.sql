-- 080_feature_limit_insert_triggers.sql
-- Server-side enforcement of feature limits via BEFORE INSERT triggers.
-- Prevents bypassing client-side gates through offline mode or direct API calls.

-- Shared helper: returns TRUE when the household is under its plan limit.
CREATE OR REPLACE FUNCTION _check_entity_limit(
    p_household_id UUID,
    p_feature_key TEXT,
    p_current_count INT
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER STABLE
AS $$
DECLARE
    v_limit INT;
    v_features JSONB;
BEGIN
    SELECT sp.features INTO v_features
    FROM households h
    JOIN subscription_plans sp ON sp.id = h.current_plan_id
    WHERE h.household_id = p_household_id;

    IF v_features IS NULL THEN
        -- No plan found; default permissive
        RETURN TRUE;
    END IF;

    -- Boolean features are not count-based; skip
    IF jsonb_typeof(v_features -> p_feature_key) = 'boolean' THEN
        RETURN (v_features ->> p_feature_key)::boolean;
    END IF;

    v_limit := (v_features ->> p_feature_key)::int;

    -- -1 = unlimited
    IF v_limit = -1 THEN
        RETURN TRUE;
    END IF;

    RETURN p_current_count < v_limit;
END;
$$;

-- ──────────────────────────────────────────────
-- Pantry items limit
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION enforce_pantry_items_limit()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*)::int INTO v_count
    FROM pantry_items
    WHERE household_id = NEW.household_id
      AND NOT archived;

    IF NOT _check_entity_limit(NEW.household_id, 'pantry_items', v_count) THEN
        RAISE EXCEPTION 'Pantry item limit reached for your plan. Upgrade to Premium for unlimited items.'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_pantry_items_limit ON pantry_items;
CREATE TRIGGER trg_enforce_pantry_items_limit
    BEFORE INSERT ON pantry_items
    FOR EACH ROW
    EXECUTE FUNCTION enforce_pantry_items_limit();

-- ──────────────────────────────────────────────
-- Shopping lists limit
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION enforce_shopping_lists_limit()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT count(*)::int INTO v_count
    FROM shopping_lists
    WHERE household_id = NEW.household_id
      AND NOT transferred;

    IF NOT _check_entity_limit(NEW.household_id, 'shopping_lists', v_count) THEN
        RAISE EXCEPTION 'Shopping list limit reached for your plan. Upgrade to Premium for unlimited lists.'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_shopping_lists_limit ON shopping_lists;
CREATE TRIGGER trg_enforce_shopping_lists_limit
    BEFORE INSERT ON shopping_lists
    FOR EACH ROW
    EXECUTE FUNCTION enforce_shopping_lists_limit();

-- ──────────────────────────────────────────────
-- Household members limit
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION enforce_household_members_limit()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_count INT;
BEGIN
    -- Skip if household_id is NULL (user not in a household)
    IF NEW.household_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- On UPDATE, skip if household_id hasn't changed
    IF TG_OP = 'UPDATE' AND OLD.household_id IS NOT DISTINCT FROM NEW.household_id THEN
        RETURN NEW;
    END IF;

    SELECT count(*)::int INTO v_count
    FROM users
    WHERE household_id = NEW.household_id;

    IF NOT _check_entity_limit(NEW.household_id, 'household_members', v_count) THEN
        RAISE EXCEPTION 'Household member limit reached for your plan. Upgrade to Premium for unlimited members.'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_household_members_limit ON users;
CREATE TRIGGER trg_enforce_household_members_limit
    BEFORE INSERT OR UPDATE OF household_id ON users
    FOR EACH ROW
    EXECUTE FUNCTION enforce_household_members_limit();
