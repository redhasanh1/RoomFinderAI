-- User Verification System Extension to RoomFinderAI Database Schema
-- Run this after the main database_schema.sql

-- First, drop the existing function if it exists
DROP FUNCTION IF EXISTS set_current_user_email(text);

-- Create enum for verification status
DO $$ BEGIN
    CREATE TYPE verification_status AS ENUM ('pending', 'approved', 'rejected', 'expired');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- User Verifications table
CREATE TABLE IF NOT EXISTS user_verifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    verification_status verification_status DEFAULT 'pending',
    
    -- ID Document Information
    id_document_url VARCHAR(500), -- URL to uploaded ID document in Supabase Storage
    id_document_type VARCHAR(50) CHECK (id_document_type IN ('passport', 'drivers_license', 'national_id', 'other')),
    id_document_number VARCHAR(100), -- Extracted or manually entered
    id_document_expiry DATE,
    
    -- Face Verification Information
    face_scan_data JSONB, -- Store face scan vectors/data for comparison
    face_verification_score DECIMAL(3,2), -- Confidence score 0.00-1.00
    
    -- Verification Metadata
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    verified_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE, -- Verification expires after 1 year
    
    -- Admin/System Information
    processed_by VARCHAR(255), -- Admin email or 'system' for automated
    rejection_reason TEXT,
    verification_notes TEXT,
    
    -- Tracking
    ip_address INET,
    user_agent TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE
);

-- Add verification status to users table (only if columns don't exist)
DO $$ 
BEGIN
    BEGIN
        ALTER TABLE users ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;
    EXCEPTION
        WHEN duplicate_column THEN 
            RAISE NOTICE 'Column is_verified already exists in users table.';
    END;
    
    BEGIN
        ALTER TABLE users ADD COLUMN verification_badge_earned_at TIMESTAMP WITH TIME ZONE;
    EXCEPTION
        WHEN duplicate_column THEN 
            RAISE NOTICE 'Column verification_badge_earned_at already exists in users table.';
    END;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_verifications_user_email ON user_verifications(user_email);
CREATE INDEX IF NOT EXISTS idx_user_verifications_status ON user_verifications(verification_status);
CREATE INDEX IF NOT EXISTS idx_user_verifications_submitted_at ON user_verifications(submitted_at);
CREATE INDEX IF NOT EXISTS idx_users_is_verified ON users(is_verified);

-- Enable Row Level Security for verifications
ALTER TABLE user_verifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own verifications" ON user_verifications;
DROP POLICY IF EXISTS "Users can create their own verification requests" ON user_verifications;
DROP POLICY IF EXISTS "Users can update their pending verifications" ON user_verifications;

-- RLS Policies for user_verifications
CREATE POLICY "Users can view their own verifications" ON user_verifications
    FOR SELECT USING (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can create their own verification requests" ON user_verifications
    FOR INSERT WITH CHECK (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can update their pending verifications" ON user_verifications
    FOR UPDATE USING (
        user_email = current_setting('app.current_user_email', true) AND 
        verification_status = 'pending'
    );

-- Recreate the function with correct signature
CREATE OR REPLACE FUNCTION set_current_user_email(email TEXT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_email', email, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing triggers and functions for verification updates
DROP TRIGGER IF EXISTS update_user_verification_trigger ON user_verifications;
DROP FUNCTION IF EXISTS update_user_verification_status();

-- Trigger to update users.is_verified when verification is approved
CREATE OR REPLACE FUNCTION update_user_verification_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.verification_status = 'approved' AND OLD.verification_status != 'approved' THEN
        UPDATE users 
        SET 
            is_verified = TRUE,
            verification_badge_earned_at = NOW()
        WHERE email = NEW.user_email;
    ELSIF NEW.verification_status != 'approved' AND OLD.verification_status = 'approved' THEN
        UPDATE users 
        SET 
            is_verified = FALSE,
            verification_badge_earned_at = NULL
        WHERE email = NEW.user_email;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_verification_trigger
    AFTER UPDATE ON user_verifications
    FOR EACH ROW EXECUTE FUNCTION update_user_verification_status();

-- Drop existing expiry trigger and function
DROP TRIGGER IF EXISTS check_verification_expiry_trigger ON user_verifications;
DROP FUNCTION IF EXISTS check_verification_expiry();

-- Function to check if verification is expired and update status
CREATE OR REPLACE FUNCTION check_verification_expiry()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.expires_at IS NOT NULL AND NEW.expires_at < NOW() AND NEW.verification_status = 'approved' THEN
        NEW.verification_status = 'expired';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_verification_expiry_trigger
    BEFORE UPDATE ON user_verifications
    FOR EACH ROW EXECUTE FUNCTION check_verification_expiry();

-- Add trigger for updated_at on user_verifications
DROP TRIGGER IF EXISTS update_user_verifications_updated_at ON user_verifications;
CREATE TRIGGER update_user_verifications_updated_at 
    BEFORE UPDATE ON user_verifications 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Drop existing verification status function
DROP FUNCTION IF EXISTS get_user_verification_status(TEXT);

-- Create function to get user verification status
CREATE OR REPLACE FUNCTION get_user_verification_status(user_email_param TEXT)
RETURNS TABLE(
    is_verified BOOLEAN,
    verification_status verification_status,
    verified_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.is_verified,
        uv.verification_status,
        uv.verified_at,
        uv.expires_at
    FROM users u
    LEFT JOIN user_verifications uv ON u.email = uv.user_email 
        AND uv.verification_status = 'approved'
        AND (uv.expires_at IS NULL OR uv.expires_at > NOW())
    WHERE u.email = user_email_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;