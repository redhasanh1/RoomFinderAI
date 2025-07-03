-- Sublease Matching System Database Schema
-- This schema creates tables for sublease transfer and seeking requests with matching capabilities

-- Create sublease_requests table for both transfer and seeking requests
CREATE TABLE IF NOT EXISTS sublease_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    user_email TEXT NOT NULL,
    type TEXT CHECK (type IN ('transfer', 'seeking')) NOT NULL,
    status TEXT CHECK (status IN ('active', 'matched', 'completed', 'cancelled')) DEFAULT 'active',
    
    -- Location information
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    coordinates POINT,
    
    -- Financial details
    rent_amount DECIMAL(10,2),
    min_budget DECIMAL(10,2), -- for seeking requests
    max_budget DECIMAL(10,2), -- for seeking requests
    utilities_included BOOLEAN DEFAULT false,
    security_deposit DECIMAL(10,2),
    
    -- Time requirements
    available_from DATE,
    available_until DATE,
    preferred_move_in DATE, -- for seeking requests
    preferred_move_out DATE, -- for seeking requests
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
    title TEXT NOT NULL,
    description TEXT,
    reason_for_transfer TEXT, -- for transfer requests
    urgency_level INTEGER CHECK (urgency_level BETWEEN 1 AND 5) DEFAULT 3,
    photos JSONB DEFAULT '[]'::jsonb, -- array of photo URLs
    
    -- Contact and verification
    contact_method TEXT CHECK (contact_method IN ('platform', 'phone', 'email')) DEFAULT 'platform',
    phone_number TEXT,
    verified_lease BOOLEAN DEFAULT false,
    lease_document_url TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Search optimization
    search_vector tsvector
);

-- Create sublease_matches table for tracking compatibility matches
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
    conversation_id UUID, -- Reference to conversations table
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

-- Create sublease_transfers table for completed transfers
CREATE TABLE IF NOT EXISTS sublease_transfers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    match_id UUID REFERENCES sublease_matches(id) ON DELETE CASCADE,
    transfer_request_id UUID REFERENCES sublease_requests(id),
    seeking_request_id UUID REFERENCES sublease_requests(id),
    
    -- User details
    transferor_id UUID REFERENCES auth.users(id),
    transferee_id UUID REFERENCES auth.users(id),
    transferor_email TEXT,
    transferee_email TEXT,
    
    -- Final agreement details
    final_rent DECIMAL(10,2) NOT NULL,
    final_security_deposit DECIMAL(10,2),
    final_move_in_date DATE NOT NULL,
    final_move_out_date DATE NOT NULL,
    utilities_arrangement TEXT,
    
    -- Property handover
    keys_transferred BOOLEAN DEFAULT false,
    utilities_transferred BOOLEAN DEFAULT false,
    lease_amended BOOLEAN DEFAULT false,
    inventory_completed BOOLEAN DEFAULT false,
    
    -- Documentation
    transfer_agreement_url TEXT,
    handover_checklist JSONB,
    photos_condition JSONB DEFAULT '[]'::jsonb,
    
    -- Feedback
    transferor_rating INTEGER CHECK (transferor_rating BETWEEN 1 AND 5),
    transferee_rating INTEGER CHECK (transferee_rating BETWEEN 1 AND 5),
    transferor_feedback TEXT,
    transferee_feedback TEXT,
    
    -- Timestamps
    transfer_initiated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    transfer_completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_sublease_requests_user_email ON sublease_requests(user_email);
CREATE INDEX IF NOT EXISTS idx_sublease_requests_type_status ON sublease_requests(type, status);
CREATE INDEX IF NOT EXISTS idx_sublease_requests_location ON sublease_requests(city, state);
CREATE INDEX IF NOT EXISTS idx_sublease_requests_budget ON sublease_requests(rent_amount, min_budget, max_budget);
CREATE INDEX IF NOT EXISTS idx_sublease_requests_dates ON sublease_requests(available_from, available_until);
CREATE INDEX IF NOT EXISTS idx_sublease_requests_created_at ON sublease_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_sublease_requests_search_vector ON sublease_requests USING gin(search_vector);

CREATE INDEX IF NOT EXISTS idx_sublease_matches_transfer_request ON sublease_matches(transfer_request_id);
CREATE INDEX IF NOT EXISTS idx_sublease_matches_seeking_request ON sublease_matches(seeking_request_id);
CREATE INDEX IF NOT EXISTS idx_sublease_matches_score ON sublease_matches(compatibility_score DESC);
CREATE INDEX IF NOT EXISTS idx_sublease_matches_status ON sublease_matches(match_status);
CREATE INDEX IF NOT EXISTS idx_sublease_matches_created_at ON sublease_matches(created_at);

CREATE INDEX IF NOT EXISTS idx_sublease_transfers_match_id ON sublease_transfers(match_id);
CREATE INDEX IF NOT EXISTS idx_sublease_transfers_users ON sublease_transfers(transferor_id, transferee_id);

-- Create search vector update function
CREATE OR REPLACE FUNCTION update_sublease_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.address, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(NEW.city, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(NEW.amenities::text, '')), 'D');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for search vector updates
DROP TRIGGER IF EXISTS sublease_requests_search_vector_update ON sublease_requests;
CREATE TRIGGER sublease_requests_search_vector_update
    BEFORE INSERT OR UPDATE ON sublease_requests
    FOR EACH ROW EXECUTE FUNCTION update_sublease_search_vector();

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create updated_at triggers
DROP TRIGGER IF EXISTS update_sublease_requests_updated_at ON sublease_requests;
CREATE TRIGGER update_sublease_requests_updated_at
    BEFORE UPDATE ON sublease_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sublease_matches_updated_at ON sublease_matches;
CREATE TRIGGER update_sublease_matches_updated_at
    BEFORE UPDATE ON sublease_matches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sublease_transfers_updated_at ON sublease_transfers;
CREATE TRIGGER update_sublease_transfers_updated_at
    BEFORE UPDATE ON sublease_transfers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS) policies
ALTER TABLE sublease_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE sublease_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE sublease_transfers ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only see their own sublease requests
CREATE POLICY "Users can view own sublease requests" ON sublease_requests
    FOR SELECT USING (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can insert own sublease requests" ON sublease_requests
    FOR INSERT WITH CHECK (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can update own sublease requests" ON sublease_requests
    FOR UPDATE USING (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can delete own sublease requests" ON sublease_requests
    FOR DELETE USING (user_email = current_setting('app.current_user_email', true));

-- RLS Policy: Users can see matches involving their requests
CREATE POLICY "Users can view matches for their requests" ON sublease_matches
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM sublease_requests sr1 
            WHERE sr1.id = transfer_request_id 
            AND sr1.user_email = current_setting('app.current_user_email', true)
        ) OR EXISTS (
            SELECT 1 FROM sublease_requests sr2 
            WHERE sr2.id = seeking_request_id 
            AND sr2.user_email = current_setting('app.current_user_email', true)
        )
    );

CREATE POLICY "Users can update matches for their requests" ON sublease_matches
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM sublease_requests sr1 
            WHERE sr1.id = transfer_request_id 
            AND sr1.user_email = current_setting('app.current_user_email', true)
        ) OR EXISTS (
            SELECT 1 FROM sublease_requests sr2 
            WHERE sr2.id = seeking_request_id 
            AND sr2.user_email = current_setting('app.current_user_email', true)
        )
    );

-- RLS Policy: Users can see transfers they're involved in
CREATE POLICY "Users can view their transfers" ON sublease_transfers
    FOR SELECT USING (
        transferor_email = current_setting('app.current_user_email', true) OR
        transferee_email = current_setting('app.current_user_email', true)
    );

CREATE POLICY "Users can update their transfers" ON sublease_transfers
    FOR UPDATE USING (
        transferor_email = current_setting('app.current_user_email', true) OR
        transferee_email = current_setting('app.current_user_email', true)
    );

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON sublease_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON sublease_matches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON sublease_transfers TO authenticated;

-- Comments for documentation
COMMENT ON TABLE sublease_requests IS 'Stores both sublease transfer requests (users wanting to get out) and seeking requests (users looking for subleases)';
COMMENT ON TABLE sublease_matches IS 'Tracks compatibility matches between transfer and seeking requests with scoring';
COMMENT ON TABLE sublease_transfers IS 'Records completed sublease transfers with handover details and feedback';

COMMENT ON COLUMN sublease_requests.type IS 'Either transfer (wanting to get out) or seeking (looking for sublease)';
COMMENT ON COLUMN sublease_requests.compatibility_score IS 'Overall compatibility score from 0-100';
COMMENT ON COLUMN sublease_matches.match_status IS 'Progress through the matching and transfer process';