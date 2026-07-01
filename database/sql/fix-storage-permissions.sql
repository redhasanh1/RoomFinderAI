-- Fix Storage Permissions for Profile Images
-- Run this in Supabase SQL Editor to allow uploads

-- ============================================
-- OPTION 1: Allow service role to bypass RLS
-- ============================================

-- Create policy that allows service role to upload
CREATE POLICY "Allow service role uploads" ON storage.objects
FOR INSERT 
TO service_role
WITH CHECK (bucket_id = 'profile-images');

-- Allow service role to read
CREATE POLICY "Allow service role reads" ON storage.objects
FOR SELECT 
TO service_role
USING (bucket_id = 'profile-images');

-- Allow service role to update
CREATE POLICY "Allow service role updates" ON storage.objects
FOR UPDATE 
TO service_role
USING (bucket_id = 'profile-images');

-- ============================================
-- OPTION 2: Alternative - Allow all uploads to profile-images
-- ============================================

-- If above doesn't work, try this more permissive policy
CREATE POLICY "Allow all profile image uploads" ON storage.objects
FOR INSERT 
WITH CHECK (bucket_id = 'profile-images');

CREATE POLICY "Allow all profile image reads" ON storage.objects
FOR SELECT 
USING (bucket_id = 'profile-images');

-- ============================================
-- Check current policies
-- ============================================
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Storage policies updated for profile-images bucket';
    RAISE NOTICE 'Service role should now be able to upload files';
END $$;