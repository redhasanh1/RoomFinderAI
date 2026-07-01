-- SIMPLE DATABASE FIX FOR ROOMFINDERAI
-- This version just adds the missing tables without complex policies
-- Run this FIRST to add all missing tables

-- ============================================
-- PART 1: Enable Extensions
-- ============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- PART 2: Create Missing Tables (Simple Version)
-- ============================================

-- 1. Favorites table
CREATE TABLE IF NOT EXISTS favorites (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    listing_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_email, listing_id)
);

-- 2. Bookings table
CREATE TABLE IF NOT EXISTS bookings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id VARCHAR(255) NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    landlord_email VARCHAR(255) NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    payment_status VARCHAR(20) DEFAULT 'unpaid',
    guest_count INTEGER DEFAULT 1,
    special_requests TEXT,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Reviews table
CREATE TABLE IF NOT EXISTS reviews (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id VARCHAR(255) NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(200),
    comment TEXT,
    is_verified_booking BOOLEAN DEFAULT FALSE,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Amenities table
CREATE TABLE IF NOT EXISTS amenities (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50),
    icon VARCHAR(50),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Listing amenities junction table
CREATE TABLE IF NOT EXISTS listing_amenities (
    listing_id VARCHAR(255) NOT NULL,
    amenity_id UUID NOT NULL,
    PRIMARY KEY (listing_id, amenity_id)
);

-- 6. Payments table
CREATE TABLE IF NOT EXISTS payments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    booking_id UUID NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_method VARCHAR(50),
    stripe_payment_id VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Search history table
CREATE TABLE IF NOT EXISTS search_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email VARCHAR(255),
    search_query TEXT,
    filters JSONB,
    results_count INTEGER,
    session_id VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. User preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL UNIQUE,
    preferred_currency VARCHAR(3) DEFAULT 'USD',
    preferred_language VARCHAR(10) DEFAULT 'en',
    email_notifications BOOLEAN DEFAULT TRUE,
    push_notifications BOOLEAN DEFAULT TRUE,
    sms_notifications BOOLEAN DEFAULT FALSE,
    newsletter_subscription BOOLEAN DEFAULT TRUE,
    search_radius INTEGER DEFAULT 10,
    min_price DECIMAL(10, 2),
    max_price DECIMAL(10, 2),
    preferred_bedrooms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Listing views table
CREATE TABLE IF NOT EXISTS listing_views (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id VARCHAR(255) NOT NULL,
    user_email VARCHAR(255),
    session_id VARCHAR(100),
    viewed_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Simple conversations table
CREATE TABLE IF NOT EXISTS conversations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id VARCHAR(255),
    participant1_email VARCHAR(255) NOT NULL,
    participant2_email VARCHAR(255) NOT NULL,
    last_message_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- PART 3: Add Missing Columns to Existing Tables
-- ============================================

-- Add columns to profiles table (safe - won't error if exists)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS profile_image_url TEXT,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Remove password column from profiles (SECURITY FIX)
ALTER TABLE profiles DROP COLUMN IF EXISTS password;

-- Add columns to listings table
ALTER TABLE listings
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active',
ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS available_from DATE,
ADD COLUMN IF NOT EXISTS furnished BOOLEAN DEFAULT FALSE;

-- Add columns to messages table
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- ============================================
-- PART 4: Insert Default Amenities
-- ============================================
INSERT INTO amenities (name, category, icon, description) VALUES
('WiFi', 'Essential', 'wifi', 'High-speed internet connection'),
('Parking', 'Essential', 'car', 'Dedicated parking space'),
('Air Conditioning', 'Essential', 'snowflake', 'Central or room AC'),
('Heating', 'Essential', 'fire', 'Central heating system'),
('Washer', 'Appliances', 'washer', 'In-unit washing machine'),
('Dryer', 'Appliances', 'dryer', 'In-unit dryer'),
('Dishwasher', 'Appliances', 'dishwasher', 'Dishwasher available'),
('Gym', 'Building', 'dumbbell', 'Access to gym facilities'),
('Pool', 'Building', 'pool', 'Swimming pool access'),
('Pet Friendly', 'Policies', 'paw', 'Pets allowed'),
('Elevator', 'Building', 'elevator', 'Building has elevator'),
('Security', 'Safety', 'shield', '24/7 security service'),
('Balcony', 'Features', 'balcony', 'Private balcony'),
('Garden', 'Features', 'tree', 'Access to garden'),
('Storage', 'Features', 'box', 'Additional storage space')
ON CONFLICT (name) DO NOTHING;

-- ============================================
-- PART 5: Create Basic Indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_email);
CREATE INDEX IF NOT EXISTS idx_favorites_listing ON favorites(listing_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user ON bookings(user_email);
CREATE INDEX IF NOT EXISTS idx_bookings_listing ON bookings(listing_id);
CREATE INDEX IF NOT EXISTS idx_reviews_listing ON reviews(listing_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_email);
CREATE INDEX IF NOT EXISTS idx_listing_views_listing ON listing_views(listing_id);

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '✅ SUCCESS! All missing tables have been created.';
    RAISE NOTICE 'Your database now has: favorites, bookings, reviews, payments, notifications, and more!';
    RAISE NOTICE 'Password field has been removed from profiles table for security.';
END $$;