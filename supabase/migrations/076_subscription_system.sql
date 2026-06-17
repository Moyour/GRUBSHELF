-- 076_subscription_system.sql
-- Subscription system: plans, user subscriptions, feature usage, events

-- Plan catalog
CREATE TABLE IF NOT EXISTS subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    features JSONB NOT NULL DEFAULT '{}'::jsonb,
    price_monthly_cents INT NOT NULL DEFAULT 0,
    price_yearly_cents INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Active subscription per household
CREATE TABLE IF NOT EXISTS user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'trialing', 'cancelled', 'expired')),
    current_period_start TIMESTAMPTZ NOT NULL DEFAULT now(),
    current_period_end TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '100 years',
    payment_provider TEXT CHECK (payment_provider IN ('apple_iap', 'free')),
    external_subscription_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_subscriptions_household
    ON user_subscriptions(household_id) WHERE status IN ('active', 'trialing');

-- Monthly feature usage counters
CREATE TABLE IF NOT EXISTS feature_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    feature_key TEXT NOT NULL,
    usage_count INT NOT NULL DEFAULT 0,
    period_start DATE NOT NULL DEFAULT date_trunc('month', now())::date,
    period_end DATE NOT NULL DEFAULT (date_trunc('month', now()) + INTERVAL '1 month' - INTERVAL '1 day')::date,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (household_id, feature_key, period_start)
);

-- Audit log for subscription events
CREATE TABLE IF NOT EXISTS subscription_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    user_id UUID,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'created', 'renewed', 'cancelled', 'expired',
        'upgraded', 'downgraded', 'trial_started', 'payment_failed',
        'restored'
    )),
    old_plan_id UUID REFERENCES subscription_plans(id),
    new_plan_id UUID REFERENCES subscription_plans(id),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add current_plan_id to households
ALTER TABLE households
    ADD COLUMN IF NOT EXISTS current_plan_id UUID REFERENCES subscription_plans(id),
    ADD COLUMN IF NOT EXISTS subscription_updated_at TIMESTAMPTZ;

-- Seed free and premium plans
INSERT INTO subscription_plans (name, display_name, features, price_monthly_cents, price_yearly_cents)
VALUES
    ('free', 'Free', '{
        "household_members": 2,
        "pantry_items": 75,
        "shopping_lists": 2,
        "barcode_scans_per_month": 20,
        "analytics_days": 7,
        "export_reports": false,
        "photo_uploads": false,
        "bulk_operations": false
    }'::jsonb, 0, 0),
    ('premium', 'Premium', '{
        "household_members": -1,
        "pantry_items": -1,
        "shopping_lists": -1,
        "barcode_scans_per_month": -1,
        "analytics_days": -1,
        "export_reports": true,
        "photo_uploads": true,
        "bulk_operations": true
    }'::jsonb, 499, 4999)
ON CONFLICT (name) DO NOTHING;

-- Migrate all existing households to free plan
UPDATE households
SET current_plan_id = (SELECT id FROM subscription_plans WHERE name = 'free'),
    subscription_updated_at = now()
WHERE current_plan_id IS NULL;

-- Create a free subscription row for every household owner
INSERT INTO user_subscriptions (household_id, plan_id, status, payment_provider, current_period_end)
SELECT
    h.household_id,
    (SELECT id FROM subscription_plans WHERE name = 'free'),
    'active',
    'free',
    now() + INTERVAL '100 years'
FROM households h
WHERE NOT EXISTS (
    SELECT 1 FROM user_subscriptions us
    WHERE us.household_id = h.household_id
      AND us.status IN ('active', 'trialing')
);

-- RLS policies
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_events ENABLE ROW LEVEL SECURITY;

-- Plans are public-readable
CREATE POLICY "Plans are readable by everyone"
    ON subscription_plans FOR SELECT
    USING (true);

-- Members can read their own household's subscription
CREATE POLICY "Members can read own household subscription"
    ON user_subscriptions FOR SELECT
    USING (
        household_id IN (
            SELECT household_id FROM users WHERE user_id = auth.uid()
        )
    );

-- Members can read their own household's usage
CREATE POLICY "Members can read own household usage"
    ON feature_usage FOR SELECT
    USING (
        household_id IN (
            SELECT household_id FROM users WHERE user_id = auth.uid()
        )
    );

-- Members can read their own household's events
CREATE POLICY "Members can read own household events"
    ON subscription_events FOR SELECT
    USING (
        household_id IN (
            SELECT household_id FROM users WHERE user_id = auth.uid()
        )
    );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_feature_usage_household_period
    ON feature_usage(household_id, feature_key, period_start);

CREATE INDEX IF NOT EXISTS idx_subscription_events_household
    ON subscription_events(household_id, created_at DESC);
