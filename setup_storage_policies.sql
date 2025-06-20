-- Supabase Storage Setup for Verification Documents
-- Run this AFTER creating the 'verification-documents' bucket in Supabase Dashboard

-- 1. Create storage policies for verification documents bucket
-- Allow authenticated users to upload their own verification documents

-- Policy to allow users to upload files (INSERT)
CREATE POLICY "Users can upload verification documents" 
ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'verification-documents' 
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.jwt() ->> 'email'
);

-- Policy to allow users to view their own files (SELECT)
CREATE POLICY "Users can view their own verification documents"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'verification-documents'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.jwt() ->> 'email'
);

-- Policy to allow users to update their own files (UPDATE)
CREATE POLICY "Users can update their own verification documents"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'verification-documents'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.jwt() ->> 'email'
);

-- Policy to allow users to delete their own files (DELETE)
CREATE POLICY "Users can delete their own verification documents"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'verification-documents'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.jwt() ->> 'email'
);

-- Admin policy to view all verification documents
CREATE POLICY "Admins can view all verification documents"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'verification-documents'
    AND auth.jwt() ->> 'role' = 'admin'
);