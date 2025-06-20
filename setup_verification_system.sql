-- Complete Verification System Setup for RoomFinderAI
-- Run this SQL in your Supabase database

-- 1. First, drop any existing conflicting objects
DROP FUNCTION IF EXISTS set_current_user_email(text);
DROP TRIGGER IF EXISTS update_user_verification_trigger ON user_verifications;
DROP TRIGGER IF EXISTS check_verification_expiry_trigger ON user_verifications;
DROP TRIGGER IF EXISTS update_user_verifications_updated_at ON user_verifications;
DROP FUNCTION IF EXISTS update_user_verification_status();
DROP FUNCTION IF EXISTS check_verification_expiry();
DROP FUNCTION IF EXISTS get_user_verification_status(TEXT);

-- 2. Create enum for verification status
DO $$ BEGIN
    CREATE TYPE verification_status AS ENUM ('pending', 'approved', 'rejected', 'expired');
EXCEPTION
    WHEN duplicate_object THEN 
        RAISE NOTICE 'verification_status enum already exists';
END $$;

-- 3. Create user_verifications table
CREATE TABLE IF NOT EXISTS user_verifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    verification_status verification_status DEFAULT 'pending',
    
    -- ID Document Information
    id_document_url VARCHAR(500),
    id_document_type VARCHAR(50) CHECK (id_document_type IN ('passport', 'drivers_license', 'national_id', 'other')),
    id_document_number VARCHAR(100),
    id_document_expiry DATE,
    
    -- Face Verification Information
    face_scan_data JSONB,
    face_verification_score DECIMAL(3,2),
    
    -- Third-party verification data (for Onfido/Jumio)
    onfido_check_id VARCHAR(255),
    onfido_report_id VARCHAR(255),
    jumio_scan_reference VARCHAR(255),
    third_party_verification_data JSONB,
    
    -- Verification Metadata
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    verified_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Admin/System Information
    processed_by VARCHAR(255),
    rejection_reason TEXT,
    verification_notes TEXT,
    
    -- Tracking
    ip_address INET,
    user_agent TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT fk_user_email FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE
);

-- 4. Add verification columns to users table
DO $$ 
BEGIN
    -- Add is_verified column
    BEGIN
        ALTER TABLE users ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added is_verified column to users table';
    EXCEPTION
        WHEN duplicate_column THEN 
            RAISE NOTICE 'Column is_verified already exists in users table';
    END;
    
    -- Add verification_badge_earned_at column
    BEGIN
        ALTER TABLE users ADD COLUMN verification_badge_earned_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added verification_badge_earned_at column to users table';
    EXCEPTION
        WHEN duplicate_column THEN 
            RAISE NOTICE 'Column verification_badge_earned_at already exists in users table';
    END;
    
    -- Add verification_provider column for tracking which service was used
    BEGIN
        ALTER TABLE users ADD COLUMN verification_provider VARCHAR(50);
        RAISE NOTICE 'Added verification_provider column to users table';
    EXCEPTION
        WHEN duplicate_column THEN 
            RAISE NOTICE 'Column verification_provider already exists in users table';
    END;
END $$;

-- 5. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_verifications_user_email ON user_verifications(user_email);
CREATE INDEX IF NOT EXISTS idx_user_verifications_status ON user_verifications(verification_status);
CREATE INDEX IF NOT EXISTS idx_user_verifications_submitted_at ON user_verifications(submitted_at);
CREATE INDEX IF NOT EXISTS idx_user_verifications_onfido_check_id ON user_verifications(onfido_check_id);
CREATE INDEX IF NOT EXISTS idx_user_verifications_jumio_scan_reference ON user_verifications(jumio_scan_reference);
CREATE INDEX IF NOT EXISTS idx_users_is_verified ON users(is_verified);

-- 6. Enable Row Level Security
ALTER TABLE user_verifications ENABLE ROW LEVEL SECURITY;

-- 7. Drop existing policies
DROP POLICY IF EXISTS "Users can view their own verifications" ON user_verifications;
DROP POLICY IF EXISTS "Users can create their own verification requests" ON user_verifications;
DROP POLICY IF EXISTS "Users can update their pending verifications" ON user_verifications;

-- 8. Create RLS policies
CREATE POLICY "Users can view their own verifications" ON user_verifications
    FOR SELECT USING (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can create their own verification requests" ON user_verifications
    FOR INSERT WITH CHECK (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can update their pending verifications" ON user_verifications
    FOR UPDATE USING (
        user_email = current_setting('app.current_user_email', true) AND 
        verification_status = 'pending'
    );

-- 9. Recreate the set_current_user_email function
CREATE OR REPLACE FUNCTION set_current_user_email(email TEXT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_email', email, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Create trigger function to update users table when verification status changes
CREATE OR REPLACE FUNCTION update_user_verification_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.verification_status = 'approved' AND (OLD.verification_status IS NULL OR OLD.verification_status != 'approved') THEN
        -- User just got verified
        UPDATE users 
        SET 
            is_verified = TRUE,
            verification_badge_earned_at = NOW(),
            verification_provider = COALESCE(
                CASE 
                    WHEN NEW.onfido_check_id IS NOT NULL THEN 'onfido'
                    WHEN NEW.jumio_scan_reference IS NOT NULL THEN 'jumio'
                    ELSE 'manual'
                END,
                'manual'
            )
        WHERE email = NEW.user_email;
        
        RAISE NOTICE 'User % verified successfully via %', NEW.user_email, COALESCE(
            CASE 
                WHEN NEW.onfido_check_id IS NOT NULL THEN 'onfido'
                WHEN NEW.jumio_scan_reference IS NOT NULL THEN 'jumio'
                ELSE 'manual'
            END,
            'manual'
        );
        
    ELSIF NEW.verification_status != 'approved' AND OLD.verification_status = 'approved' THEN
        -- User verification was revoked
        UPDATE users 
        SET 
            is_verified = FALSE,
            verification_badge_earned_at = NULL,
            verification_provider = NULL
        WHERE email = NEW.user_email;
        
        RAISE NOTICE 'User % verification revoked', NEW.user_email;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. Create trigger for verification status updates
CREATE TRIGGER update_user_verification_trigger
    AFTER UPDATE ON user_verifications
    FOR EACH ROW EXECUTE FUNCTION update_user_verification_status();

-- 12. Create function to check verification expiry
CREATE OR REPLACE FUNCTION check_verification_expiry()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.expires_at IS NOT NULL AND NEW.expires_at < NOW() AND NEW.verification_status = 'approved' THEN
        NEW.verification_status = 'expired';
        RAISE NOTICE 'Verification for user % has expired', NEW.user_email;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 13. Create trigger for expiry checking
CREATE TRIGGER check_verification_expiry_trigger
    BEFORE UPDATE ON user_verifications
    FOR EACH ROW EXECUTE FUNCTION check_verification_expiry();

-- 14. Create trigger for updated_at timestamp
CREATE TRIGGER update_user_verifications_updated_at 
    BEFORE UPDATE ON user_verifications 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 15. Create function to get comprehensive verification status
CREATE OR REPLACE FUNCTION get_user_verification_status(user_email_param TEXT)
RETURNS TABLE(
    is_verified BOOLEAN,
    verification_status verification_status,
    verified_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    verification_provider VARCHAR(50),
    latest_verification_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.is_verified,
        uv.verification_status,
        uv.verified_at,
        uv.expires_at,
        u.verification_provider,
        uv.id as latest_verification_id
    FROM users u
    LEFT JOIN user_verifications uv ON u.email = uv.user_email 
        AND uv.id = (
            SELECT id 
            FROM user_verifications 
            WHERE user_email = user_email_param 
            ORDER BY created_at DESC 
            LIMIT 1
        )
    WHERE u.email = user_email_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 16. Insert test verification data for demonstration
DO $$
BEGIN
    -- Check if demo user exists and add verification status
    IF EXISTS (SELECT 1 FROM users WHERE email = 'demo@roomfinder.com') THEN
        UPDATE users 
        SET 
            is_verified = TRUE, 
            verification_badge_earned_at = NOW(),
            verification_provider = 'manual'
        WHERE email = 'demo@roomfinder.com';
        
        -- Insert a sample verification record
        INSERT INTO user_verifications (
            user_email,
            verification_status,
            id_document_type,
            face_verification_score,
            verified_at,
            expires_at,
            processed_by
        ) VALUES (
            'demo@roomfinder.com',
            'approved',
            'drivers_license',
            0.95,
            NOW(),
            NOW() + INTERVAL '1 year',
            'system'
        ) ON CONFLICT DO NOTHING;
        
        RAISE NOTICE 'Demo user verification set up successfully';
    ELSE
        RAISE NOTICE 'Demo user not found, skipping demo verification setup';
    END IF;
END $$;

-- 17. Create storage bucket policy (if using Supabase Storage)
-- Note: This might need to be done via Supabase Dashboard or API
-- Storage bucket name: verification-documents

COMMIT;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'VERIFICATION SYSTEM SETUP COMPLETE!';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Create Supabase Storage bucket: verification-documents';
    RAISE NOTICE '2. Set up storage policies for authenticated users';
    RAISE NOTICE '3. Configure Onfido or Jumio API credentials';
    RAISE NOTICE '4. Test the verification system';
    RAISE NOTICE '==============================================';
END $$;