-- Verify your listings exist in Supabase
-- Run this in Supabase SQL Editor to check your listings

-- 1. Show all listings for your email
SELECT id, title, price, city, user_email, created_at 
FROM listings 
WHERE user_email = 'bobwent1991@gmail.com'  -- Replace with your email
ORDER BY created_at DESC;

-- 2. Count total listings per user
SELECT user_email, COUNT(*) as listing_count 
FROM listings 
GROUP BY user_email 
ORDER BY listing_count DESC;

-- 3. Show most recent listings across all users
SELECT id, title, price, city, user_email, created_at 
FROM listings 
ORDER BY created_at DESC 
LIMIT 10;

-- 4. Check if RLS is disabled (should show 'false')
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'listings';

-- 5. If you need to manually insert a test listing
-- INSERT INTO listings (
--     id, title, price, city, street, "postalCode", 
--     "houseType", bedrooms, bathrooms, utilities, 
--     description, user_email, created_at
-- ) VALUES (
--     gen_random_uuid(),
--     'Test Listing',
--     1500,
--     'Toronto',
--     '123 Test Street',
--     'M5V 3A5',
--     'Apartment',
--     2,
--     1,
--     'Included',
--     'This is a test listing',
--     'bobwent1991@gmail.com',  -- Your email
--     NOW()
-- );