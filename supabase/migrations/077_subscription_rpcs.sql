-- 077_subscription_rpcs.sql
-- RPCs for subscription management and limit checking

-- Get the current subscription for a household
CREATE OR REPLACE FUNCTION get_household_subscription(p_household_id UUID)
RETURNS TABLE (
    plan_name TEXT,
    display_name TEXT,
    features JSONB,
    is_premium BOOLEAN,
    subscription_status TEXT,
    current_period_end TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        sp.name,
        sp.display_name,
        sp.features,
        sp.name = 'premium',
        COALESCE(us.status, 'active'),
        us.current_period_end
    FROM households h
    JOIN subscription_plans sp ON sp.id = h.current_plan_id
    LEFT JOIN user_subscriptions us ON us.household_id = h.household_id
        AND us.status IN ('active', 'trialing')
    WHERE h.household_id = p_household_id;
END;
$$;

-- Check whether a feature action is allowed
CREATE OR REPLACE FUNCTION check_feature_limit(
    p_household_id UUID,
    p_feature_key TEXT
)
RETURNS TABLE (
    can_perform BOOLEAN,
    current_usage INT,
    limit_value INT,
    is_unlimited BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_features JSONB;
    v_limit INT;
    v_current INT;
    v_is_boolean BOOLEAN;
BEGIN
    -- Get the plan features
    SELECT sp.features INTO v_features
    FROM households h
    JOIN subscription_plans sp ON sp.id = h.current_plan_id
    WHERE h.household_id = p_household_id;

    IF v_features IS NULL THEN
        -- No plan found, default permissive
        RETURN QUERY SELECT true, 0, -1, true;
        RETURN;
    END IF;

    -- Check if this is a boolean feature
    v_is_boolean := jsonb_typeof(v_features -> p_feature_key) = 'boolean';

    IF v_is_boolean THEN
        RETURN QUERY SELECT
            (v_features ->> p_feature_key)::boolean,
            0,
            CASE WHEN (v_features ->> p_feature_key)::boolean THEN -1 ELSE 0 END,
            (v_features ->> p_feature_key)::boolean;
        RETURN;
    END IF;

    -- Numeric limit
    v_limit := (v_features ->> p_feature_key)::int;

    -- -1 means unlimited
    IF v_limit = -1 THEN
        RETURN QUERY SELECT true, 0, -1, true;
        RETURN;
    END IF;

    -- Count current usage based on feature type
    CASE p_feature_key
        WHEN 'pantry_items' THEN
            SELECT count(*)::int INTO v_current
            FROM pantry_items
            WHERE household_id = p_household_id AND NOT archived;
        WHEN 'shopping_lists' THEN
            SELECT count(*)::int INTO v_current
            FROM shopping_lists
            WHERE household_id = p_household_id AND NOT transferred;
        WHEN 'household_members' THEN
            SELECT count(*)::int INTO v_current
            FROM users
            WHERE household_id = p_household_id;
        WHEN 'barcode_scans_per_month' THEN
            SELECT COALESCE(fu.usage_count, 0) INTO v_current
            FROM feature_usage fu
            WHERE fu.household_id = p_household_id
              AND fu.feature_key = 'barcode_scans_per_month'
              AND fu.period_start = date_trunc('month', now())::date;

            IF NOT FOUND THEN v_current := 0; END IF;
        ELSE
            v_current := 0;
    END CASE;

    RETURN QUERY SELECT
        v_current < v_limit,
        v_current,
        v_limit,
        false;
END;
$$;

-- Increment a monthly usage counter
CREATE OR REPLACE FUNCTION increment_feature_usage(
    p_household_id UUID,
    p_feature_key TEXT,
    p_user_id UUID DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_period_start DATE := date_trunc('month', now())::date;
    v_period_end DATE := (date_trunc('month', now()) + INTERVAL '1 month' - INTERVAL '1 day')::date;
BEGIN
    INSERT INTO feature_usage (household_id, feature_key, usage_count, period_start, period_end)
    VALUES (p_household_id, p_feature_key, 1, v_period_start, v_period_end)
    ON CONFLICT (household_id, feature_key, period_start)
    DO UPDATE SET
        usage_count = feature_usage.usage_count + 1,
        updated_at = now();
END;
$$;

-- Activate a premium subscription after StoreKit purchase
CREATE OR REPLACE FUNCTION create_subscription(
    p_user_id UUID,
    p_household_id UUID,
    p_plan_name TEXT DEFAULT 'premium',
    p_payment_provider TEXT DEFAULT 'apple_iap',
    p_external_subscription_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_plan_id UUID;
    v_old_plan_id UUID;
    v_subscription_id UUID;
BEGIN
    -- Get plan ID
    SELECT id INTO v_plan_id FROM subscription_plans WHERE name = p_plan_name;
    IF v_plan_id IS NULL THEN
        RAISE EXCEPTION 'Plan not found: %', p_plan_name;
    END IF;

    -- Get old plan for event log
    SELECT current_plan_id INTO v_old_plan_id FROM households WHERE household_id = p_household_id;

    -- Expire any existing active subscriptions
    UPDATE user_subscriptions
    SET status = 'expired', updated_at = now()
    WHERE household_id = p_household_id AND status IN ('active', 'trialing');

    -- Create new subscription
    INSERT INTO user_subscriptions (
        household_id, plan_id, status, payment_provider,
        external_subscription_id, current_period_start, current_period_end
    )
    VALUES (
        p_household_id, v_plan_id, 'active', p_payment_provider,
        p_external_subscription_id, now(),
        CASE
            WHEN p_plan_name = 'free' THEN now() + INTERVAL '100 years'
            ELSE now() + INTERVAL '1 month'
        END
    )
    RETURNING id INTO v_subscription_id;

    -- Update household
    UPDATE households
    SET current_plan_id = v_plan_id, subscription_updated_at = now()
    WHERE household_id = p_household_id;

    -- Log event
    INSERT INTO subscription_events (household_id, user_id, event_type, old_plan_id, new_plan_id, metadata)
    VALUES (
        p_household_id, p_user_id,
        CASE WHEN p_plan_name = 'premium' THEN 'upgraded' ELSE 'downgraded' END,
        v_old_plan_id, v_plan_id,
        jsonb_build_object('provider', p_payment_provider, 'external_id', p_external_subscription_id)
    );

    RETURN v_subscription_id;
END;
$$;

-- Cancel a subscription
CREATE OR REPLACE FUNCTION cancel_subscription(
    p_subscription_id UUID,
    p_cancel_immediately BOOLEAN DEFAULT false
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_household_id UUID;
    v_plan_id UUID;
    v_free_plan_id UUID;
BEGIN
    SELECT household_id, plan_id INTO v_household_id, v_plan_id
    FROM user_subscriptions WHERE id = p_subscription_id;

    SELECT id INTO v_free_plan_id FROM subscription_plans WHERE name = 'free';

    IF p_cancel_immediately THEN
        -- Immediate: expire and downgrade
        UPDATE user_subscriptions
        SET status = 'expired', updated_at = now()
        WHERE id = p_subscription_id;

        UPDATE households
        SET current_plan_id = v_free_plan_id, subscription_updated_at = now()
        WHERE household_id = v_household_id;

        -- Create free subscription
        INSERT INTO user_subscriptions (household_id, plan_id, status, payment_provider, current_period_end)
        VALUES (v_household_id, v_free_plan_id, 'active', 'free', now() + INTERVAL '100 years');
    ELSE
        -- Cancel at period end
        UPDATE user_subscriptions
        SET status = 'cancelled', updated_at = now()
        WHERE id = p_subscription_id;
    END IF;

    -- Log event
    INSERT INTO subscription_events (household_id, event_type, old_plan_id, new_plan_id)
    VALUES (v_household_id, 'cancelled', v_plan_id, v_free_plan_id);
END;
$$;

-- Cron: expire subscriptions past their period end
CREATE OR REPLACE FUNCTION expire_subscriptions()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_free_plan_id UUID;
    r RECORD;
BEGIN
    SELECT id INTO v_free_plan_id FROM subscription_plans WHERE name = 'free';

    FOR r IN
        SELECT id, household_id, plan_id
        FROM user_subscriptions
        WHERE status IN ('cancelled', 'active')
          AND current_period_end < now()
          AND plan_id != v_free_plan_id
    LOOP
        UPDATE user_subscriptions
        SET status = 'expired', updated_at = now()
        WHERE id = r.id;

        UPDATE households
        SET current_plan_id = v_free_plan_id, subscription_updated_at = now()
        WHERE household_id = r.household_id;

        -- Create free subscription
        INSERT INTO user_subscriptions (household_id, plan_id, status, payment_provider, current_period_end)
        VALUES (r.household_id, v_free_plan_id, 'active', 'free', now() + INTERVAL '100 years')
        ON CONFLICT DO NOTHING;

        INSERT INTO subscription_events (household_id, event_type, old_plan_id, new_plan_id)
        VALUES (r.household_id, 'expired', r.plan_id, v_free_plan_id);
    END LOOP;
END;
$$;
