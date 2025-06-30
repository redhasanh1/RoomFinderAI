-- User Verifications table for ID/Face verification
CREATE TABLE IF NOT EXISTS user_verifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    
    -- ID Document Verification
    id_verification_status VARCHAR(20) DEFAULT 'pending' CHECK (id_verification_status IN ('pending', 'verified', 'failed', 'expired')),
    id_verification_data JSONB DEFAULT '{}'::jsonb,
    id_verified_at TIMESTAMP WITH TIME ZONE,
    
    -- Face Verification
    face_verification_status VARCHAR(20) DEFAULT 'pending' CHECK (face_verification_status IN ('pending', 'verified', 'failed')),
    face_verification_confidence DECIMAL(5,4),
    face_verified_at TIMESTAMP WITH TIME ZONE,
    
    -- General verification info
    verification_level VARCHAR(20) DEFAULT 'none' CHECK (verification_level IN ('none', 'id_only', 'face_only', 'full')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE,
    UNIQUE(user_email)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_verifications_user_email ON user_verifications(user_email);
CREATE INDEX IF NOT EXISTS idx_user_verifications_id_status ON user_verifications(id_verification_status);
CREATE INDEX IF NOT EXISTS idx_user_verifications_face_status ON user_verifications(face_verification_status);
CREATE INDEX IF NOT EXISTS idx_user_verifications_level ON user_verifications(verification_level);

-- Row Level Security
ALTER TABLE user_verifications ENABLE ROW LEVEL SECURITY;

-- User verification policies
CREATE POLICY "Users can view their own verification status" ON user_verifications
    FOR SELECT USING (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "System can manage user verifications" ON user_verifications
    FOR ALL WITH CHECK (true);

-- Trigger for updated_at
CREATE TRIGGER update_user_verifications_updated_at 
    BEFORE UPDATE ON user_verifications 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update verification level automatically
CREATE OR REPLACE FUNCTION update_verification_level()
RETURNS TRIGGER AS $$
BEGIN
    -- Determine verification level based on status
    IF NEW.id_verification_status = 'verified' AND NEW.face_verification_status = 'verified' THEN
        NEW.verification_level = 'full';
    ELSIF NEW.id_verification_status = 'verified' THEN
        NEW.verification_level = 'id_only';
    ELSIF NEW.face_verification_status = 'verified' THEN
        NEW.verification_level = 'face_only';
    ELSE
        NEW.verification_level = 'none';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update verification level
CREATE TRIGGER update_verification_level_trigger
    BEFORE INSERT OR UPDATE ON user_verifications
    FOR EACH ROW EXECUTE FUNCTION update_verification_level();