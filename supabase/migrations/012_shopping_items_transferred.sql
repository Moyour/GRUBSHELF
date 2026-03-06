-- Add missing transferred column to shopping_items table
-- The Swift model expects this column for the shopping-to-pantry transfer flow
ALTER TABLE shopping_items ADD COLUMN IF NOT EXISTS transferred BOOLEAN NOT NULL DEFAULT false;
