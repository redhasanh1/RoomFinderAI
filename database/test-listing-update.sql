-- Test script to verify listing updates work
-- Run this in Supabase SQL Editor to test if RLS is properly disabled

-- 1. Check if RLS is enabled on listings table
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'listings';

-- 2. List current RLS policies (should be empty if RLS is disabled)
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'listings';

-- 3. Check if bathrooms column exists
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'listings' 
AND column_name = 'bathrooms';

-- 4. Show first few listings with all columns
SELECT id, title, price, user_email, bathrooms, house_type, postal_code, created_at
FROM listings 
ORDER BY created_at DESC 
LIMIT 3;

-- 5. Test update (replace with actual values from your test listing)
-- UPDATE listings 
-- SET title = 'UPDATED TEST TITLE', bathrooms = 2.5, updated_at = NOW()
-- WHERE user_email = 'your-email@example.com' 
-- AND id = 'your-listing-id';

-- 6. Test if we can update any listing (this should work if RLS is disabled)
-- SELECT COUNT(*) as total_listings FROM listings;
-- If you see listings, RLS public read access is working

-- 7. Check for any constraints that might prevent updates
SELECT conname, contype, conkey, confkey, consrc
FROM pg_constraint 
WHERE conrelid = 'listings'::regclass
AND contype IN ('c', 'f', 'u'); -- check, foreign key, unique constraints