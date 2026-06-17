-- Adjust free tier limits: raise pantry items from 75 to 150, shopping lists from 2 to 3
-- Adjust pricing: monthly from $4.99 to $1.99, yearly from $49.99 to $14.99

UPDATE subscription_plans
SET features = jsonb_set(
      jsonb_set(features, '{pantry_items}', '150'),
      '{shopping_lists}', '3'
    ),
    updated_at = now()
WHERE name = 'free';

UPDATE subscription_plans
SET price_monthly_cents = 199,
    price_yearly_cents = 1499,
    updated_at = now()
WHERE name = 'premium';
