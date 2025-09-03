-- RoomFinderAI Database Migration Script (FIXED VERSION)
-- This version works with your existing database structure
-- Run this in your Supabase SQL editor

-- ============================================
-- STEP 1: Enable necessary extensions
-- ============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- STEP 2: Fix the users table FIRST
-- ============================================

-- First, add a proper UUID id column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'users' AND column_name = 'id' 
                   AND data_type = 'uuid') THEN
        -- Add temporary UUID column
        ALTER TABLE users ADD COLUMN new_id UUID DEFAULT uuid_generate_v4();
        
        -- If there's an existing id column that's not UUID, rename it
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'users' AND column_name = 'id') THEN
            ALTER TABLE users RENAME COLUMN id TO old_id;
        END IF;
        
        -- Rename new_id to id
        ALTER TABLE users RENAME COLUMN new_id TO id;
        
        -- Make it primary key
        ALTER TABLE users ADD PRIMARY KEY (id);
    END IF;
END $$;

-- Add other missing columns to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS auth_id UUID UNIQUE,
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS profile_image_url TEXT,
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================
-- STEP 3: Fix the profiles table
-- ============================================

-- Check if profiles table has a proper id column
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'id' 
                   AND data_type = 'uuid') THEN
        ALTER TABLE profiles ADD COLUMN id UUID DEFAULT uuid_generate_v4() PRIMARY KEY;
    END IF;
END $$;

-- Add user_id column to link profiles to users (will be populated later)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS user_id UUID,
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS profile_image_url TEXT,
ADD COLUMN IF NOT EXISTS date_of_birth DATE,
ADD COLUMN IF NOT EXISTS gender VARCHAR(20),
ADD COLUMN IF NOT EXISTS occupation VARCHAR(100),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Remove plaintext password field (CRITICAL SECURITY FIX)
ALTER TABLE profiles DROP COLUMN IF EXISTS password;

-- ============================================
-- STEP 4: Fix the listings table
-- ============================================

-- Check if listings has proper UUID id
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'listings' AND column_name = 'id' 
                   AND data_type = 'uuid') THEN
        -- Add new UUID column
        ALTER TABLE listings ADD COLUMN new_id UUID DEFAULT uuid_generate_v4();
        
        -- Copy data if there's an existing id
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'listings' AND column_name = 'id') THEN
            ALTER TABLE listings RENAME COLUMN id TO old_id;
        END IF;
        
        ALTER TABLE listings RENAME COLUMN new_id TO id;
        ALTER TABLE listings ADD PRIMARY KEY (id);
    END IF;
END $$;

-- Add missing columns to listings
ALTER TABLE listings
ADD COLUMN IF NOT EXISTS user_id UUID,
ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active',
ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS available_from DATE,
ADD COLUMN IF NOT EXISTS lease_duration VARCHAR(50),
ADD COLUMN IF NOT EXISTS pet_policy VARCHAR(100),
ADD COLUMN IF NOT EXISTS parking_spaces INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS furnished BOOLEAN DEFAULT FALSE;

-- ============================================
-- STEP 5: Now create the foreign key relationships
-- ============================================

-- Add foreign key for profiles to users (but don't enforce yet)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'profiles_user_id_fkey') THEN
        ALTER TABLE profiles 
        ADD CONSTRAINT profiles_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Could not add profiles foreign key - will be added after data migration';
END $$;

-- Add foreign key for listings to users (but don't enforce yet)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE constraint_name = 'listings_user_id_fkey') THEN
        ALTER TABLE listings 
        ADD CONSTRAINT listings_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Could not add listings foreign key - will be added after data migration';
END $$;

-- ============================================
-- STEP 6: Create missing tables (SIMPLIFIED)
-- ============================================

-- Favorites table for saved listings
CREATE TABLE IF NOT EXISTS favorites (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, listing_id)
);

-- Bookings/Reservations table
CREATE TABLE IF NOT EXISTS bookings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id UUID NOT NULL,
    user_id UUID NOT NULL,
    landlord_id UUID NOT NULL,
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

-- Reviews table
CREATE TABLE IF NOT EXISTS reviews (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id UUID NOT NULL,
    user_id UUID NOT NULL,
    booking_id UUID,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(200),
    comment TEXT,
    cleanliness_rating INTEGER CHECK (cleanliness_rating >= 1 AND cleanliness_rating <= 5),
    communication_rating INTEGER CHECK (communication_rating >= 1 AND communication_rating <= 5),
    location_rating INTEGER CHECK (location_rating >= 1 AND location_rating <= 5),
    value_rating INTEGER CHECK (value_rating >= 1 AND value_rating <= 5),
    is_verified_booking BOOLEAN DEFAULT FALSE,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Amenities table
CREATE TABLE IF NOT EXISTS amenities (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50),
    icon VARCHAR(50),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Listing amenities junction table
CREATE TABLE IF NOT EXISTS listing_amenities (
    listing_id UUID NOT NULL,
    amenity_id UUID NOT NULL,
    PRIMARY KEY (listing_id, amenity_id)
);

-- Payments table
CREATE TABLE IF NOT EXISTS payments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    booking_id UUID NOT NULL,
    user_id UUID NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_method VARCHAR(50),
    stripe_payment_id VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending',
    transaction_fee DECIMAL(10, 2),
    net_amount DECIMAL(10, 2),
    refund_amount DECIMAL(10, 2),
    refund_reason TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Search history table
CREATE TABLE IF NOT EXISTS search_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID,
    search_query TEXT,
    filters JSONB,
    results_count INTEGER,
    clicked_listings JSONB,
    session_id VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE,
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
    preferred_property_types JSONB,
    preferred_amenities JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Listing views tracking table
CREATE TABLE IF NOT EXISTS listing_views (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id UUID NOT NULL,
    user_id UUID,
    session_id VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    referrer TEXT,
    viewed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Conversation tracking for messages
CREATE TABLE IF NOT EXISTS conversations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id UUID,
    participant1_id UUID NOT NULL,
    participant2_id UUID NOT NULL,
    last_message_at TIMESTAMPTZ,
    participant1_unread_count INTEGER DEFAULT 0,
    participant2_unread_count INTEGER DEFAULT 0,
    is_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Update messages table to link with conversations
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS user_id UUID,
ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- ============================================
-- STEP 7: Add indexes for performance
-- ============================================

CREATE INDEX IF NOT EXISTS idx_listings_user_id ON listings(user_id);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_listings_city ON listings(city);
CREATE INDEX IF NOT EXISTS idx_listings_price ON listings(price);

CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_listing_id ON favorites(listing_id);

CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_listing_id ON bookings(listing_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

CREATE INDEX IF NOT EXISTS idx_reviews_listing_id ON reviews(listing_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);

CREATE INDEX IF NOT EXISTS idx_payments_booking_id ON payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_search_history_user_id ON search_history(user_id);
CREATE INDEX IF NOT EXISTS idx_search_history_created_at ON search_history(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_listing_views_listing_id ON listing_views(listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_views_user_id ON listing_views(user_id);
CREATE INDEX IF NOT EXISTS idx_listing_views_viewed_at ON listing_views(viewed_at DESC);

CREATE INDEX IF NOT EXISTS idx_conversations_participant1 ON conversations(participant1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant2 ON conversations(participant2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message ON conversations(last_message_at DESC);

-- ============================================
-- STEP 8: Insert default amenities
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
-- FINAL MESSAGE
-- ============================================
DO $$
BEGIN
    RAISE NOTICE 'Migration Step 1 Complete! Now run the data migration script.';
END $$;