-- Consolidate Users - Move all profile data to users table
-- This will make users table the single source of truth

-- ============================================
-- STEP 1: Add missing columns to users table
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
-- STEP 2: Migrate data from profiles to users
-- ============================================

-- First, create users from profiles data
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
    p.first_name,
    p.last_name,
    p.city,
    p.postalcode,
    p.street,
    p.bio,
    p.profile_image,
    p.profile_image_url,
    (p.profile_image_url IS NOT NULL OR (p.profile_image IS NOT NULL AND p.profile_image != 'https://via.placeholder.com/40')) as has_custom_profile_image,
    p.phone,
    p.created_at,
    p.updated_at,
    false as is_verified  -- Default to false, can be updated later
FROM profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM users u WHERE u.email = p.email
);

-- ============================================
-- STEP 3: Update existing users with profile data
-- ============================================

-- Update existing users with data from profiles
UPDATE users 
SET 
    first_name = COALESCE(p.first_name, users.first_name),
    last_name = COALESCE(p.last_name, users.last_name),
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
    updated_at = COALESCE(p.updated_at, users.updated_at)
FROM profiles p
WHERE users.email = p.email;

-- ============================================
-- STEP 4: Update all foreign key references
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

-- Update favorites to use user_id instead of user_email
ALTER TABLE favorites 
ADD COLUMN IF NOT EXISTS user_id UUID;

UPDATE favorites
SET user_id = u.id
FROM users u
WHERE favorites.user_email = u.email;

-- Update other tables similarly (only if columns exist)
UPDATE bookings
SET user_id = u.id
FROM users u
WHERE bookings.user_email = u.email
AND bookings.user_id IS NULL;

UPDATE bookings
SET landlord_id = ul.id
FROM users ul
WHERE bookings.landlord_email = ul.email
AND bookings.landlord_id IS NULL;

UPDATE reviews
SET user_id = u.id  
FROM users u
WHERE reviews.user_email = u.email
AND reviews.user_id IS NULL;

UPDATE notifications
SET user_id = u.id
FROM users u
WHERE notifications.user_email = u.email
AND notifications.user_id IS NULL;

UPDATE search_history
SET user_id = u.id
FROM users u
WHERE search_history.user_email = u.email
AND search_history.user_id IS NULL;

UPDATE user_preferences
SET user_id = u.id
FROM users u
WHERE user_preferences.user_email = u.email
AND user_preferences.user_id IS NULL;

UPDATE listing_views
SET user_id = u.id
FROM users u
WHERE listing_views.user_email = u.email
AND listing_views.user_id IS NULL;

-- ============================================
-- STEP 5: Create indexes
-- ============================================

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON users(auth_id);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- ============================================
-- STEP 6: Update triggers for updated_at
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at 
BEFORE UPDATE ON users
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- STEP 7: Data verification and completion message
-- ============================================

DO $$
DECLARE
    user_count INTEGER;
    profile_count INTEGER;
    listings_linked INTEGER;
    favorites_linked INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users;
    SELECT COUNT(*) INTO profile_count FROM profiles;
    SELECT COUNT(*) INTO listings_linked FROM listings WHERE user_id IS NOT NULL;
    SELECT COUNT(*) INTO favorites_linked FROM favorites WHERE user_id IS NOT NULL;
    
    RAISE NOTICE '=== CONSOLIDATION RESULTS ===';
    RAISE NOTICE 'Total users: %', user_count;
    RAISE NOTICE 'Original profiles: %', profile_count;
    RAISE NOTICE 'Listings linked to users: %', listings_linked;
    RAISE NOTICE 'Favorites linked to users: %', favorites_linked;
    RAISE NOTICE '✅ Users table consolidation complete!';
    RAISE NOTICE '⚠️  Test everything before dropping profiles table';
    RAISE NOTICE '💡 All user data is now in the users table';
END $$;