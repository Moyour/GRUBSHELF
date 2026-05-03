-- Pantry item storage location (fridge vs shelf) for filtering and inventory layout.

ALTER TABLE pantry_items
ADD COLUMN IF NOT EXISTS storage_location TEXT NOT NULL DEFAULT 'shelf'
CHECK (storage_location IN ('fridge', 'shelf'));

COMMENT ON COLUMN pantry_items.storage_location IS 'Where the item is stored: fridge or shelf';
