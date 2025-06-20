-- Simplified Verification System Setup
-- This version handles missing users table gracefully

-- 1. Drop existing objects first
DROP FUNCTION IF EXISTS set_current_user_email(text);
DROP TRIGGER IF EXISTS update_user_verification_trigger ON user_verifications;
DROP TRIGGER IF EXISTS check_verification_expiry_trigger ON user_verifications;
DROP TRIGGER IF EXISTS update_user_verifications_updated_at ON user_verifications;
DROP FUNCTION IF EXISTS update_user_verification_status();
DROP FUNCTION IF EXISTS check_verification_expiry();
DROP FUNCTION IF EXISTS get_user_verification_status(TEXT);
DROP TABLE IF EXISTS user_verifications;
DROP TYPE IF EXISTS verification_status;

-- 2. Create enum for verification status
CREATE TYPE verification_status AS ENUM ('pending', 'approved', 'rejected', 'expired');

-- 3. Check if users table exists, if not create it
CREATE TABLE IF NOT EXISTS users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    profile_image VARCHAR(500) DEFAULT 'https://via.placeholder.com/40',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Add verification columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_badge_earned_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_provider VARCHAR(50);

-- 5. Create user_verifications table (without foreign key constraint initially)
CREATE TABLE user_verifications (
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
    
    -- Third-party verification data
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
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Create indexes
CREATE INDEX idx_user_verifications_user_email ON user_verifications(user_email);
CREATE INDEX idx_user_verifications_status ON user_verifications(verification_status);
CREATE INDEX idx_user_verifications_submitted_at ON user_verifications(submitted_at);
CREATE INDEX idx_users_is_verified ON users(is_verified);

-- 7. Create the updated_at trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Create trigger for updated_at on users table
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 9. Create trigger for updated_at on user_verifications table
CREATE TRIGGER update_user_verifications_updated_at 
    BEFORE UPDATE ON user_verifications 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 10. Create function to update user verification status
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
        
    ELSIF NEW.verification_status != 'approved' AND OLD.verification_status = 'approved' THEN
        -- User verification was revoked
        UPDATE users 
        SET 
            is_verified = FALSE,
            verification_badge_earned_at = NULL,
            verification_provider = NULL
        WHERE email = NEW.user_email;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. Create trigger for verification status updates
CREATE TRIGGER update_user_verification_trigger
    AFTER UPDATE ON user_verifications
    FOR EACH ROW EXECUTE FUNCTION update_user_verification_status();

-- 12. Create function for RLS (Row Level Security)
CREATE OR REPLACE FUNCTION set_current_user_email(email TEXT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_email', email, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. Enable Row Level Security
ALTER TABLE user_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 14. Create RLS policies for user_verifications
CREATE POLICY "Users can view their own verifications" ON user_verifications
    FOR SELECT USING (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can create their own verification requests" ON user_verifications
    FOR INSERT WITH CHECK (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can update their pending verifications" ON user_verifications
    FOR UPDATE USING (
        user_email = current_setting('app.current_user_email', true) AND 
        verification_status = 'pending'
    );

-- 15. Create RLS policies for users table
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (email = current_setting('app.current_user_email', true));

CREATE POLICY "Anyone can create a user account" ON users
    FOR INSERT WITH CHECK (true);

-- 16. Create function to get user verification status
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

-- 17. Insert demo data
INSERT INTO users (email, first_name, last_name, is_verified, verification_badge_earned_at, verification_provider)
VALUES ('demo@roomfinder.com', 'Demo', 'User', TRUE, NOW(), 'manual')
ON CONFLICT (email) DO UPDATE SET 
    is_verified = TRUE,
    verification_badge_earned_at = NOW(),
    verification_provider = 'manual';

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

-- 18. Test the setup
SELECT 'Verification system setup completed successfully!' as status;
SELECT 'user_verifications table created with ' || COUNT(*) || ' records' as verification_table_status 
FROM user_verifications;
SELECT 'users table has ' || COUNT(*) || ' records with verification columns' as users_table_status 
FROM users;