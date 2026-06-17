-- Hotfix: re-add pantry_items columns that drifted out of the live schema.
--
-- Migrations 023 (storage_location) and 025 (photo_path) are recorded in
-- supabase_migrations.schema_migrations on the remote project, but the
-- columns themselves are missing — the table was likely recreated after
-- those migrations ran. The iOS client sends both fields on every insert,
-- so writes from members fail with PGRST204 ("Could not find the
-- 'storage_location' column of 'pantry_items' in the schema cache").
--
-- All operations here are idempotent: ADD COLUMN IF NOT EXISTS, ON CONFLICT
-- DO NOTHING, DROP POLICY IF EXISTS, CREATE POLICY. Safe to re-run.

ALTER TABLE pantry_items
    ADD COLUMN IF NOT EXISTS storage_location TEXT NOT NULL DEFAULT 'shelf';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'pantry_items_storage_location_check'
    ) THEN
        ALTER TABLE pantry_items
            ADD CONSTRAINT pantry_items_storage_location_check
            CHECK (storage_location IN ('fridge', 'shelf'));
    END IF;
END$$;

COMMENT ON COLUMN pantry_items.storage_location IS 'Where the item is stored: fridge or shelf';

ALTER TABLE pantry_items
    ADD COLUMN IF NOT EXISTS photo_path TEXT;

COMMENT ON COLUMN pantry_items.photo_path IS 'Supabase Storage object path for pantry item photo (bucket pantry-item-photos).';

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'pantry-item-photos',
    'pantry-item-photos',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Members can read pantry item photos" ON storage.objects;
CREATE POLICY "Members can read pantry item photos"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'pantry-item-photos'
        AND (storage.foldername(name))[1] = get_my_household_id()::text
    );

DROP POLICY IF EXISTS "Members can upload pantry item photos" ON storage.objects;
CREATE POLICY "Members can upload pantry item photos"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'pantry-item-photos'
        AND (storage.foldername(name))[1] = get_my_household_id()::text
    );

DROP POLICY IF EXISTS "Members can update pantry item photos" ON storage.objects;
CREATE POLICY "Members can update pantry item photos"
    ON storage.objects FOR UPDATE TO authenticated
    USING (
        bucket_id = 'pantry-item-photos'
        AND (storage.foldername(name))[1] = get_my_household_id()::text
    )
    WITH CHECK (
        bucket_id = 'pantry-item-photos'
        AND (storage.foldername(name))[1] = get_my_household_id()::text
    );

DROP POLICY IF EXISTS "Members can delete pantry item photos" ON storage.objects;
CREATE POLICY "Members can delete pantry item photos"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'pantry-item-photos'
        AND (storage.foldername(name))[1] = get_my_household_id()::text
    );

NOTIFY pgrst, 'reload schema';
