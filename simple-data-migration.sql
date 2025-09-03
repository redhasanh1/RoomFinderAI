-- Simple Data Migration - Just add columns and update existing data

-- ============================================
-- STEP 1: Add missing columns to users table (no foreign keys)
-- ============================================

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS city VARCHAR(100),
ADD COLUMN IF NOT EXISTS postalcode VARCHAR(20),
ADD COLUMN IF NOT EXISTS street VARCHAR(200),
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS profile_image TEXT,
ADD COLUMN IF NOT EXISTS profile_image_url TEXT,
ADD COLUMN IF NOT EXISTS has_custom_profile_image BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Remove NOT NULL constraints that might be causing issues
ALTER TABLE users ALTER COLUMN first_name DROP NOT NULL;
ALTER TABLE users ALTER COLUMN last_name DROP NOT NULL;

-- ============================================
-- STEP 2: Just update existing users with profile data (safer approach)
-- ============================================

-- Update the existing user with data from profiles
UPDATE users 
SET 
    first_name = COALESCE(p.first_name, users.first_name, split_part(users.email, '@', 1)),
    last_name = COALESCE(p.last_name, users.last_name, ''),
    city = p.city,
    postalcode = p.postalcode,
    street = p.street,
    bio = p.bio,
    profile_image = p.profile_image,
    profile_image_url = p.profile_image_url,
    has_custom_profile_image = (p.profile_image_url IS NOT NULL OR (p.profile_image IS NOT NULL AND p.profile_image != 'https://via.placeholder.com/40')),
    phone = p.phone,
    updated_at = NOW()
FROM profiles p
WHERE users.email = p.email;

-- ============================================
-- STEP 3: Create missing users from profiles (one by one to avoid constraints)
-- ============================================

-- Get list of emails in profiles but not in users
DO $$
DECLARE
    profile_record RECORD;
BEGIN
    FOR profile_record IN 
        SELECT * FROM profiles p 
        WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = p.email)
        AND p.email IS NOT NULL
    LOOP
        BEGIN
            INSERT INTO users (
                id,
                email,
                first_name,
                last_name,
                city,
                postalcode,
                street,
                bio,
                profile_image,
                profile_image_url,
                has_custom_profile_image,
                phone,
                created_at,
                updated_at,
                is_verified
            ) VALUES (
                COALESCE(profile_record.id, uuid_generate_v4()),
                profile_record.email,
                COALESCE(profile_record.first_name, split_part(profile_record.email, '@', 1)),
                COALESCE(profile_record.last_name, ''),
                profile_record.city,
                profile_record.postalcode,
                profile_record.street,
                profile_record.bio,
                profile_record.profile_image,
                profile_record.profile_image_url,
                (profile_record.profile_image_url IS NOT NULL OR (profile_record.profile_image IS NOT NULL AND profile_record.profile_image != 'https://via.placeholder.com/40')),
                profile_record.phone,
                COALESCE(profile_record.created_at, NOW()),
                NOW(),
                false
            );
            
            RAISE NOTICE 'Created user: %', profile_record.email;
        EXCEPTION 
            WHEN OTHERS THEN
                RAISE NOTICE 'Skipped user % due to constraint: %', profile_record.email, SQLERRM;
        END;
    END LOOP;
END $$;

-- ============================================
-- STEP 4: Update foreign key references 
-- ============================================

-- Update listings
UPDATE listings 
SET user_id = u.id
FROM users u
WHERE listings.user_email = u.email
AND listings.user_id IS NULL;

-- Update messages
UPDATE messages
SET user_id = u.id
FROM users u  
WHERE messages.sender_email = u.email
AND messages.user_id IS NULL;

-- ============================================
-- STEP 5: Show results
-- ============================================

DO $$
DECLARE
    user_count INTEGER;
    profile_count INTEGER;
    listings_linked INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users;
    SELECT COUNT(*) INTO profile_count FROM profiles;
    SELECT COUNT(*) INTO listings_linked FROM listings WHERE user_id IS NOT NULL;
    
    RAISE NOTICE '=== MIGRATION RESULTS ===';
    RAISE NOTICE 'Total users: %', user_count;
    RAISE NOTICE 'Original profiles: %', profile_count;
    RAISE NOTICE 'Listings linked: %', listings_linked;
    RAISE NOTICE '✅ Migration complete!';
END $$;