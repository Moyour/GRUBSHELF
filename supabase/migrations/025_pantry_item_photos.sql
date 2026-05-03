-- Pantry item photos: metadata column + storage bucket/policies.

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
