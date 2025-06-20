-- Debug Version: Create verification table step by step
-- This will show us exactly where it fails

-- Step 1: Clean slate - remove everything
DO $$
BEGIN
    -- Drop all objects that might reference user_verifications
    DROP TRIGGER IF EXISTS update_user_verification_trigger ON user_verifications;
    DROP TRIGGER IF EXISTS check_verification_expiry_trigger ON user_verifications;
    DROP TRIGGER IF EXISTS update_user_verifications_updated_at ON user_verifications;
    
    -- Drop functions
    DROP FUNCTION IF EXISTS update_user_verification_status();
    DROP FUNCTION IF EXISTS check_verification_expiry();
    DROP FUNCTION IF EXISTS get_user_verification_status(TEXT);
    DROP FUNCTION IF EXISTS set_current_user_email(text);
    
    -- Drop policies
    DROP POLICY IF EXISTS "Users can view their own verifications" ON user_verifications;
    DROP POLICY IF EXISTS "Users can create their own verification requests" ON user_verifications;
    DROP POLICY IF EXISTS "Users can update their pending verifications" ON user_verifications;
    
    -- Drop the table
    DROP TABLE IF EXISTS user_verifications CASCADE;
    
    -- Drop the type
    DROP TYPE IF EXISTS verification_status CASCADE;
    
    RAISE NOTICE 'Step 1: Cleanup completed successfully';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Step 1: Cleanup had errors: %', SQLERRM;
END $$;

-- Step 2: Create the enum type
DO $$
BEGIN
    CREATE TYPE verification_status AS ENUM ('pending', 'approved', 'rejected', 'expired');
    RAISE NOTICE 'Step 2: verification_status enum created successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Step 2: Failed to create enum: %', SQLERRM;
END $$;

-- Step 3: Create basic users table if it doesn't exist
DO $$
BEGIN
    CREATE TABLE IF NOT EXISTS users (
        id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
    RAISE NOTICE 'Step 3: users table ensured to exist';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Step 3: Failed to create users table: %', SQLERRM;
END $$;

-- Step 4: Create the user_verifications table (basic version first)
DO $$
BEGIN
    CREATE TABLE user_verifications (
        id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
        user_email VARCHAR(255) NOT NULL,
        verification_status verification_status DEFAULT 'pending',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
    RAISE NOTICE 'Step 4: user_verifications table created successfully (basic version)';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Step 4: Failed to create user_verifications table: %', SQLERRM;
END $$;

-- Step 5: Add additional columns to user_verifications
DO $$
BEGIN
    -- ID Document Information
    ALTER TABLE user_verifications ADD COLUMN id_document_url VARCHAR(500);
    ALTER TABLE user_verifications ADD COLUMN id_document_type VARCHAR(50);
    ALTER TABLE user_verifications ADD COLUMN id_document_number VARCHAR(100);
    ALTER TABLE user_verifications ADD COLUMN id_document_expiry DATE;
    
    -- Face Verification Information
    ALTER TABLE user_verifications ADD COLUMN face_scan_data JSONB;
    ALTER TABLE user_verifications ADD COLUMN face_verification_score DECIMAL(3,2);
    
    -- Third-party verification data
    ALTER TABLE user_verifications ADD COLUMN onfido_check_id VARCHAR(255);
    ALTER TABLE user_verifications ADD COLUMN onfido_report_id VARCHAR(255);
    ALTER TABLE user_verifications ADD COLUMN jumio_scan_reference VARCHAR(255);
    ALTER TABLE user_verifications ADD COLUMN third_party_verification_data JSONB;
    
    -- Verification Metadata
    ALTER TABLE user_verifications ADD COLUMN submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    ALTER TABLE user_verifications ADD COLUMN processed_at TIMESTAMP WITH TIME ZONE;
    ALTER TABLE user_verifications ADD COLUMN verified_at TIMESTAMP WITH TIME ZONE;
    ALTER TABLE user_verifications ADD COLUMN expires_at TIMESTAMP WITH TIME ZONE;
    
    -- Admin/System Information
    ALTER TABLE user_verifications ADD COLUMN processed_by VARCHAR(255);
    ALTER TABLE user_verifications ADD COLUMN rejection_reason TEXT;
    ALTER TABLE user_verifications ADD COLUMN verification_notes TEXT;
    
    -- Tracking
    ALTER TABLE user_verifications ADD COLUMN ip_address INET;
    ALTER TABLE user_verifications ADD COLUMN user_agent TEXT;
    ALTER TABLE user_verifications ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    
    RAISE NOTICE 'Step 5: Additional columns added to user_verifications successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Step 5: Failed to add columns: %', SQLERRM;
END $$;

-- Step 6: Add constraints
DO $$
BEGIN
    ALTER TABLE user_verifications 
    ADD CONSTRAINT chk_id_document_type 
    CHECK (id_document_type IN ('passport', 'drivers_license', 'national_id', 'other'));
    
    RAISE NOTICE 'Step 6: Constraints added successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Step 6: Failed to add constraints: %', SQLERRM;
END $$;

-- Step 7: Add verification columns to users table
DO $$
BEGIN
    ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_badge_earned_at TIMESTAMP WITH TIME ZONE;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_provider VARCHAR(50);
    
    RAISE NOTICE 'Step 7: Verification columns added to users table';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Step 7: Failed to add verification columns to users: %', SQLERRM;
END $$;

-- Step 8: Create indexes
DO $$
BEGIN
    CREATE INDEX idx_user_verifications_user_email ON user_verifications(user_email);
    CREATE INDEX idx_user_verifications_status ON user_verifications(verification_status);
    CREATE INDEX idx_user_verifications_submitted_at ON user_verifications(submitted_at);
    
    RAISE NOTICE 'Step 8: Indexes created successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Step 8: Failed to create indexes: %', SQLERRM;
END $$;

-- Step 9: Test that the table exists and works
DO $$
BEGIN
    -- Test insert
    INSERT INTO user_verifications (user_email, verification_status) 
    VALUES ('test@example.com', 'pending');
    
    -- Test select
    IF EXISTS (SELECT 1 FROM user_verifications WHERE user_email = 'test@example.com') THEN
        RAISE NOTICE 'Step 9: Table test successful - can insert and select';
    ELSE
        RAISE NOTICE 'Step 9: Table test failed - cannot find inserted record';
    END IF;
    
    -- Clean up test data
    DELETE FROM user_verifications WHERE user_email = 'test@example.com';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Step 9: Table test failed: %', SQLERRM;
END $$;

-- Step 10: Verify table structure
SELECT 
    'user_verifications table has ' || COUNT(*) || ' columns' as table_info
FROM information_schema.columns 
WHERE table_name = 'user_verifications';

-- Step 11: Show table details
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_verifications'
ORDER BY ordinal_position;