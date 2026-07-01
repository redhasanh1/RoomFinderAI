-- Supabase Storage Setup (idempotent — safe to re-run)
-- Run entire file in Supabase SQL Editor as ONE query.

-- ============================================
-- Buckets (names must match frontend/backend code)
-- ============================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'profile-images', 'profile-images', true, 5242880,
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Listing uploads use bucket listing-media/Photos in listings.html
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'listing-media', 'listing-media', true, 10485760,
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'chat-attachments', 'chat-attachments', false, 10485760,
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'application/pdf', 'text/plain']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'verification-docs', 'verification-docs', false, 20971520,
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ============================================
-- Policies (drop + recreate for idempotency)
-- ============================================

-- Profile images
DROP POLICY IF EXISTS "Users can upload their own profile image" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own profile image" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile image" ON storage.objects;
DROP POLICY IF EXISTS "Profile images are publicly accessible" ON storage.objects;

CREATE POLICY "Users can upload their own profile image" ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'profile-images' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users can update their own profile image" ON storage.objects FOR UPDATE
USING (bucket_id = 'profile-images' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users can delete their own profile image" ON storage.objects FOR DELETE
USING (bucket_id = 'profile-images' AND auth.uid() IS NOT NULL);

CREATE POLICY "Profile images are publicly accessible" ON storage.objects FOR SELECT
USING (bucket_id = 'profile-images');

-- Listing media (listing-media bucket)
DROP POLICY IF EXISTS "Authenticated users can upload listing media" ON storage.objects;
DROP POLICY IF EXISTS "Users can update listing media" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete listing media" ON storage.objects;
DROP POLICY IF EXISTS "Listing media is publicly accessible" ON storage.objects;

CREATE POLICY "Authenticated users can upload listing media" ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'listing-media' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users can update listing media" ON storage.objects FOR UPDATE
USING (bucket_id = 'listing-media' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users can delete listing media" ON storage.objects FOR DELETE
USING (bucket_id = 'listing-media' AND auth.uid() IS NOT NULL);

CREATE POLICY "Listing media is publicly accessible" ON storage.objects FOR SELECT
USING (bucket_id = 'listing-media');

-- Chat attachments (simple policy — no conversations table required)
DROP POLICY IF EXISTS "Users can upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own chat attachments" ON storage.objects;

CREATE POLICY "Users can upload chat attachments" ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'chat-attachments' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users can view own chat attachments" ON storage.objects FOR SELECT
USING (bucket_id = 'chat-attachments' AND auth.uid() IS NOT NULL);

-- Verification documents
DROP POLICY IF EXISTS "Users can upload their verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own verification documents" ON storage.objects;

CREATE POLICY "Users can upload their verification documents" ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'verification-docs' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users can view their own verification documents" ON storage.objects FOR SELECT
USING (bucket_id = 'verification-docs' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users can delete their own verification documents" ON storage.objects FOR DELETE
USING (bucket_id = 'verification-docs' AND auth.uid() IS NOT NULL);

-- ============================================
-- Optional: storage usage view
-- ============================================

CREATE OR REPLACE VIEW storage_usage AS
SELECT
    bucket_id,
    COUNT(*) AS file_count,
    COALESCE(SUM((metadata->>'size')::BIGINT), 0) AS total_size_bytes,
    ROUND(COALESCE(SUM((metadata->>'size')::BIGINT), 0) / 1024.0 / 1024.0, 2) AS total_size_mb
FROM storage.objects
GROUP BY bucket_id;

COMMENT ON VIEW storage_usage IS 'Monitor storage usage across all buckets';
