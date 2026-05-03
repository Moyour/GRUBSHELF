-- Per-household remembered names for barcodes (pantry-style labels after first save).

CREATE TABLE household_barcode_labels (
    household_id UUID NOT NULL REFERENCES households(household_id) ON DELETE CASCADE,
    barcode TEXT NOT NULL CHECK (
        char_length(barcode) BETWEEN 8 AND 14
        AND barcode ~ '^[0-9]+$'
    ),
    display_name TEXT NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 120),
    category TEXT NOT NULL CHECK (char_length(category) BETWEEN 1 AND 40),
    catalog_item_id UUID REFERENCES grocery_catalog(catalog_item_id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (household_id, barcode)
);

CREATE INDEX idx_household_barcode_labels_household ON household_barcode_labels (household_id);

CREATE TRIGGER set_updated_at_household_barcode_labels
    BEFORE UPDATE ON household_barcode_labels FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE household_barcode_labels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read household barcode labels"
    ON household_barcode_labels FOR SELECT USING (household_id = get_my_household_id());

CREATE POLICY "Members can insert household barcode labels"
    ON household_barcode_labels FOR INSERT WITH CHECK (household_id = get_my_household_id());

CREATE POLICY "Members can update household barcode labels"
    ON household_barcode_labels FOR UPDATE USING (household_id = get_my_household_id());

CREATE POLICY "Members can delete household barcode labels"
    ON household_barcode_labels FOR DELETE USING (household_id = get_my_household_id());
