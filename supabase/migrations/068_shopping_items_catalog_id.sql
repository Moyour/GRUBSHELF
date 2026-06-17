-- Every shopping line can reference one grocery_catalog product (unique catalog_item_id per product name).
-- Required for all catalog-backed adds (meat, dairy, produce, etc.); free-text lines may leave this NULL.

ALTER TABLE shopping_items
    ADD COLUMN IF NOT EXISTS catalog_item_id UUID
        REFERENCES grocery_catalog(catalog_item_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_shopping_items_catalog_id
    ON shopping_items (list_id, catalog_item_id)
    WHERE catalog_item_id IS NOT NULL;
