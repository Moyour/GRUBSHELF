-- GrubShelf Finance Feature Migration
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)

-- ============================================================
-- 1. Finance Settings (per-user budget configuration)
-- ============================================================
CREATE TABLE finance_settings (
    user_id UUID PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    budget_period TEXT NOT NULL CHECK (budget_period IN ('weekly', 'monthly')) DEFAULT 'monthly',
    budget_amount_minor INTEGER NOT NULL CHECK (budget_amount_minor >= 0),
    period_start_day INTEGER NOT NULL CHECK (period_start_day BETWEEN 1 AND 28) DEFAULT 1,
    currency TEXT NOT NULL DEFAULT 'GBP' CHECK (char_length(currency) BETWEEN 2 AND 5)
);

-- ============================================================
-- 2. Shopping Trips (logged when a shopping list is completed)
-- ============================================================
CREATE TABLE shopping_trips (
    trip_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    shopping_list_id UUID REFERENCES shopping_lists(list_id) ON DELETE SET NULL,
    date TIMESTAMPTZ NOT NULL DEFAULT now(),
    total_cost_minor INTEGER CHECK (total_cost_minor >= 0),
    item_count INTEGER NOT NULL DEFAULT 0,
    period TEXT NOT NULL,
    cost_logged BOOLEAN NOT NULL DEFAULT false
);

-- ============================================================
-- 3. Waste Events (logged when a pantry item is wasted/expired)
-- ============================================================
CREATE TABLE waste_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    pantry_item_id UUID REFERENCES pantry_items(item_id) ON DELETE SET NULL,
    item_name TEXT NOT NULL,
    date TIMESTAMPTZ NOT NULL DEFAULT now(),
    estimated_cost_minor INTEGER CHECK (estimated_cost_minor >= 0),
    period TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'manual_removal'
);

-- ============================================================
-- 4. Period Snapshots (historical summaries for trends chart)
-- ============================================================
CREATE TABLE period_snapshots (
    snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    period TEXT NOT NULL,
    budget_amount_minor INTEGER NOT NULL DEFAULT 0,
    total_spent_minor INTEGER NOT NULL DEFAULT 0,
    total_waste_minor INTEGER NOT NULL DEFAULT 0,
    waste_item_count INTEGER NOT NULL DEFAULT 0,
    trip_count INTEGER NOT NULL DEFAULT 0,
    effective_value_minor INTEGER NOT NULL DEFAULT 0,
    UNIQUE (household_id, period)
);

-- ============================================================
-- 5. Indexes for common queries
-- ============================================================
CREATE INDEX idx_shopping_trips_household_period ON shopping_trips (household_id, period);
CREATE INDEX idx_shopping_trips_household_cost_logged ON shopping_trips (household_id, cost_logged);
CREATE INDEX idx_waste_events_household_period ON waste_events (household_id, period);
CREATE INDEX idx_period_snapshots_household_period ON period_snapshots (household_id, period);

-- ============================================================
-- 6. Row Level Security
-- ============================================================
ALTER TABLE finance_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE shopping_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE waste_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE period_snapshots ENABLE ROW LEVEL SECURITY;

-- Finance Settings policies (user-scoped, not household-scoped)
CREATE POLICY "Users can read own finance settings"
    ON finance_settings FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert own finance settings"
    ON finance_settings FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own finance settings"
    ON finance_settings FOR UPDATE USING (user_id = auth.uid());

-- Shopping Trips policies (household-scoped)
CREATE POLICY "Members can read household trips"
    ON shopping_trips FOR SELECT USING (household_id = get_my_household_id());

CREATE POLICY "Members can insert trips"
    ON shopping_trips FOR INSERT WITH CHECK (household_id = get_my_household_id());

CREATE POLICY "Members can update trips"
    ON shopping_trips FOR UPDATE USING (household_id = get_my_household_id());

-- Waste Events policies (household-scoped)
CREATE POLICY "Members can read household waste events"
    ON waste_events FOR SELECT USING (household_id = get_my_household_id());

CREATE POLICY "Members can insert waste events"
    ON waste_events FOR INSERT WITH CHECK (household_id = get_my_household_id());

-- Period Snapshots policies (household-scoped)
CREATE POLICY "Members can read household snapshots"
    ON period_snapshots FOR SELECT USING (household_id = get_my_household_id());

CREATE POLICY "Members can insert snapshots"
    ON period_snapshots FOR INSERT WITH CHECK (household_id = get_my_household_id());

CREATE POLICY "Members can update snapshots"
    ON period_snapshots FOR UPDATE USING (household_id = get_my_household_id());

-- ============================================================
-- 7. Enable Realtime for shopping trips and waste events
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE shopping_trips;
ALTER PUBLICATION supabase_realtime ADD TABLE waste_events;

-- ============================================================
-- 8. Add transferred flag to shopping_lists
-- ============================================================
ALTER TABLE shopping_lists ADD COLUMN transferred BOOLEAN NOT NULL DEFAULT false;
