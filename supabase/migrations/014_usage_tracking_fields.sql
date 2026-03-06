-- Migration 014: Add usage tracking and reminder fields to pantry_items
-- Supports the Pantry Item Usage & Batched Reminder system

-- Track when quantity was last updated (for staleness detection)
ALTER TABLE pantry_items
ADD COLUMN IF NOT EXISTS last_quantity_update_date TIMESTAMPTZ DEFAULT now();

-- Expected usage cycle in days (category-based defaults applied at app level)
ALTER TABLE pantry_items
ADD COLUMN IF NOT EXISTS expected_usage_cycle_days INT;

-- Reminder status: active (default), snoozed, dismissed
ALTER TABLE pantry_items
ADD COLUMN IF NOT EXISTS reminder_status TEXT NOT NULL DEFAULT 'active'
CHECK (reminder_status IN ('active', 'snoozed', 'dismissed'));

-- When a snoozed reminder should reactivate
ALTER TABLE pantry_items
ADD COLUMN IF NOT EXISTS reminder_snoozed_until TIMESTAMPTZ;

-- Backfill: set last_quantity_update_date to updated_at for existing rows
UPDATE pantry_items
SET last_quantity_update_date = updated_at
WHERE last_quantity_update_date IS NULL OR last_quantity_update_date = now();

-- Index for efficient staleness queries
CREATE INDEX IF NOT EXISTS idx_pantry_items_usage_tracking
ON pantry_items (household_id, reminder_status, last_quantity_update_date);
