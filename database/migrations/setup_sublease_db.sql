-- Simple Database Setup for Sublease Matching System
-- Run this SQL in your Supabase SQL editor

-- Create the user context function
CREATE OR REPLACE FUNCTION set_user_context(user_email TEXT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_email', user_email, TRUE);
END;
$$ LANGUAGE plpgsql;

-- Create sublease_requests table (simplified version without RLS for now)
CREATE TABLE IF NOT EXISTS sublease_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_email TEXT NOT NULL,
    type TEXT CHECK (type IN ('transfer', 'seeking')) NOT NULL,
    status TEXT CHECK (status IN ('active', 'matched', 'completed', 'cancelled')) DEFAULT 'active',
    
    -- Basic information
    title TEXT NOT NULL,
    description TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    
    -- Financial details
    rent_amount DECIMAL(10,2),
    min_budget DECIMAL(10,2),
    max_budget DECIMAL(10,2),
    utilities_included BOOLEAN DEFAULT false,
    security_deposit DECIMAL(10,2),
    
    -- Time requirements
    available_from DATE,
    available_until DATE,
    preferred_move_in DATE,
    preferred_move_out DATE,
    duration_months INTEGER,
    flexible_dates BOOLEAN DEFAULT false,
    
    -- Property details
    property_type TEXT CHECK (property_type IN ('apartment', 'house', 'room', 'studio', 'condo')),
    bedrooms INTEGER,
    bathrooms DECIMAL(3,1),
    square_feet INTEGER,
    furnished BOOLEAN DEFAULT false,
    
    -- Amenities (stored as JSON array)
    amenities JSONB DEFAULT '[]'::jsonb,
    
    -- Lifestyle preferences
    pet_friendly BOOLEAN DEFAULT false,
    smoking_allowed BOOLEAN DEFAULT false,
    cleanliness_level INTEGER CHECK (cleanliness_level BETWEEN 1 AND 5),
    noise_tolerance INTEGER CHECK (noise_tolerance BETWEEN 1 AND 5),
    social_level INTEGER CHECK (social_level BETWEEN 1 AND 5),
    
    -- Schedule preferences
    schedule_type TEXT CHECK (schedule_type IN ('early_bird', 'regular', 'night_owl')),
    work_from_home BOOLEAN DEFAULT false,
    
    -- Request details
    reason_for_transfer TEXT,
    urgency_level INTEGER CHECK (urgency_level BETWEEN 1 AND 5) DEFAULT 3,
    photos JSONB DEFAULT '[]'::jsonb,
    
    -- Contact and verification
    contact_method TEXT CHECK (contact_method IN ('platform', 'phone', 'email')) DEFAULT 'platform',
    phone_number TEXT,
    verified_lease BOOLEAN DEFAULT false,
    lease_document_url TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Create sublease_matches table
CREATE TABLE IF NOT EXISTS sublease_matches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    transfer_request_id UUID REFERENCES sublease_requests(id) ON DELETE CASCADE,
    seeking_request_id UUID REFERENCES sublease_requests(id) ON DELETE CASCADE,
    
    -- Compatibility scoring
    compatibility_score DECIMAL(5,2) CHECK (compatibility_score BETWEEN 0 AND 100),
    location_score DECIMAL(5,2),
    budget_score DECIMAL(5,2),
    date_score DECIMAL(5,2),
    lifestyle_score DECIMAL(5,2),
    amenity_score DECIMAL(5,2),
    
    -- Match status
    match_status TEXT CHECK (match_status IN ('suggested', 'viewed', 'interested', 'mutual_interest', 'negotiating', 'agreed', 'completed', 'declined')) DEFAULT 'suggested',
    
    -- Interest tracking
    transfer_user_interested BOOLEAN DEFAULT false,
    seeking_user_interested BOOLEAN DEFAULT false,
    transfer_user_viewed_at TIMESTAMP WITH TIME ZONE,
    seeking_user_viewed_at TIMESTAMP WITH TIME ZONE,
    
    -- Communication
    conversation_id UUID,
    last_interaction_at TIMESTAMP WITH TIME ZONE,
    
    -- Agreement details
    agreed_rent DECIMAL(10,2),
    agreed_move_in_date DATE,
    agreed_move_out_date DATE,
    agreed_terms JSONB,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Ensure unique matches
    UNIQUE(transfer_request_id, seeking_request_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_sublease_requests_user_email ON sublease_requests(user_email);
CREATE INDEX IF NOT EXISTS idx_sublease_requests_type_status ON sublease_requests(type, status);
CREATE INDEX IF NOT EXISTS idx_sublease_requests_location ON sublease_requests(city, state);
CREATE INDEX IF NOT EXISTS idx_sublease_matches_transfer_request ON sublease_matches(transfer_request_id);
CREATE INDEX IF NOT EXISTS idx_sublease_matches_seeking_request ON sublease_matches(seeking_request_id);

-- Grant permissions (adjust as needed for your setup)
-- These may need to be modified based on your specific Supabase setup