-- Global catalog identity: every grocery_catalog row = one product = one UUID (catalog_item_id).
-- Applies to all products (meat, dairy, produce, etc.), not any single category.
-- Enforces one catalog row per display name and backfills shopping_items.catalog_item_id.

-- Remove duplicate seed rows (e.g. 015 + 016 both inserted "Evaporated Milk").
DO $$
BEGIN
    CREATE TEMP TABLE grocery_catalog_dupes (
        duplicate_id UUID PRIMARY KEY,
        keeper_id UUID NOT NULL
    ) ON COMMIT DROP;

    INSERT INTO grocery_catalog_dupes (duplicate_id, keeper_id)
    WITH canonical AS (
        SELECT DISTINCT ON (lower(trim(name)))
            catalog_item_id,
            lower(trim(name)) AS norm_name
        FROM grocery_catalog
        ORDER BY lower(trim(name)), catalog_item_id
    )
    SELECT g.catalog_item_id, c.catalog_item_id
    FROM grocery_catalog g
    JOIN canonical c ON lower(trim(g.name)) = c.norm_name
    WHERE g.catalog_item_id <> c.catalog_item_id;

    UPDATE shopping_items si
    SET catalog_item_id = d.keeper_id
    FROM grocery_catalog_dupes d
    WHERE si.catalog_item_id = d.duplicate_id;

    UPDATE household_barcode_labels hbl
    SET catalog_item_id = d.keeper_id
    FROM grocery_catalog_dupes d
    WHERE hbl.catalog_item_id = d.duplicate_id;

    DELETE FROM grocery_catalog g
    USING grocery_catalog_dupes d
    WHERE g.catalog_item_id = d.duplicate_id;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_grocery_catalog_name_unique
    ON grocery_catalog (lower(trim(name)));

-- Link existing shopping lines to their catalog product when names match exactly (one catalog row per name).
UPDATE shopping_items si
SET catalog_item_id = gc.catalog_item_id
FROM (
    SELECT DISTINCT ON (lower(trim(name)))
        catalog_item_id,
        lower(trim(name)) AS norm_name
    FROM grocery_catalog
    ORDER BY lower(trim(name)), catalog_item_id
) gc
WHERE si.catalog_item_id IS NULL
  AND lower(trim(si.name)) = gc.norm_name;
