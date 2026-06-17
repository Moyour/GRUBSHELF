-- 079_update_pricing.sql
-- Update premium pricing: $1.99/$14.99 → $4.99/$54.99

UPDATE subscription_plans
SET price_monthly_cents = 499,
    price_yearly_cents = 5499,
    updated_at = now()
WHERE name = 'premium';
