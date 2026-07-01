-- Simple Storage Bucket Creation
-- Run this to set up image storage

-- Create bucket for profile images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'profile-images',
    'profile-images', 
    true,  -- Public bucket
    5242880,  -- 5MB limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Create bucket for listing media (matches listings.html upload path listing-media/Photos)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'listing-media',
    'listing-media',
    true,  -- Public bucket
    10485760,  -- 10MB limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Create bucket for chat files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'chat-files',
    'chat-files',
    false,  -- Private bucket
    10485760,  -- 10MB limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'application/pdf', 'text/plain']
)
ON CONFLICT (id) DO NOTHING;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Storage buckets created successfully!';
END $$;