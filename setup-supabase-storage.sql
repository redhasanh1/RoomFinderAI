-- Supabase Storage Setup Script
-- Run this in your Supabase SQL editor to set up storage buckets

-- ============================================
-- Create Storage Buckets
-- ============================================

-- Create bucket for profile images
INSERT INTO storage.buckets (id, name, public, avif_autodetection, file_size_limit, allowed_mime_types)
VALUES (
    'profile-images',
    'profile-images', 
    true,  -- Public bucket for profile images
    false,
    5242880,  -- 5MB limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];

-- Create bucket for listing images
INSERT INTO storage.buckets (id, name, public, avif_autodetection, file_size_limit, allowed_mime_types)
VALUES (
    'listing-images',
    'listing-images',
    true,  -- Public bucket for listing images
    false,
    10485760,  -- 10MB limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];

-- Create bucket for chat attachments
INSERT INTO storage.buckets (id, name, public, avif_autodetection, file_size_limit, allowed_mime_types)
VALUES (
    'chat-attachments',
    'chat-attachments',
    false,  -- Private bucket for chat files
    false,
    10485760,  -- 10MB limit
    ARRAY[
        'image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif',
        'application/pdf', 
        'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain'
    ]
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY[
        'image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif',
        'application/pdf', 
        'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain'
    ];

-- Create bucket for verification documents
INSERT INTO storage.buckets (id, name, public, avif_autodetection, file_size_limit, allowed_mime_types)
VALUES (
    'verification-docs',
    'verification-docs',
    false,  -- Private bucket for sensitive documents
    false,
    20971520,  -- 20MB limit
    ARRAY[
        'image/jpeg', 'image/jpg', 'image/png',
        'application/pdf'
    ]
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 20971520,
    allowed_mime_types = ARRAY[
        'image/jpeg', 'image/jpg', 'image/png',
        'application/pdf'
    ];

-- ============================================
-- Storage Policies
-- ============================================

-- Profile Images Policies
CREATE POLICY "Users can upload their own profile image"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'profile-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update their own profile image"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'profile-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own profile image"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'profile-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Profile images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-images');

-- Listing Images Policies
CREATE POLICY "Authenticated users can upload listing images"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'listing-images' AND
    auth.uid() IS NOT NULL
);

CREATE POLICY "Users can update their own listing images"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'listing-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own listing images"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'listing-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Listing images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'listing-images');

-- Chat Attachments Policies
CREATE POLICY "Users can upload chat attachments"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'chat-attachments' AND
    auth.uid() IS NOT NULL
);

CREATE POLICY "Users can view chat attachments in their conversations"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'chat-attachments' AND
    auth.uid() IN (
        SELECT participant1_id FROM conversations WHERE id::text = (storage.foldername(name))[1]
        UNION
        SELECT participant2_id FROM conversations WHERE id::text = (storage.foldername(name))[1]
    )
);

-- Verification Documents Policies  
CREATE POLICY "Users can upload their verification documents"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'verification-docs' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can view their own verification documents"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'verification-docs' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own verification documents"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'verification-docs' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- ============================================
-- Helper Functions for Storage
-- ============================================

-- Function to get storage URL for a file
CREATE OR REPLACE FUNCTION get_storage_url(bucket_name TEXT, file_path TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN 'https://fkktwhjybuflxqzopaex.supabase.co/storage/v1/object/public/' || bucket_name || '/' || file_path;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up old profile images when updating
CREATE OR REPLACE FUNCTION cleanup_old_profile_image()
RETURNS TRIGGER AS $$
BEGIN
    -- If profile image URL changed, delete the old one from storage
    IF OLD.profile_image_url IS DISTINCT FROM NEW.profile_image_url 
       AND OLD.profile_image_url LIKE '%supabase.co/storage/%' THEN
        -- Extract the file path from URL and delete
        -- This is a placeholder - actual implementation would need to call storage API
        RAISE NOTICE 'Old profile image should be deleted: %', OLD.profile_image_url;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cleanup_profile_image_on_update
BEFORE UPDATE OF profile_image_url ON profiles
FOR EACH ROW
EXECUTE FUNCTION cleanup_old_profile_image();

-- ============================================
-- Migration helper to move base64 images to storage
-- ============================================

-- This function helps identify profiles with base64 images that need migration
CREATE OR REPLACE FUNCTION identify_base64_images()
RETURNS TABLE(
    profile_id UUID,
    email TEXT,
    image_size_estimate INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.email,
        LENGTH(p.profile_image)::INTEGER as image_size_estimate
    FROM profiles p
    WHERE p.profile_image LIKE 'data:image%'
    ORDER BY LENGTH(p.profile_image) DESC;
END;
$$ LANGUAGE plpgsql;

-- View to monitor storage usage
CREATE OR REPLACE VIEW storage_usage AS
SELECT 
    bucket_id,
    COUNT(*) as file_count,
    SUM(metadata->>'size')::BIGINT as total_size_bytes,
    ROUND((SUM(metadata->>'size')::BIGINT / 1024.0 / 1024.0)::NUMERIC, 2) as total_size_mb
FROM storage.objects
GROUP BY bucket_id;

COMMENT ON VIEW storage_usage IS 'Monitor storage usage across all buckets';