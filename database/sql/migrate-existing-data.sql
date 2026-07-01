-- Data Migration Script for RoomFinderAI
-- Run this AFTER running supabase-migrations.sql
-- This script migrates existing data to the new structure

-- ============================================
-- STEP 1: Migrate users from profiles to users table
-- ============================================

-- First, ensure all profile emails exist in users table
INSERT INTO users (id, email, first_name, last_name, created_at, is_verified)
SELECT 
    uuid_generate_v4() as id,
    p.email,
    COALESCE(p.first_name, split_part(p.email, '@', 1)) as first_name,
    COALESCE(p.last_name, '') as last_name,
    p.created_at,
    false as is_verified
FROM profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM users u WHERE u.email = p.email
)
AND p.email IS NOT NULL;

-- ============================================
-- STEP 2: Link profiles to users
-- ============================================

-- Update profiles with user_id foreign key
UPDATE profiles p
SET user_id = u.id
FROM users u
WHERE p.email = u.email
AND p.user_id IS NULL;

-- ============================================
-- STEP 3: Fix listings ownership
-- ============================================

-- Link listings to users based on user_email
UPDATE listings l
SET user_id = u.id
FROM users u
WHERE l.user_email = u.email
AND l.user_id IS NULL;

-- For listings without valid user_email, assign to a default landlord account
-- First create a default landlord if needed
INSERT INTO users (id, email, first_name, last_name, created_at, is_verified)
SELECT 
    uuid_generate_v4(),
    'default-landlord@roomfinderai.com',
    'Default',
    'Landlord',
    NOW(),
    true
WHERE NOT EXISTS (
    SELECT 1 FROM users WHERE email = 'default-landlord@roomfinderai.com'
);

-- Assign orphaned listings to default landlord
UPDATE listings
SET user_id = (SELECT id FROM users WHERE email = 'default-landlord@roomfinderai.com')
WHERE user_id IS NULL;

-- ============================================
-- STEP 4: Migrate profile images to new structure
-- ============================================

-- Update profile image URLs (remove base64 data URIs)
UPDATE profiles
SET profile_image_url = CASE 
    WHEN profile_image LIKE 'data:image%' THEN NULL  -- Will need to re-upload
    WHEN profile_image LIKE 'http%' THEN profile_image
    ELSE profile_image
END
WHERE profile_image IS NOT NULL 
AND profile_image != 'https://via.placeholder.com/40';

-- ============================================
-- STEP 5: Link messages to users
-- ============================================

-- Update messages with user_id based on sender_email
UPDATE messages m
SET user_id = u.id
FROM users u
WHERE m.sender_email = u.email
AND m.user_id IS NULL;

-- ============================================
-- STEP 6: Create conversations for existing messages
-- ============================================

-- Create conversations from existing message threads
INSERT INTO conversations (
    id,
    listing_id,
    participant1_id,
    participant2_id,
    last_message_at,
    created_at
)
SELECT DISTINCT ON (m.conversation_id)
    COALESCE(m.conversation_id::uuid, uuid_generate_v4()) as id,
    NULL as listing_id,  -- Will need to infer from context
    u1.id as participant1_id,
    u2.id as participant2_id,
    MAX(m.created_at) OVER (PARTITION BY m.conversation_id) as last_message_at,
    MIN(m.created_at) OVER (PARTITION BY m.conversation_id) as created_at
FROM messages m
JOIN users u1 ON u1.email = (
    SELECT DISTINCT sender_email 
    FROM messages 
    WHERE conversation_id = m.conversation_id 
    ORDER BY created_at 
    LIMIT 1
)
JOIN users u2 ON u2.email = (
    SELECT DISTINCT sender_email 
    FROM messages 
    WHERE conversation_id = m.conversation_id 
    AND sender_email != u1.email
    LIMIT 1
)
WHERE m.conversation_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- ============================================
-- STEP 7: Clean up data quality issues
-- ============================================

-- Set default values for required fields
UPDATE listings
SET 
    status = COALESCE(status, 'active'),
    views = COALESCE(views, 0),
    country = COALESCE(country, 'US'),
    created_at = COALESCE(created_at, NOW()),
    updated_at = COALESCE(updated_at, NOW())
WHERE status IS NULL OR views IS NULL;

-- Standardize city names (capitalize first letter)
UPDATE listings
SET city = INITCAP(LOWER(city))
WHERE city IS NOT NULL;

-- Standardize postal codes (remove spaces)
UPDATE listings
SET "postalCode" = REPLACE("postalCode", ' ', '')
WHERE "postalCode" IS NOT NULL;

-- ============================================
-- STEP 8: Create initial user preferences
-- ============================================

-- Create default preferences for all users
INSERT INTO user_preferences (user_id)
SELECT id FROM users
WHERE NOT EXISTS (
    SELECT 1 FROM user_preferences WHERE user_id = users.id
);

-- ============================================
-- STEP 9: Data validation report
-- ============================================

-- Run this to see the migration results
DO $$
DECLARE
    user_count INTEGER;
    profile_count INTEGER;
    listing_count INTEGER;
    orphaned_listings INTEGER;
    message_count INTEGER;
    conversation_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users;
    SELECT COUNT(*) INTO profile_count FROM profiles WHERE user_id IS NOT NULL;
    SELECT COUNT(*) INTO listing_count FROM listings WHERE user_id IS NOT NULL;
    SELECT COUNT(*) INTO orphaned_listings FROM listings WHERE user_email IS NULL;
    SELECT COUNT(*) INTO message_count FROM messages WHERE user_id IS NOT NULL;
    SELECT COUNT(*) INTO conversation_count FROM conversations;
    
    RAISE NOTICE '=== Migration Report ===';
    RAISE NOTICE 'Users: %', user_count;
    RAISE NOTICE 'Profiles linked: %', profile_count;
    RAISE NOTICE 'Listings linked: %', listing_count;
    RAISE NOTICE 'Orphaned listings fixed: %', orphaned_listings;
    RAISE NOTICE 'Messages linked: %', message_count;
    RAISE NOTICE 'Conversations created: %', conversation_count;
END $$;