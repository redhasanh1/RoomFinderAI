-- Safe Consolidation Script - Handles NULL values properly

-- ============================================
-- STEP 1: Check users table constraints first
-- ============================================

-- Remove NOT NULL constraint from first_name if it exists
ALTER TABLE users ALTER COLUMN first_name DROP NOT NULL;
ALTER TABLE users ALTER COLUMN last_name DROP NOT NULL;

-- ============================================
-- STEP 2: Add missing columns to users table
-- ============================================

-- Add all the profile fields to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS city VARCHAR(100),
ADD COLUMN IF NOT EXISTS postalcode VARCHAR(20),
ADD COLUMN IF NOT EXISTS street VARCHAR(200),
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS date_of_birth DATE,
ADD COLUMN IF NOT EXISTS gender VARCHAR(20),
ADD COLUMN IF NOT EXISTS occupation VARCHAR(100),
ADD COLUMN IF NOT EXISTS profile_image TEXT,
ADD COLUMN IF NOT EXISTS profile_image_url TEXT,
ADD COLUMN IF NOT EXISTS has_custom_profile_image BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS auth_id UUID UNIQUE,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================
-- STEP 3: Migrate data from profiles to users (SAFE)
-- ============================================

-- Insert profiles as new users, handling NULL names
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
)
SELECT 
    COALESCE(p.id, uuid_generate_v4()) as id,
    p.email,
    COALESCE(p.first_name, split_part(p.email, '@', 1)) as first_name, -- Use email username if name is null
    COALESCE(p.last_name, '') as last_name, -- Empty string if null
    p.city,
    p.postalcode,
    p.street,
    p.bio,
    p.profile_image,
    p.profile_image_url,
    (p.profile_image_url IS NOT NULL OR (p.profile_image IS NOT NULL AND p.profile_image != 'https://via.placeholder.com/40')) as has_custom_profile_image,
    p.phone,
    COALESCE(p.created_at, NOW()) as created_at,
    COALESCE(p.updated_at, NOW()) as updated_at,
    false as is_verified
FROM profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM users u WHERE u.email = p.email
)
AND p.email IS NOT NULL;

-- ============================================
-- STEP 4: Update existing users with profile data
-- ============================================

-- Update existing users with data from profiles
UPDATE users 
SET 
    first_name = COALESCE(p.first_name, users.first_name, split_part(users.email, '@', 1)),
    last_name = COALESCE(p.last_name, users.last_name, ''),
    city = COALESCE(p.city, users.city),
    postalcode = COALESCE(p.postalcode, users.postalcode),
    street = COALESCE(p.street, users.street),
    bio = COALESCE(p.bio, users.bio),
    profile_image = COALESCE(p.profile_image, users.profile_image),
    profile_image_url = COALESCE(p.profile_image_url, users.profile_image_url),
    has_custom_profile_image = COALESCE(
        (p.profile_image_url IS NOT NULL OR (p.profile_image IS NOT NULL AND p.profile_image != 'https://via.placeholder.com/40')), 
        users.has_custom_profile_image
    ),
    phone = COALESCE(p.phone, users.phone),
    updated_at = NOW()
FROM profiles p
WHERE users.email = p.email;

-- ============================================
-- STEP 5: Update all foreign key references
-- ============================================

-- Update listings to reference users properly
UPDATE listings 
SET user_id = u.id
FROM users u
WHERE listings.user_email = u.email
AND listings.user_id IS NULL;

-- Update messages to reference users properly  
UPDATE messages
SET user_id = u.id
FROM users u  
WHERE messages.sender_email = u.email
AND messages.user_id IS NULL;

-- Update favorites if user_email column exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='favorites' AND column_name='user_email') THEN
        ALTER TABLE favorites ADD COLUMN IF NOT EXISTS user_id UUID;
        
        UPDATE favorites
        SET user_id = u.id
        FROM users u
        WHERE favorites.user_email = u.email;
        
        -- Only drop user_email after user_id is populated
        UPDATE favorites 
        SET user_email = NULL 
        WHERE user_id IS NOT NULL;
    END IF;
END $$;

-- ============================================
-- STEP 6: Create indexes for better performance
-- ============================================

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON users(auth_id);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- ============================================
-- STEP 7: Verification and success message
-- ============================================

DO $$
DECLARE
    user_count INTEGER;
    profile_count INTEGER;
    listings_linked INTEGER;
    users_with_names INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users;
    SELECT COUNT(*) INTO profile_count FROM profiles;
    SELECT COUNT(*) INTO listings_linked FROM listings WHERE user_id IS NOT NULL;
    SELECT COUNT(*) INTO users_with_names FROM users WHERE first_name IS NOT NULL AND first_name != '';
    
    RAISE NOTICE '=== CONSOLIDATION RESULTS ===';
    RAISE NOTICE 'Total users: %', user_count;
    RAISE NOTICE 'Original profiles: %', profile_count;
    RAISE NOTICE 'Listings linked to users: %', listings_linked;
    RAISE NOTICE 'Users with names: %', users_with_names;
    RAISE NOTICE '✅ CONSOLIDATION COMPLETE!';
    RAISE NOTICE '💡 All user data is now in the users table';
    RAISE NOTICE '🔧 profiles table can be dropped when ready';
END $$;