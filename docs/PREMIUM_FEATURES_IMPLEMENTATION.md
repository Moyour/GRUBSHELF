# Premium Features Implementation Guide

**Version:** 1.0  
**Last Updated:** May 15, 2026  
**Status:** Planning & Design Phase

---

## Table of Contents

1. [Overview](#overview)
2. [Business Model & Strategy](#business-model--strategy)
3. [Feature Comparison](#feature-comparison)
4. [Database Architecture](#database-architecture)
5. [Backend Implementation](#backend-implementation)
6. [iOS App Integration](#ios-app-integration)
7. [Payment Integration](#payment-integration)
8. [UI/UX Implementation](#uiux-implementation)
9. [Testing Strategy](#testing-strategy)
10. [Migration & Rollout Plan](#migration--rollout-plan)
11. [Code Examples](#code-examples)
12. [Troubleshooting](#troubleshooting)

---

## Overview

### Purpose

This document outlines the complete implementation strategy for adding a **two-tier subscription model** (Free and Premium) to GrubShelf. The goal is to monetize the app while maintaining a generous free tier for casual users and providing substantial value for premium subscribers.

### Goals

- Create sustainable revenue stream
- Provide clear value differentiation between tiers
- Maintain excellent UX for both free and premium users
- Implement scalable, maintainable subscription infrastructure
- Support Apple In-App Purchases (IAP)

### Key Principles

1. **Free tier should be genuinely useful** - not a demo
2. **Premium features should be valuable** - worth the investment
3. **Limits should be clear and predictable** - no surprise paywalls
4. **Upgrade prompts should be helpful** - not annoying
5. **Grandfathering existing users** - reward early adopters

---

## Business Model & Strategy

### Pricing Strategy

#### Recommended Pricing (Phase 1)

| Tier | Monthly | Yearly | Savings |
|------|---------|--------|---------|
| Free | $0 | $0 | - |
| Premium | $4.99 | $49.99 | 17% (~2 months free) |

#### Alternative Pricing (Phase 2 - Optional)

Consider a three-tier model after gathering user data:

| Tier | Monthly | Yearly | Target User |
|------|---------|--------|-------------|
| Free | $0 | $0 | Individuals, light users |
| Plus | $2.99 | $29.99 | Small families (2-4 people) |
| Pro | $6.99 | $69.99 | Large households, power users |

### Market Research

**Competitor Pricing Analysis:**
- AnyList Premium: $11.99/year
- Out of Milk Premium: $2.99/month
- Mealime Pro: $5.99/month or $49.99/year
- Paprika: One-time $4.99

**GrubShelf Positioning:** Mid-range pricing with better feature set than competitors.

### Revenue Projections

**Conservative Estimates (Year 1):**
- 10,000 active users
- 5% conversion to premium (500 subscribers)
- 60% choose annual plan
- **Projected Annual Revenue:** ~$22,500

**Growth Scenario (Year 3):**
- 50,000 active users
- 8% conversion rate (4,000 subscribers)
- 70% choose annual plan
- **Projected Annual Revenue:** ~$180,000

---

## Feature Comparison

### Free vs. Premium Features

| Feature | Free Tier | Premium Tier |
|---------|-----------|--------------|
| **Household Members** | 2 total (1 owner/admin + 1 member) | Unlimited members |
| **Pantry Items** | 75 items | Unlimited items |
| **Shopping Lists** | 2 active lists | Unlimited lists |
| **Barcode Scans** | 20 per month | Unlimited scans |
| **Analytics History** | 7 days | Unlimited history |
| **Custom Categories** | ❌ No | ✅ Yes |
| **Storage Locations** | ❌ No | ✅ Yes (freezer, fridge, pantry) |
| **Bulk Operations** | ❌ No | ✅ Yes (multi-select edit/delete) |
| **Recipe Integration** | ❌ No | ✅ Yes |
| **Advanced Analytics** | ❌ No | ✅ Yes (waste reports, forecasts) |
| **Photo Uploads** | ❌ No | ✅ Yes (per item) |
| **List Templates** | ❌ No | ✅ Yes |
| **Price Tracking** | ❌ No | ✅ Yes |
| **Smart Suggestions** | ❌ No | ✅ Yes (AI-powered) |
| **Custom Budgets** | 1 overall budget | Per-category budgets |
| **Export Reports** | ❌ No | ✅ Yes (PDF, Excel) |
| **Priority Support** | Email (48hr response) | Email (12hr response) |
| **Early Access** | ❌ No | ✅ Beta features |

### Household model (product rule, not a premium gate)

- **One household per user** — no multi-household membership. Switching households is out of scope; this keeps permissions, billing, and invites simple.
- **Free member cap** — exactly **2 people**: the household **owner/admin** plus **one other member**. A third invite or join attempt hits the paywall.
- **Premium** — unlimited members in that single household.

### Feature Categories

#### 🔒 Hard Limits (Enforced, Show Paywall)
- Household members > 2 (owner/admin + 1 member on free)
- Pantry items > 75
- Shopping lists > 2
- Barcode scans > 20/month

#### 🚀 Premium-Only Features (Completely Blocked)
- Custom categories
- Storage locations
- Bulk operations
- Recipe integration
- Advanced analytics
- Photo uploads
- List templates
- Price tracking
- AI suggestions
- Export to PDF/Excel

#### 💡 Soft Limits (Show Upgrade Prompts)
- Analytics beyond 7 days (blur or show preview)
- Category budgets (show "Unlock" CTA)

---

## Database Architecture

### New Tables

#### 1. `subscription_plans`

Stores available subscription tiers and their feature limits.

```sql
CREATE TABLE subscription_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE, -- 'free', 'premium'
  display_name TEXT NOT NULL, -- 'Free', 'Premium'
  description TEXT,
  price_monthly_cents INTEGER, -- Store in cents to avoid decimal issues
  price_yearly_cents INTEGER,
  currency TEXT DEFAULT 'USD',
  features JSONB NOT NULL, -- Feature limits configuration
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_subscription_plans_name ON subscription_plans(name);
CREATE INDEX idx_subscription_plans_active ON subscription_plans(is_active);
```

**Example Data:**

```json
{
  "name": "free",
  "display_name": "Free",
  "features": {
    "household_members": 2,
    "pantry_items": 75,
    "shopping_lists": 2,
    "barcode_scans_per_month": 20,
    "analytics_history_days": 7,
    "custom_categories": false,
    "storage_locations": false,
    "bulk_operations": false,
    "recipe_integration": false,
    "advanced_analytics": false,
    "photo_uploads": false,
    "list_templates": false,
    "price_tracking": false,
    "ai_suggestions": false,
    "category_budgets": false,
    "export_reports": false,
    "priority_support": false
  }
}
```

#### 2. `user_subscriptions`

Tracks each user/household's subscription status.

```sql
CREATE TABLE user_subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES subscription_plans(id),
  
  -- Subscription status
  status TEXT NOT NULL CHECK (status IN (
    'active',      -- Currently active
    'trialing',    -- In trial period
    'cancelled',   -- Cancelled but still active until period end
    'expired',     -- Subscription ended
    'paused'       -- Temporarily paused
  )),
  
  -- Trial information
  trial_starts_at TIMESTAMPTZ,
  trial_ends_at TIMESTAMPTZ,
  
  -- Billing period
  current_period_start TIMESTAMPTZ NOT NULL,
  current_period_end TIMESTAMPTZ NOT NULL,
  
  -- Cancellation
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  cancelled_at TIMESTAMPTZ,
  
  -- Payment provider integration
  payment_provider TEXT CHECK (payment_provider IN (
    'apple_iap',   -- Apple In-App Purchase
    'stripe',      -- Future: Stripe for web
    'manual'       -- Manual/admin grants
  )),
  external_subscription_id TEXT, -- Provider's subscription ID
  external_customer_id TEXT,     -- Provider's customer ID
  
  -- Receipt validation (for Apple IAP)
  last_receipt_data TEXT,
  last_validation_at TIMESTAMPTZ,
  
  -- Metadata
  granted_by UUID REFERENCES auth.users(id), -- If manually granted by admin
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  UNIQUE(household_id, plan_id, current_period_start)
);

-- Indexes
CREATE INDEX idx_user_subscriptions_user ON user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_household ON user_subscriptions(household_id);
CREATE INDEX idx_user_subscriptions_status ON user_subscriptions(status);
CREATE INDEX idx_user_subscriptions_period_end ON user_subscriptions(current_period_end);
CREATE INDEX idx_user_subscriptions_external ON user_subscriptions(external_subscription_id);

-- RLS Policies
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their household subscriptions"
  ON user_subscriptions FOR SELECT
  USING (
    household_id IN (
      SELECT household_id FROM household_members
      WHERE user_id = auth.uid()
    )
  );
```

#### 3. `feature_usage`

Tracks usage against monthly limits (barcode scans, etc.).

```sql
CREATE TABLE feature_usage (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Track who used it
  
  feature_key TEXT NOT NULL, -- 'barcode_scans', 'pantry_items', etc.
  usage_count INTEGER DEFAULT 0,
  
  -- Time period for this usage record
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ NOT NULL,
  
  -- Metadata
  last_used_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Unique per household, feature, and period
  UNIQUE(household_id, feature_key, period_start)
);

-- Indexes
CREATE INDEX idx_feature_usage_household ON feature_usage(household_id);
CREATE INDEX idx_feature_usage_feature ON feature_usage(feature_key);
CREATE INDEX idx_feature_usage_period ON feature_usage(period_start, period_end);
CREATE INDEX idx_feature_usage_active ON feature_usage(period_end) WHERE period_end > NOW();

-- RLS Policies
ALTER TABLE feature_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their household usage"
  ON feature_usage FOR SELECT
  USING (
    household_id IN (
      SELECT household_id FROM household_members
      WHERE user_id = auth.uid()
    )
  );
```

#### 4. `subscription_events`

Audit log for all subscription changes.

```sql
CREATE TABLE subscription_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subscription_id UUID REFERENCES user_subscriptions(id) ON DELETE CASCADE,
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  event_type TEXT NOT NULL CHECK (event_type IN (
    'created',
    'activated',
    'renewed',
    'cancelled',
    'expired',
    'upgraded',
    'downgraded',
    'trial_started',
    'trial_ended',
    'payment_failed',
    'refunded'
  )),
  
  old_plan_id UUID REFERENCES subscription_plans(id),
  new_plan_id UUID REFERENCES subscription_plans(id),
  
  metadata JSONB, -- Store additional event data
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_subscription_events_subscription ON subscription_events(subscription_id);
CREATE INDEX idx_subscription_events_household ON subscription_events(household_id);
CREATE INDEX idx_subscription_events_type ON subscription_events(event_type);
CREATE INDEX idx_subscription_events_created ON subscription_events(created_at DESC);

-- RLS Policies
ALTER TABLE subscription_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their household subscription events"
  ON subscription_events FOR SELECT
  USING (
    household_id IN (
      SELECT household_id FROM household_members
      WHERE user_id = auth.uid()
    )
  );
```

### Schema Modifications

#### Update `households` Table

```sql
-- Add subscription reference to households
ALTER TABLE households 
ADD COLUMN current_plan_id UUID REFERENCES subscription_plans(id),
ADD COLUMN subscription_updated_at TIMESTAMPTZ;

-- Set default plan for existing households
UPDATE households 
SET current_plan_id = (SELECT id FROM subscription_plans WHERE name = 'free' LIMIT 1)
WHERE current_plan_id IS NULL;

-- Make it NOT NULL after setting defaults
ALTER TABLE households 
ALTER COLUMN current_plan_id SET NOT NULL;

-- Add index
CREATE INDEX idx_households_plan ON households(current_plan_id);
```

### Seed Data

```sql
-- Insert default plans
INSERT INTO subscription_plans (name, display_name, description, price_monthly_cents, price_yearly_cents, features, sort_order)
VALUES
  (
    'free',
    'Free',
    'Perfect for individuals and light users',
    0,
    0,
    '{
      "household_members": 2,
      "pantry_items": 75,
      "shopping_lists": 2,
      "barcode_scans_per_month": 20,
      "analytics_history_days": 7,
      "custom_categories": false,
      "storage_locations": false,
      "bulk_operations": false,
      "recipe_integration": false,
      "advanced_analytics": false,
      "photo_uploads": false,
      "list_templates": false,
      "price_tracking": false,
      "ai_suggestions": false,
      "category_budgets": false,
      "export_reports": false,
      "priority_support": false
    }'::jsonb,
    1
  ),
  (
    'premium',
    'Premium',
    'Unlimited features for families and power users',
    499,
    4999,
    '{
      "household_members": -1,
      "pantry_items": -1,
      "shopping_lists": -1,
      "barcode_scans_per_month": -1,
      "analytics_history_days": -1,
      "custom_categories": true,
      "storage_locations": true,
      "bulk_operations": true,
      "recipe_integration": true,
      "advanced_analytics": true,
      "photo_uploads": true,
      "list_templates": true,
      "price_tracking": true,
      "ai_suggestions": true,
      "category_budgets": true,
      "export_reports": true,
      "priority_support": true
    }'::jsonb,
    2
  );

-- Note: -1 in features means "unlimited"
```

---

## Backend Implementation

### RPC Functions

#### 1. Get Current Subscription

```sql
CREATE OR REPLACE FUNCTION get_household_subscription(p_household_id UUID)
RETURNS TABLE (
  subscription_id UUID,
  plan_name TEXT,
  plan_display_name TEXT,
  status TEXT,
  features JSONB,
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN,
  is_premium BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    us.id,
    sp.name,
    sp.display_name,
    us.status,
    sp.features,
    us.current_period_end,
    us.cancel_at_period_end,
    sp.name != 'free' AS is_premium
  FROM user_subscriptions us
  JOIN subscription_plans sp ON us.plan_id = sp.id
  WHERE us.household_id = p_household_id
    AND us.status IN ('active', 'trialing')
    AND us.current_period_end > NOW()
  ORDER BY us.created_at DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### 2. Check Feature Access

```sql
CREATE OR REPLACE FUNCTION can_use_feature(
  p_household_id UUID,
  p_feature_key TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_feature_value JSONB;
  v_is_boolean BOOLEAN;
  v_limit INTEGER;
BEGIN
  -- Get the feature value from the household's current plan
  SELECT sp.features->p_feature_key INTO v_feature_value
  FROM households h
  JOIN subscription_plans sp ON h.current_plan_id = sp.id
  WHERE h.id = p_household_id;
  
  -- If feature doesn't exist in plan, default to false
  IF v_feature_value IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Check if it's a boolean feature
  IF jsonb_typeof(v_feature_value) = 'boolean' THEN
    RETURN (v_feature_value)::TEXT::BOOLEAN;
  END IF;
  
  -- If it's a number, -1 means unlimited
  v_limit := (v_feature_value)::TEXT::INTEGER;
  
  IF v_limit = -1 THEN
    RETURN TRUE;
  END IF;
  
  -- For countable features, we just return true if limit > 0
  -- Actual count checking happens in check_feature_limit
  RETURN v_limit > 0;
  
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### 3. Check Feature Limit

```sql
CREATE OR REPLACE FUNCTION check_feature_limit(
  p_household_id UUID,
  p_feature_key TEXT
)
RETURNS TABLE (
  can_perform BOOLEAN,
  current_usage INTEGER,
  limit_value INTEGER,
  is_unlimited BOOLEAN
) AS $$
DECLARE
  v_limit INTEGER;
  v_current_usage INTEGER := 0;
BEGIN
  -- Get limit from plan
  SELECT (sp.features->p_feature_key)::TEXT::INTEGER INTO v_limit
  FROM households h
  JOIN subscription_plans sp ON h.current_plan_id = sp.id
  WHERE h.id = p_household_id;
  
  -- If no limit defined, deny access
  IF v_limit IS NULL THEN
    RETURN QUERY SELECT FALSE, 0, 0, FALSE;
    RETURN;
  END IF;
  
  -- If unlimited (-1), allow
  IF v_limit = -1 THEN
    RETURN QUERY SELECT TRUE, 0, -1, TRUE;
    RETURN;
  END IF;
  
  -- Get current usage for time-based limits (monthly)
  IF p_feature_key IN ('barcode_scans_per_month') THEN
    SELECT COALESCE(usage_count, 0) INTO v_current_usage
    FROM feature_usage
    WHERE household_id = p_household_id
      AND feature_key = p_feature_key
      AND period_end > NOW();
  
  -- Get current count for static limits
  ELSIF p_feature_key = 'pantry_items' THEN
    SELECT COUNT(*) INTO v_current_usage
    FROM pantry_items
    WHERE household_id = p_household_id
      AND status != 'archived';
  
  ELSIF p_feature_key = 'shopping_lists' THEN
    SELECT COUNT(*) INTO v_current_usage
    FROM shopping_lists
    WHERE household_id = p_household_id
      AND archived = FALSE;
  
  ELSIF p_feature_key = 'household_members' THEN
    SELECT COUNT(*) INTO v_current_usage
    FROM household_members
    WHERE household_id = p_household_id;
  
  END IF;
  
  -- Return result
  RETURN QUERY SELECT 
    v_current_usage < v_limit,
    v_current_usage,
    v_limit,
    FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### 4. Increment Feature Usage

```sql
CREATE OR REPLACE FUNCTION increment_feature_usage(
  p_household_id UUID,
  p_feature_key TEXT,
  p_user_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_period_start TIMESTAMPTZ;
  v_period_end TIMESTAMPTZ;
BEGIN
  -- Calculate current month boundaries
  v_period_start := DATE_TRUNC('month', NOW());
  v_period_end := v_period_start + INTERVAL '1 month';
  
  -- Insert or update usage
  INSERT INTO feature_usage (
    household_id,
    user_id,
    feature_key,
    usage_count,
    period_start,
    period_end,
    last_used_at
  )
  VALUES (
    p_household_id,
    p_user_id,
    p_feature_key,
    1,
    v_period_start,
    v_period_end,
    NOW()
  )
  ON CONFLICT (household_id, feature_key, period_start)
  DO UPDATE SET
    usage_count = feature_usage.usage_count + 1,
    last_used_at = NOW(),
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### 5. Create Subscription

```sql
CREATE OR REPLACE FUNCTION create_subscription(
  p_user_id UUID,
  p_household_id UUID,
  p_plan_name TEXT,
  p_payment_provider TEXT DEFAULT 'apple_iap',
  p_external_subscription_id TEXT DEFAULT NULL,
  p_trial_days INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_plan_id UUID;
  v_subscription_id UUID;
  v_period_start TIMESTAMPTZ := NOW();
  v_period_end TIMESTAMPTZ;
  v_trial_end TIMESTAMPTZ := NULL;
  v_status TEXT := 'active';
BEGIN
  -- Get plan ID
  SELECT id INTO v_plan_id
  FROM subscription_plans
  WHERE name = p_plan_name AND is_active = TRUE;
  
  IF v_plan_id IS NULL THEN
    RAISE EXCEPTION 'Plan % not found', p_plan_name;
  END IF;
  
  -- Set up trial if provided
  IF p_trial_days IS NOT NULL AND p_trial_days > 0 THEN
    v_trial_end := NOW() + (p_trial_days || ' days')::INTERVAL;
    v_status := 'trialing';
    v_period_end := v_trial_end;
  ELSE
    -- Default to monthly billing
    v_period_end := NOW() + INTERVAL '1 month';
  END IF;
  
  -- Create subscription
  INSERT INTO user_subscriptions (
    user_id,
    household_id,
    plan_id,
    status,
    trial_ends_at,
    current_period_start,
    current_period_end,
    payment_provider,
    external_subscription_id
  )
  VALUES (
    p_user_id,
    p_household_id,
    v_plan_id,
    v_status,
    v_trial_end,
    v_period_start,
    v_period_end,
    p_payment_provider,
    p_external_subscription_id
  )
  RETURNING id INTO v_subscription_id;
  
  -- Update household plan
  UPDATE households
  SET current_plan_id = v_plan_id,
      subscription_updated_at = NOW()
  WHERE id = p_household_id;
  
  -- Log event
  INSERT INTO subscription_events (
    subscription_id,
    household_id,
    user_id,
    event_type,
    new_plan_id
  )
  VALUES (
    v_subscription_id,
    p_household_id,
    p_user_id,
    CASE WHEN v_status = 'trialing' THEN 'trial_started' ELSE 'created' END,
    v_plan_id
  );
  
  RETURN v_subscription_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### 6. Cancel Subscription

```sql
CREATE OR REPLACE FUNCTION cancel_subscription(
  p_subscription_id UUID,
  p_cancel_immediately BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
  v_household_id UUID;
  v_free_plan_id UUID;
BEGIN
  -- Get household ID
  SELECT household_id INTO v_household_id
  FROM user_subscriptions
  WHERE id = p_subscription_id;
  
  IF p_cancel_immediately THEN
    -- Cancel immediately - downgrade to free
    SELECT id INTO v_free_plan_id
    FROM subscription_plans
    WHERE name = 'free';
    
    UPDATE user_subscriptions
    SET status = 'expired',
        cancelled_at = NOW(),
        updated_at = NOW()
    WHERE id = p_subscription_id;
    
    UPDATE households
    SET current_plan_id = v_free_plan_id,
        subscription_updated_at = NOW()
    WHERE id = v_household_id;
    
    -- Log event
    INSERT INTO subscription_events (
      subscription_id,
      household_id,
      event_type,
      new_plan_id
    )
    VALUES (
      p_subscription_id,
      v_household_id,
      'cancelled',
      v_free_plan_id
    );
  ELSE
    -- Cancel at period end
    UPDATE user_subscriptions
    SET cancel_at_period_end = TRUE,
        cancelled_at = NOW(),
        updated_at = NOW()
    WHERE id = p_subscription_id;
    
    -- Log event
    INSERT INTO subscription_events (
      subscription_id,
      household_id,
      event_type
    )
    VALUES (
      p_subscription_id,
      v_household_id,
      'cancelled'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Database Triggers

#### 1. Auto-expire Subscriptions

```sql
CREATE OR REPLACE FUNCTION expire_subscriptions()
RETURNS VOID AS $$
DECLARE
  v_free_plan_id UUID;
BEGIN
  -- Get free plan ID
  SELECT id INTO v_free_plan_id
  FROM subscription_plans
  WHERE name = 'free';
  
  -- Update expired subscriptions
  UPDATE user_subscriptions
  SET status = 'expired',
      updated_at = NOW()
  WHERE status IN ('active', 'trialing')
    AND current_period_end < NOW();
  
  -- Downgrade households to free
  UPDATE households h
  SET current_plan_id = v_free_plan_id,
      subscription_updated_at = NOW()
  WHERE id IN (
    SELECT household_id
    FROM user_subscriptions
    WHERE status = 'expired'
      AND updated_at > NOW() - INTERVAL '1 minute'
  );
  
  -- Log events
  INSERT INTO subscription_events (subscription_id, household_id, event_type, new_plan_id)
  SELECT 
    us.id,
    us.household_id,
    'expired',
    v_free_plan_id
  FROM user_subscriptions us
  WHERE us.status = 'expired'
    AND us.updated_at > NOW() - INTERVAL '1 minute';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule this to run periodically (via pg_cron or external cron)
-- For now, you can call it manually or via Edge Function on a schedule
```

---

## iOS App Integration

### Models

#### SubscriptionPlan.swift

```swift
import Foundation

struct SubscriptionPlan: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let displayName: String
    let description: String?
    let priceMonthlyCents: Int
    let priceYearlyCents: Int
    let currency: String
    let features: FeatureLimits
    let isActive: Bool
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName = "display_name"
        case description
        case priceMonthlyCents = "price_monthly_cents"
        case priceYearlyCents = "price_yearly_cents"
        case currency
        case features
        case isActive = "is_active"
        case sortOrder = "sort_order"
    }
    
    var isFree: Bool {
        name == "free"
    }
    
    var isPremium: Bool {
        name == "premium"
    }
    
    var monthlyPrice: String {
        formatPrice(cents: priceMonthlyCents)
    }
    
    var yearlyPrice: String {
        formatPrice(cents: priceYearlyCents)
    }
    
    private func formatPrice(cents: Int) -> String {
        let amount = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct FeatureLimits: Codable, Equatable {
    let householdMembers: LimitValue
    let pantryItems: LimitValue
    let shoppingLists: LimitValue
    let barcodeScansPerMonth: LimitValue
    let analyticsHistoryDays: LimitValue
    let customCategories: Bool
    let storageLocations: Bool
    let bulkOperations: Bool
    let recipeIntegration: Bool
    let advancedAnalytics: Bool
    let photoUploads: Bool
    let listTemplates: Bool
    let priceTracking: Bool
    let aiSuggestions: Bool
    let categoryBudgets: Bool
    let exportReports: Bool
    let prioritySupport: Bool
    
    enum CodingKeys: String, CodingKey {
        case householdMembers = "household_members"
        case pantryItems = "pantry_items"
        case shoppingLists = "shopping_lists"
        case barcodeScansPerMonth = "barcode_scans_per_month"
        case analyticsHistoryDays = "analytics_history_days"
        case customCategories = "custom_categories"
        case storageLocations = "storage_locations"
        case bulkOperations = "bulk_operations"
        case recipeIntegration = "recipe_integration"
        case advancedAnalytics = "advanced_analytics"
        case photoUploads = "photo_uploads"
        case listTemplates = "list_templates"
        case priceTracking = "price_tracking"
        case aiSuggestions = "ai_suggestions"
        case categoryBudgets = "category_budgets"
        case exportReports = "export_reports"
        case prioritySupport = "priority_support"
    }
}

enum LimitValue: Codable, Equatable {
    case limited(Int)
    case unlimited
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        
        if value == -1 {
            self = .unlimited
        } else {
            self = .limited(value)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .unlimited:
            try container.encode(-1)
        case .limited(let value):
            try container.encode(value)
        }
    }
    
    var intValue: Int? {
        switch self {
        case .limited(let value):
            return value
        case .unlimited:
            return nil
        }
    }
    
    var isUnlimited: Bool {
        if case .unlimited = self {
            return true
        }
        return false
    }
}
```

#### UserSubscription.swift

```swift
import Foundation

struct UserSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let householdId: UUID
    let planId: UUID
    let status: SubscriptionStatus
    let trialStartsAt: Date?
    let trialEndsAt: Date?
    let currentPeriodStart: Date
    let currentPeriodEnd: Date
    let cancelAtPeriodEnd: Bool
    let cancelledAt: Date?
    let paymentProvider: PaymentProvider?
    let externalSubscriptionId: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case householdId = "household_id"
        case planId = "plan_id"
        case status
        case trialStartsAt = "trial_starts_at"
        case trialEndsAt = "trial_ends_at"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case cancelledAt = "cancelled_at"
        case paymentProvider = "payment_provider"
        case externalSubscriptionId = "external_subscription_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var isActive: Bool {
        (status == .active || status == .trialing) && currentPeriodEnd > Date()
    }
    
    var isInTrial: Bool {
        status == .trialing && trialEndsAt ?? Date() > Date()
    }
    
    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: currentPeriodEnd).day ?? 0
    }
}

enum SubscriptionStatus: String, Codable {
    case active
    case trialing
    case cancelled
    case expired
    case paused
}

enum PaymentProvider: String, Codable {
    case appleIAP = "apple_iap"
    case stripe
    case manual
}
```

#### FeatureUsage.swift

```swift
import Foundation

struct FeatureUsage: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    let featureKey: String
    let usageCount: Int
    let periodStart: Date
    let periodEnd: Date
    let lastUsedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case featureKey = "feature_key"
        case usageCount = "usage_count"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case lastUsedAt = "last_used_at"
    }
    
    var remainingDays: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: periodEnd).day ?? 0
    }
    
    var progressPercentage: Double {
        let total = Calendar.current.dateComponents([.day], from: periodStart, to: periodEnd).day ?? 30
        let elapsed = Calendar.current.dateComponents([.day], from: periodStart, to: Date()).day ?? 0
        return Double(elapsed) / Double(total)
    }
}

struct FeatureLimitCheck: Codable {
    let canPerform: Bool
    let currentUsage: Int
    let limitValue: Int
    let isUnlimited: Bool
    
    enum CodingKeys: String, CodingKey {
        case canPerform = "can_perform"
        case currentUsage = "current_usage"
        case limitValue = "limit_value"
        case isUnlimited = "is_unlimited"
    }
    
    var usagePercentage: Double {
        guard limitValue > 0 else { return 0 }
        return Double(currentUsage) / Double(limitValue)
    }
    
    var remaining: Int {
        guard limitValue > 0 else { return 0 }
        return max(0, limitValue - currentUsage)
    }
}
```

### Services

#### SubscriptionService.swift

```swift
import Foundation
import Supabase

@MainActor
class SubscriptionService: ObservableObject {
    @Published var currentSubscription: UserSubscription?
    @Published var currentPlan: SubscriptionPlan?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let supabase: SupabaseClient
    
    init(supabase: SupabaseClient = SupabaseManager.shared.client) {
        self.supabase = supabase
    }
    
    // MARK: - Fetch Subscription
    
    func fetchCurrentSubscription(for householdId: UUID) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: [UserSubscription] = try await supabase
                .from("user_subscriptions")
                .select()
                .eq("household_id", value: householdId.uuidString)
                .in("status", values: ["active", "trialing"])
                .gt("current_period_end", value: ISO8601DateFormatter().string(from: Date()))
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            currentSubscription = response.first
            
            if let subscription = currentSubscription {
                try await fetchPlan(planId: subscription.planId)
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    func fetchPlan(planId: UUID) async throws {
        let response: SubscriptionPlan = try await supabase
            .from("subscription_plans")
            .select()
            .eq("id", value: planId.uuidString)
            .single()
            .execute()
            .value
        
        currentPlan = response
    }
    
    // MARK: - Check Features
    
    func canUseFeature(_ featureKey: String, householdId: UUID) async throws -> Bool {
        guard let plan = currentPlan else {
            // If no plan loaded, assume free tier
            return false
        }
        
        // For boolean features, check directly
        switch featureKey {
        case "custom_categories":
            return plan.features.customCategories
        case "storage_locations":
            return plan.features.storageLocations
        case "bulk_operations":
            return plan.features.bulkOperations
        case "recipe_integration":
            return plan.features.recipeIntegration
        case "advanced_analytics":
            return plan.features.advancedAnalytics
        case "photo_uploads":
            return plan.features.photoUploads
        case "list_templates":
            return plan.features.listTemplates
        case "price_tracking":
            return plan.features.priceTracking
        case "ai_suggestions":
            return plan.features.aiSuggestions
        case "category_budgets":
            return plan.features.categoryBudgets
        case "export_reports":
            return plan.features.exportReports
        case "priority_support":
            return plan.features.prioritySupport
        default:
            return false
        }
    }
    
    func checkFeatureLimit(_ featureKey: String, householdId: UUID) async throws -> FeatureLimitCheck {
        let response: FeatureLimitCheck = try await supabase
            .rpc("check_feature_limit", params: [
                "p_household_id": householdId.uuidString,
                "p_feature_key": featureKey
            ])
            .single()
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Usage Tracking
    
    func incrementUsage(_ featureKey: String, householdId: UUID, userId: UUID) async throws {
        try await supabase
            .rpc("increment_feature_usage", params: [
                "p_household_id": householdId.uuidString,
                "p_feature_key": featureKey,
                "p_user_id": userId.uuidString
            ])
            .execute()
    }
    
    func fetchFeatureUsage(householdId: UUID, featureKey: String) async throws -> FeatureUsage? {
        let response: [FeatureUsage] = try await supabase
            .from("feature_usage")
            .select()
            .eq("household_id", value: householdId.uuidString)
            .eq("feature_key", value: featureKey)
            .gt("period_end", value: ISO8601DateFormatter().string(from: Date()))
            .execute()
            .value
        
        return response.first
    }
    
    // MARK: - Subscription Management
    
    func createSubscription(
        userId: UUID,
        householdId: UUID,
        planName: String,
        paymentProvider: PaymentProvider = .appleIAP,
        externalSubscriptionId: String? = nil,
        trialDays: Int? = nil
    ) async throws -> UUID {
        let response: UUID = try await supabase
            .rpc("create_subscription", params: [
                "p_user_id": userId.uuidString,
                "p_household_id": householdId.uuidString,
                "p_plan_name": planName,
                "p_payment_provider": paymentProvider.rawValue,
                "p_external_subscription_id": externalSubscriptionId as Any,
                "p_trial_days": trialDays as Any
            ])
            .single()
            .execute()
            .value
        
        // Refresh subscription after creation
        try await fetchCurrentSubscription(for: householdId)
        
        return response
    }
    
    func cancelSubscription(subscriptionId: UUID, immediately: Bool = false) async throws {
        try await supabase
            .rpc("cancel_subscription", params: [
                "p_subscription_id": subscriptionId.uuidString,
                "p_cancel_immediately": immediately
            ])
            .execute()
        
        // Refresh subscription after cancellation
        if let householdId = currentSubscription?.householdId {
            try await fetchCurrentSubscription(for: householdId)
        }
    }
    
    // MARK: - Helper Properties
    
    var isPremium: Bool {
        currentPlan?.isPremium ?? false
    }
    
    var isFree: Bool {
        currentPlan?.isFree ?? true
    }
    
    var isActive: Bool {
        currentSubscription?.isActive ?? false
    }
}
```

#### FeatureGateService.swift

```swift
import Foundation
import SwiftUI

@MainActor
class FeatureGateService: ObservableObject {
    @Published var showPaywall = false
    @Published var paywallFeature: PaywallFeature?
    
    private let subscriptionService: SubscriptionService
    
    init(subscriptionService: SubscriptionService) {
        self.subscriptionService = subscriptionService
    }
    
    // MARK: - Feature Checks with Automatic Paywall
    
    func canPerformAction(
        _ featureKey: String,
        householdId: UUID,
        showPaywallIfBlocked: Bool = true
    ) async -> Bool {
        do {
            let limitCheck = try await subscriptionService.checkFeatureLimit(featureKey, householdId: householdId)
            
            if !limitCheck.canPerform && showPaywallIfBlocked {
                paywallFeature = PaywallFeature.from(featureKey: featureKey, limitCheck: limitCheck)
                showPaywall = true
            }
            
            return limitCheck.canPerform
        } catch {
            print("Error checking feature limit: \(error)")
            return false
        }
    }
    
    func canUseFeature(
        _ featureKey: String,
        householdId: UUID,
        showPaywallIfBlocked: Bool = true
    ) async -> Bool {
        do {
            let canUse = try await subscriptionService.canUseFeature(featureKey, householdId: householdId)
            
            if !canUse && showPaywallIfBlocked {
                paywallFeature = PaywallFeature.from(featureKey: featureKey)
                showPaywall = true
            }
            
            return canUse
        } catch {
            print("Error checking feature access: \(error)")
            return false
        }
    }
    
    // MARK: - Increment Usage
    
    func recordUsage(_ featureKey: String, householdId: UUID, userId: UUID) async {
        do {
            try await subscriptionService.incrementUsage(featureKey, householdId: householdId, userId: userId)
        } catch {
            print("Error recording usage: \(error)")
        }
    }
}

// MARK: - Paywall Feature Models

struct PaywallFeature {
    let title: String
    let description: String
    let icon: String
    let limitInfo: LimitInfo?
    
    struct LimitInfo {
        let current: Int
        let limit: Int
        let remaining: Int
    }
    
    static func from(featureKey: String, limitCheck: FeatureLimitCheck? = nil) -> PaywallFeature {
        let limitInfo: LimitInfo? = {
            guard let check = limitCheck else { return nil }
            return LimitInfo(
                current: check.currentUsage,
                limit: check.limitValue,
                remaining: check.remaining
            )
        }()
        
        switch featureKey {
        case "household_members":
            return PaywallFeature(
                title: "Unlimited Members",
                description: "Free includes you (owner/admin) plus one member. Upgrade to invite the whole household.",
                icon: "person.3.fill",
                limitInfo: limitInfo
            )
        case "pantry_items":
            return PaywallFeature(
                title: "Unlimited Pantry Items",
                description: "Track as many pantry items as you need",
                icon: "square.grid.3x3.fill",
                limitInfo: limitInfo
            )
        case "shopping_lists":
            return PaywallFeature(
                title: "Unlimited Shopping Lists",
                description: "Create lists for different stores and occasions",
                icon: "list.bullet",
                limitInfo: limitInfo
            )
        case "barcode_scans_per_month":
            return PaywallFeature(
                title: "Unlimited Barcode Scans",
                description: "Scan as many barcodes as you want every month",
                icon: "barcode.viewfinder",
                limitInfo: limitInfo
            )
        case "advanced_analytics":
            return PaywallFeature(
                title: "Advanced Analytics",
                description: "Get detailed insights into spending and waste patterns",
                icon: "chart.line.uptrend.xyaxis",
                limitInfo: nil
            )
        case "bulk_operations":
            return PaywallFeature(
                title: "Bulk Operations",
                description: "Edit or delete multiple items at once",
                icon: "square.stack.3d.up.fill",
                limitInfo: nil
            )
        case "recipe_integration":
            return PaywallFeature(
                title: "Recipe Integration",
                description: "Link items to recipes and auto-deduct ingredients",
                icon: "book.closed.fill",
                limitInfo: nil
            )
        default:
            return PaywallFeature(
                title: "Premium Feature",
                description: "Upgrade to Premium to unlock this feature",
                icon: "star.fill",
                limitInfo: nil
            )
        }
    }
}
```

---

## Payment Integration

### Apple In-App Purchase Setup

#### 1. App Store Connect Configuration

1. **Create In-App Purchase Products:**
   - Go to App Store Connect > Your App > In-App Purchases
   - Create two products:
     - **Premium Monthly:** `com.grubshelf.premium.monthly` - $4.99/month (Auto-renewable subscription)
     - **Premium Yearly:** `com.grubshelf.premium.yearly` - $49.99/year (Auto-renewable subscription)

2. **Subscription Group:**
   - Create a subscription group: "GrubShelf Premium"
   - Add both products to the group
   - Set upgrade/downgrade rules (yearly is higher tier)

3. **Pricing:**
   - Set pricing for all territories
   - Enable automatic price increase consent

4. **Metadata:**
   - Add display names, descriptions
   - Add promotional images if needed

#### 2. StoreKit Configuration File

Create `Configuration.storekit` for local testing:

```json
{
  "identifier" : "Configuration",
  "nonRenewingSubscriptions" : [],
  "products" : [],
  "settings" : {
    "_failTransactionsEnabled" : false,
    "_storeKitErrors" : [],
    "_timeRate" : 1,
    "_locale" : "en_US"
  },
  "subscriptionGroups" : [
    {
      "id" : "21234567",
      "localizations" : [],
      "name" : "GrubShelf Premium",
      "subscriptions" : [
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "4.99",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "6504134567",
          "introductoryOffer" : {
            "internalID" : "6504567890",
            "numberOfPeriods" : 1,
            "paymentMode" : "free",
            "subscriptionPeriod" : "P1W"
          },
          "localizations" : [
            {
              "description" : "Unlimited features for families",
              "displayName" : "Premium Monthly",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.grubshelf.premium.monthly",
          "recurringSubscriptionPeriod" : "P1M",
          "referenceName" : "Premium Monthly",
          "subscriptionGroupID" : "21234567",
          "type" : "RecurringSubscription"
        },
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "49.99",
          "familyShareable" : false,
          "groupNumber" : 2,
          "internalID" : "6504134568",
          "introductoryOffer" : {
            "internalID" : "6504567891",
            "numberOfPeriods" : 1,
            "paymentMode" : "free",
            "subscriptionPeriod" : "P1W"
          },
          "localizations" : [
            {
              "description" : "Best value - save 17%!",
              "displayName" : "Premium Yearly",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.grubshelf.premium.yearly",
          "recurringSubscriptionPeriod" : "P1Y",
          "referenceName" : "Premium Yearly",
          "subscriptionGroupID" : "21234567",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : {
    "major" : 3,
    "minor" : 0
  }
}
```

#### 3. StoreKit Service Implementation

```swift
import StoreKit
import Foundation

@MainActor
class StoreKitService: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let productIDs = [
        "com.grubshelf.premium.monthly",
        "com.grubshelf.premium.yearly"
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    private let subscriptionService: SubscriptionService
    
    init(subscriptionService: SubscriptionService) {
        self.subscriptionService = subscriptionService
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: productIDs)
            
            // Sort: yearly first (better value), then monthly
            products.sort { product1, product2 in
                if product1.id.contains("yearly") && product2.id.contains("monthly") {
                    return true
                }
                return false
            }
        } catch {
            self.error = error
            print("Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Sync with backend
            try await syncSubscription(transaction)
            
            // Finish transaction
            await transaction.finish()
            
            await updatePurchasedProducts()
            
            return transaction
            
        case .userCancelled, .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    // MARK: - Check Subscription Status
    
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                purchasedIDs.insert(transaction.productID)
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
    }
    
    func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }
    
    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Sync with backend
                    try await self.syncSubscription(transaction)
                    
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    // MARK: - Receipt Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Backend Sync
    
    private func syncSubscription(_ transaction: Transaction) async throws {
        guard let householdId = CurrentUserManager.shared.currentHousehold?.id,
              let userId = CurrentUserManager.shared.userId else {
            return
        }
        
        let planName: String
        if transaction.productID.contains("premium") {
            planName = "premium"
        } else {
            planName = "free"
        }
        
        // Create or update subscription in backend
        let _ = try await subscriptionService.createSubscription(
            userId: userId,
            householdId: householdId,
            planName: planName,
            paymentProvider: .appleIAP,
            externalSubscriptionId: String(transaction.id)
        )
    }
}

enum StoreError: Error {
    case failedVerification
}
```

---

## UI/UX Implementation

### Paywall Views

#### PaywallView.swift

```swift
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeKit: StoreKitService
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    
    let feature: PaywallFeature?
    
    init(feature: PaywallFeature? = nil, storeKit: StoreKitService) {
        self.feature = feature
        self._storeKit = StateObject(wrappedValue: storeKit)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow, .orange)
                        
                        Text("Upgrade to Premium")
                            .font(.title.bold())
                        
                        if let feature = feature {
                            Text(feature.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            // Show limit info if available
                            if let limitInfo = feature.limitInfo {
                                LimitReachedBanner(limitInfo: limitInfo)
                            }
                        } else {
                            Text("Unlock all features for your household")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top)
                    
                    // Features List
                    PremiumFeaturesList()
                    
                    // Pricing Cards
                    if storeKit.isLoading {
                        ProgressView()
                            .frame(height: 200)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(storeKit.products) { product in
                                PricingCard(
                                    product: product,
                                    isSelected: selectedProduct?.id == product.id
                                )
                                .onTapGesture {
                                    selectedProduct = product
                                }
                            }
                        }
                    }
                    
                    // Purchase Button
                    Button(action: purchaseSelected) {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isPurchasing ? "Processing..." : "Continue")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedProduct == nil || isPurchasing)
                    
                    // Restore Purchases
                    Button("Restore Purchases") {
                        Task {
                            try? await storeKit.restorePurchases()
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    
                    // Legal
                    Text("Subscription automatically renews unless cancelled. See [Terms](https://grubshelf.app/terms) and [Privacy Policy](https://grubshelf.app/privacy).")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await storeKit.loadProducts()
            // Pre-select yearly (better value)
            selectedProduct = storeKit.products.first
        }
    }
    
    private func purchaseSelected() {
        guard let product = selectedProduct else { return }
        
        Task {
            isPurchasing = true
            defer { isPurchasing = false }
            
            do {
                let transaction = try await storeKit.purchase(product)
                if transaction != nil {
                    dismiss()
                }
            } catch {
                print("Purchase failed: \(error)")
            }
        }
    }
}

struct LimitReachedBanner: View {
    let limitInfo: PaywallFeature.LimitInfo
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Limit Reached")
                    .font(.subheadline.bold())
                
                Text("\(limitInfo.current) of \(limitInfo.limit) used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PremiumFeaturesList: View {
    let features: [(icon: String, title: String, description: String)] = [
        ("person.3.fill", "Unlimited Members", "Add everyone in your household"),
        ("square.grid.3x3.fill", "Unlimited Items", "Track everything in your pantry"),
        ("barcode.viewfinder", "Unlimited Scans", "Scan as much as you want"),
        ("chart.line.uptrend.xyaxis", "Advanced Analytics", "Deep insights into spending & waste"),
        ("book.closed.fill", "Recipe Integration", "Link items to your favorite recipes"),
        ("square.stack.3d.up.fill", "Bulk Operations", "Edit multiple items at once")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.title2)
                        .foregroundStyle(.accent)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline.bold())
                        Text(feature.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct PricingCard: View {
    let product: Product
    let isSelected: Bool
    
    var isYearly: Bool {
        product.id.contains("yearly")
    }
    
    var savingsText: String? {
        isYearly ? "Save 17%" : nil
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                
                if let savings = savingsText {
                    Text(savings)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(product.displayPrice)
                    .font(.title3.bold())
                
                Text(isYearly ? "per year" : "per month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? .accent : .secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
```

#### Usage Limit Banner

```swift
struct UsageLimitBanner: View {
    let featureKey: String
    let limitCheck: FeatureLimitCheck
    let onUpgrade: () -> Void
    
    var warningThreshold: Double {
        0.8 // Show warning at 80%
    }
    
    var shouldShow: Bool {
        !limitCheck.isUnlimited && limitCheck.usagePercentage >= warningThreshold
    }
    
    var body: some View {
        if shouldShow {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(limitMessage)
                        .font(.subheadline.bold())
                    
                    ProgressView(value: limitCheck.usagePercentage)
                        .tint(limitCheck.usagePercentage >= 1.0 ? .red : .orange)
                    
                    Text("\(limitCheck.currentUsage) of \(limitCheck.limitValue) used • \(limitCheck.remaining) remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button("Upgrade") {
                    onUpgrade()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(bannerColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var limitMessage: String {
        if limitCheck.usagePercentage >= 1.0 {
            return "Limit Reached"
        } else {
            return "Approaching Limit"
        }
    }
    
    private var bannerColor: Color {
        limitCheck.usagePercentage >= 1.0 ? .red : .orange
    }
}
```

---

## Testing Strategy

### Test Scenarios

#### 1. Free Tier Limits

**Household Members (free = owner/admin + 1 member):**
- ✅ Household has owner/admin + 1 invited member (2 total)
- ❌ Cannot invite or accept a 3rd member → Shows paywall
- ✅ After upgrade, can add unlimited members
- ✅ One household per user (no second household to join or create)

**Pantry Items:**
- ✅ Can add items 1-75
- ❌ Cannot add 76th item → Shows paywall
- ✅ After upgrade, can add unlimited items

**Shopping Lists:**
- ✅ Can create 1st list
- ✅ Can create 2nd list
- ❌ Cannot create 3rd list → Shows paywall
- ✅ After upgrade, can create unlimited lists

**Barcode Scans:**
- ✅ Can scan 1-20 times per month
- ❌ 21st scan shows paywall
- ✅ Counter resets next month
- ✅ After upgrade, unlimited scans

#### 2. Premium-Only Features

**Boolean Features:**
- ❌ Free: Custom categories button disabled
- ❌ Free: Bulk operations unavailable
- ❌ Free: Advanced analytics locked
- ✅ Premium: All features unlocked

#### 3. Subscription Management

**Purchase Flow:**
- ✅ Can view paywall
- ✅ Can select monthly plan
- ✅ Can select yearly plan
- ✅ Can complete purchase
- ✅ Subscription syncs to backend
- ✅ Features unlock immediately

**Restore Purchases:**
- ✅ Can restore on new device
- ✅ Features unlock after restore

**Cancellation:**
- ✅ Can cancel subscription
- ✅ Access continues until period end
- ✅ Downgrade to free at expiration

**Expiration:**
- ✅ Subscription expires at period end
- ✅ Auto-downgrade to free plan
- ✅ Data preserved but limited

#### 4. Edge Cases

- ✅ New user defaults to free plan
- ✅ Existing users grandfathered (if applicable)
- ✅ Subscription persists across devices
- ✅ Offline mode shows cached plan
- ✅ Failed payment handling
- ✅ Refund handling

### Testing Checklist

```markdown
## Phase 1: Database & Backend
- [ ] All migrations run successfully
- [ ] RPC functions work correctly
- [ ] Feature limits enforced in database
- [ ] Usage tracking increments properly
- [ ] Subscription creation works
- [ ] Subscription cancellation works
- [ ] Auto-expiration cron job works

## Phase 2: iOS App
- [ ] Models decode correctly from Supabase
- [ ] SubscriptionService fetches data
- [ ] FeatureGateService checks limits
- [ ] Paywalls display correctly
- [ ] StoreKit loads products
- [ ] Purchase flow completes
- [ ] Receipt validation works
- [ ] Backend sync after purchase

## Phase 3: UI/UX
- [ ] Paywall designs match mockups
- [ ] Limit banners show at correct thresholds
- [ ] Upgrade buttons go to paywall
- [ ] Settings show subscription status
- [ ] Manage subscription works

## Phase 4: App Store
- [ ] In-App Purchase products approved
- [ ] Subscription group configured
- [ ] Pricing correct in all regions
- [ ] Metadata complete
- [ ] Test subscription in Sandbox
```

---

## Migration & Rollout Plan

### Phase 1: Database Setup (Week 1)

**Tasks:**
1. Create migration files
2. Run migrations on staging
3. Seed default plans
4. Test RPC functions
5. Create Edge Functions (if needed)

**Deliverables:**
- `037_subscription_system.sql`
- `038_subscription_rpcs.sql`
- Seed data script

**Testing:**
- Verify all tables created
- Test RPC functions manually
- Check default plan assignment

### Phase 2: iOS Models & Services (Week 2)

**Tasks:**
1. Create all model files
2. Implement SubscriptionService
3. Implement FeatureGateService
4. Add unit tests
5. Test on staging backend

**Deliverables:**
- All Swift model files
- Service implementations
- Unit test suite

**Testing:**
- API calls work correctly
- Error handling works
- Offline caching works

### Phase 3: Payment Integration (Week 3)

**Tasks:**
1. Configure App Store Connect
2. Create StoreKit configuration
3. Implement StoreKitService
4. Test in Sandbox
5. Implement receipt validation

**Deliverables:**
- StoreKit configuration
- StoreKitService implementation
- Receipt validation logic

**Testing:**
- Sandbox purchases work
- Receipt validation succeeds
- Backend sync works
- Restore purchases works

### Phase 4: UI Implementation (Week 4)

**Tasks:**
1. Design paywall screens
2. Implement PaywallView
3. Add limit banners
4. Update Settings
5. Add upgrade CTAs throughout app

**Deliverables:**
- PaywallView implementation
- Usage limit components
- Settings subscription section
- Upgrade prompts

**Testing:**
- All paywalls display correctly
- Limit warnings show at right times
- Navigation works smoothly
- Accessibility checks pass

### Phase 5: Integration Testing (Week 5)

**Tasks:**
1. End-to-end testing
2. Fix bugs
3. Performance testing
4. UX refinements
5. Beta testing with internal users

**Deliverables:**
- Bug fix commits
- Performance improvements
- UX tweaks

**Testing:**
- Complete test checklist
- Beta user feedback
- Analytics tracking works

### Phase 6: Soft Launch (Week 6)

**Tasks:**
1. Deploy to production
2. Monitor closely
3. Gather user feedback
4. Fix critical issues
5. Prepare marketing materials

**Strategy:**
- Launch to existing users first
- Monitor metrics daily
- Respond to support tickets quickly
- Iterate based on feedback

**Metrics to Track:**
- Conversion rate (free → premium)
- Churn rate
- Revenue
- Feature adoption
- Support ticket volume

### Phase 7: Full Launch (Week 7+)

**Tasks:**
1. Marketing push
2. App Store feature request
3. Blog post/social media
4. Monitor growth
5. Plan feature iterations

---

## Code Examples

### Example: Checking Pantry Item Limit Before Adding

```swift
// In AddPantryItemView.swift

@State private var showingLimitReached = false
@StateObject private var featureGate: FeatureGateService

func addItem() {
    Task {
        guard let householdId = household.id else { return }
        
        // Check if user can add item
        let canAdd = await featureGate.canPerformAction(
            "pantry_items",
            householdId: householdId,
            showPaywallIfBlocked: true
        )
        
        if canAdd {
            // Proceed with adding item
            try? await pantryService.addItem(item)
        }
        // Paywall shown automatically if limit reached
    }
}
```

### Example: Showing Usage Banner for Barcode Scans

```swift
// In BarcodeScannerView.swift

@State private var barcodeUsage: FeatureLimitCheck?
@StateObject private var subscriptionService: SubscriptionService

var body: some View {
    VStack {
        // Show usage banner if approaching limit
        if let usage = barcodeUsage, !usage.isUnlimited {
            UsageLimitBanner(
                featureKey: "barcode_scans_per_month",
                limitCheck: usage,
                onUpgrade: { showPaywall = true }
            )
        }
        
        // Scanner UI
        BarcodeScannerCamera()
    }
    .task {
        guard let householdId = household.id else { return }
        
        barcodeUsage = try? await subscriptionService.checkFeatureLimit(
            "barcode_scans_per_month",
            householdId: householdId
        )
    }
}
```

### Example: Premium-Only Feature Lock

```swift
// In AdvancedAnalyticsView.swift

@StateObject private var featureGate: FeatureGateService
@State private var canAccess = false

var body: some View {
    Group {
        if canAccess {
            // Show full analytics
            AdvancedAnalyticsContent()
        } else {
            // Show locked state
            PremiumFeatureLockView(
                icon: "chart.line.uptrend.xyaxis",
                title: "Advanced Analytics",
                description: "Get detailed insights into your spending patterns and waste reduction.",
                onUpgrade: { showPaywall = true }
            )
        }
    }
    .task {
        guard let householdId = household.id else { return }
        
        canAccess = await featureGate.canUseFeature(
            "advanced_analytics",
            householdId: householdId,
            showPaywallIfBlocked: false
        )
    }
}

struct PremiumFeatureLockView: View {
    let icon: String
    let title: String
    let description: String
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(.gray.opacity(0.3))
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("Premium Feature")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                
                Text(title)
                    .font(.title2.bold())
                
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            Button(action: onUpgrade) {
                Label("Upgrade to Premium", systemImage: "star.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

---

## Troubleshooting

### Common Issues

#### 1. StoreKit Products Not Loading

**Symptoms:**
- Empty products array
- Products fail to load in paywall

**Solutions:**
- Check product IDs match App Store Connect exactly
- Verify products are approved and active
- Ensure Agreements & Tax forms completed in App Store Connect
- Try clearing StoreKit cache (Xcode > Debug > StoreKit > Clear Transaction History)
- Test with StoreKit configuration file locally

#### 2. Receipt Validation Failing

**Symptoms:**
- Purchase completes but doesn't sync to backend
- Subscription status not updating

**Solutions:**
- Check receipt data being sent correctly
- Verify server-side validation logic
- Ensure using correct Apple environment (sandbox vs production)
- Check for expired certificates

#### 3. Feature Limits Not Enforcing

**Symptoms:**
- Users can exceed limits
- Paywalls not showing

**Solutions:**
- Verify RPC functions returning correct values
- Check feature usage increments happening
- Ensure household plan_id set correctly
- Test database queries manually

#### 4. Subscription Not Restoring

**Symptoms:**
- Restore purchases doesn't work
- User loses premium access on new device

**Solutions:**
- Check App Store receipt present
- Verify `AppStore.sync()` called correctly
- Ensure checking `Transaction.currentEntitlements`
- Test with TestFlight build (Sandbox behaves differently)

#### 5. Usage Counter Not Resetting Monthly

**Symptoms:**
- Barcode scan limit persists past month boundary
- Monthly limits don't reset

**Solutions:**
- Check `period_end` field in `feature_usage` table
- Verify monthly period calculation logic
- Ensure using `DATE_TRUNC('month', NOW())` correctly
- Set up cron job or scheduled task to clean old records

### Debug Checklist

When encountering subscription issues:

1. **Check Database:**
   ```sql
   -- Verify subscription exists
   SELECT * FROM user_subscriptions WHERE household_id = 'xxx';
   
   -- Check household plan
   SELECT h.*, sp.name FROM households h
   JOIN subscription_plans sp ON h.current_plan_id = sp.id
   WHERE h.id = 'xxx';
   
   -- Check feature usage
   SELECT * FROM feature_usage WHERE household_id = 'xxx';
   ```

2. **Check iOS App:**
   - Print subscription service state
   - Verify current plan loaded
   - Check StoreKit transaction state
   - Confirm receipt data present

3. **Check StoreKit:**
   - View transaction history in Xcode
   - Check subscription status in Settings app (Sandbox account)
   - Verify products configured correctly

4. **Check Logs:**
   - Supabase function logs
   - iOS console logs
   - StoreKit debug logs

---

## Next Steps

### Immediate Actions (This Week)

1. **Review & Approve:**
   - Review this documentation
   - Approve pricing strategy
   - Finalize feature list

2. **Database Setup:**
   - Create migration files
   - Test on local Supabase instance
   - Deploy to staging

3. **App Store Connect:**
   - Create IAP products
   - Set up subscription group
   - Configure pricing

### Short Term (Weeks 2-4)

1. **iOS Development:**
   - Implement models & services
   - Build paywall UI
   - Integrate StoreKit

2. **Testing:**
   - Sandbox testing
   - Internal beta testing
   - Bug fixes

### Long Term (Months 2-6)

1. **Launch:**
   - Soft launch to existing users
   - Monitor metrics
   - Iterate based on feedback

2. **Optimization:**
   - A/B test pricing
   - Refine paywall messaging
   - Add more premium features

3. **Expansion:**
   - Consider three-tier model
   - Add family sharing
   - Explore web version with Stripe

---

## Appendix

### Useful SQL Queries

```sql
-- Get all subscriptions expiring in next 7 days
SELECT 
  us.*,
  sp.name as plan_name,
  h.name as household_name
FROM user_subscriptions us
JOIN subscription_plans sp ON us.plan_id = sp.id
JOIN households h ON us.household_id = h.id
WHERE us.status = 'active'
  AND us.current_period_end BETWEEN NOW() AND NOW() + INTERVAL '7 days'
ORDER BY us.current_period_end ASC;

-- Revenue report (monthly)
SELECT 
  DATE_TRUNC('month', us.created_at) as month,
  sp.name as plan,
  COUNT(*) as subscriptions,
  SUM(
    CASE 
      WHEN us.external_subscription_id LIKE '%yearly%' THEN sp.price_yearly_cents
      ELSE sp.price_monthly_cents
    END
  ) / 100.0 as revenue
FROM user_subscriptions us
JOIN subscription_plans sp ON us.plan_id = sp.id
WHERE us.status IN ('active', 'trialing')
GROUP BY month, sp.name
ORDER BY month DESC;

-- Feature usage report
SELECT 
  fu.feature_key,
  COUNT(DISTINCT fu.household_id) as households_using,
  AVG(fu.usage_count) as avg_usage,
  MAX(fu.usage_count) as max_usage
FROM feature_usage fu
WHERE fu.period_end > NOW()
GROUP BY fu.feature_key
ORDER BY households_using DESC;

-- Conversion funnel
SELECT 
  COUNT(DISTINCT h.id) as total_households,
  COUNT(DISTINCT CASE WHEN sp.name = 'free' THEN h.id END) as free_households,
  COUNT(DISTINCT CASE WHEN sp.name = 'premium' THEN h.id END) as premium_households,
  ROUND(
    100.0 * COUNT(DISTINCT CASE WHEN sp.name = 'premium' THEN h.id END) / 
    NULLIF(COUNT(DISTINCT h.id), 0),
    2
  ) as conversion_rate_pct
FROM households h
JOIN subscription_plans sp ON h.current_plan_id = sp.id;
```

### Resources

- [Apple In-App Purchase Documentation](https://developer.apple.com/in-app-purchase/)
- [StoreKit 2 Guide](https://developer.apple.com/documentation/storekit/in-app_purchase)
- [Supabase Documentation](https://supabase.com/docs)
- [App Store Review Guidelines - Subscriptions](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)

---

**Document maintained by:** Development Team  
**Questions or suggestions:** Contact team lead

**Version History:**
- v1.0 (May 15, 2026) - Initial documentation
