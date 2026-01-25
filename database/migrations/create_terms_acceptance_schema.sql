-- Terms Acceptance Tracking Schema
-- This table logs user acceptance of legal documents for compliance and legal defensibility

-- Create terms_acceptance table
CREATE TABLE IF NOT EXISTS terms_acceptance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_email TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  document_type TEXT NOT NULL, -- 'terms_of_service', 'privacy_policy', 'acceptable_use', 'cookie_policy', 'dispute_resolution', 'landlord_responsibilities', 'ai_negotiation_disclaimer'
  version TEXT NOT NULL, -- Version number of the document (e.g., '1.0', '2.1')
  accepted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ip_address INET, -- IP address for legal proof
  user_agent TEXT, -- Browser user agent for legal proof
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX idx_terms_acceptance_user_email ON terms_acceptance(user_email);
CREATE INDEX idx_terms_acceptance_document_type ON terms_acceptance(document_type);
CREATE INDEX idx_terms_acceptance_accepted_at ON terms_acceptance(accepted_at);
CREATE INDEX idx_terms_acceptance_user_doc ON terms_acceptance(user_email, document_type);

-- Enable Row Level Security
ALTER TABLE terms_acceptance ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own acceptance records
CREATE POLICY terms_acceptance_select_own ON terms_acceptance
  FOR SELECT
  USING (user_email = current_setting('app.current_user_email', true));

-- RLS Policy: Users can insert their own acceptance records
CREATE POLICY terms_acceptance_insert_own ON terms_acceptance
  FOR INSERT
  WITH CHECK (user_email = current_setting('app.current_user_email', true));

-- RLS Policy: Admins can view all acceptance records
-- Note: Admin detection via email pattern or role column (if exists)
-- For now, this is a placeholder - implement based on your admin detection logic
-- CREATE POLICY terms_acceptance_admin_all ON terms_acceptance
--   FOR ALL
--   USING (current_setting('app.current_user_email', true) LIKE '%@roomfinderai.com');

-- Comment on table
COMMENT ON TABLE terms_acceptance IS 'Tracks user acceptance of legal documents (Terms of Service, Privacy Policy, etc.) with timestamp and IP for legal compliance';

-- Comment on columns
COMMENT ON COLUMN terms_acceptance.document_type IS 'Type of legal document accepted (e.g., terms_of_service, privacy_policy, acceptable_use)';
COMMENT ON COLUMN terms_acceptance.version IS 'Version number of the document at time of acceptance';
COMMENT ON COLUMN terms_acceptance.ip_address IS 'IP address of user at time of acceptance for legal proof';
COMMENT ON COLUMN terms_acceptance.user_agent IS 'Browser user agent at time of acceptance for legal proof';
