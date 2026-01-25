-- Dispute Resolution System Schema
-- Complete case management system for handling disputes between users, landlords, and tenants

-- Create disputes table (main case tracking)
CREATE TABLE IF NOT EXISTS disputes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_number TEXT UNIQUE NOT NULL, -- Format: DSP-YYYY-XXXXX (e.g., DSP-2026-00001)
  complainant_email TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  respondent_email TEXT REFERENCES users(email) ON DELETE SET NULL, -- Can be null if reported anonymously
  dispute_type TEXT NOT NULL CHECK (dispute_type IN (
    'scam', 'fraud', 'harassment', 'listing_misrepresentation', 'payment_issue',
    'lease_violation', 'property_condition', 'security_deposit', 'discrimination',
    'privacy_violation', 'terms_violation', 'other'
  )),
  status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN (
    'submitted', 'under_review', 'investigating', 'awaiting_response',
    'in_mediation', 'escalated', 'resolved', 'dismissed', 'closed'
  )),
  severity TEXT NOT NULL DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  title TEXT NOT NULL, -- Brief summary (max 255 chars enforced in app)
  description TEXT NOT NULL, -- Detailed explanation
  desired_outcome TEXT, -- What resolution the complainant wants
  incident_date DATE, -- When the incident occurred
  related_listing_id UUID REFERENCES listings(id) ON DELETE SET NULL,
  related_conversation_id UUID, -- Reference to conversations table if exists
  related_sublease_id UUID, -- Reference to sublease table if exists
  evidence JSONB DEFAULT '[]'::jsonb, -- Array of evidence files: [{url, filename, type, uploaded_at}]
  assigned_to TEXT, -- Mediator/admin email handling the case
  resolution_summary TEXT, -- Final resolution details
  resolution_type TEXT CHECK (resolution_type IN (
    'mutual_agreement', 'refund_issued', 'warning_issued', 'account_suspended',
    'listing_removed', 'no_action', 'escalated_legal', null
  )),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  resolved_at TIMESTAMP WITH TIME ZONE
);

-- Create dispute_messages table (communication thread for each case)
CREATE TABLE IF NOT EXISTS dispute_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  dispute_id UUID NOT NULL REFERENCES disputes(id) ON DELETE CASCADE,
  sender_email TEXT NOT NULL,
  sender_role TEXT NOT NULL CHECK (sender_role IN ('complainant', 'respondent', 'admin', 'system')),
  message TEXT NOT NULL,
  attachments JSONB DEFAULT '[]'::jsonb, -- Array of attachment files: [{url, filename, type}]
  is_internal_note BOOLEAN DEFAULT false, -- Admin-only notes not visible to parties
  read_by JSONB DEFAULT '[]'::jsonb, -- Array of emails who have read this message
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create dispute_resolutions table (final outcome details)
CREATE TABLE IF NOT EXISTS dispute_resolutions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  dispute_id UUID NOT NULL REFERENCES disputes(id) ON DELETE CASCADE,
  resolution_details TEXT NOT NULL,
  action_taken TEXT, -- Description of actions taken (warnings, suspensions, etc.)
  complainant_satisfied BOOLEAN, -- Did complainant accept the resolution?
  respondent_satisfied BOOLEAN, -- Did respondent accept the resolution?
  refund_amount DECIMAL(10, 2), -- If refund was issued
  refund_status TEXT CHECK (refund_status IN ('pending', 'processing', 'completed', 'failed', null)),
  account_actions JSONB DEFAULT '[]'::jsonb, -- Array of actions: [{user_email, action_type, action_date}]
  follow_up_required BOOLEAN DEFAULT false,
  follow_up_notes TEXT,
  resolved_by TEXT, -- Admin/mediator email who resolved the case
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user_reports table (quick flagging system)
CREATE TABLE IF NOT EXISTS user_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_email TEXT NOT NULL REFERENCES users(email) ON DELETE CASCADE,
  reported_user_email TEXT REFERENCES users(email) ON DELETE SET NULL,
  report_type TEXT NOT NULL CHECK (report_type IN (
    'inappropriate_listing', 'fake_profile', 'spam', 'offensive_message',
    'suspicious_activity', 'other'
  )),
  related_listing_id UUID REFERENCES listings(id) ON DELETE SET NULL,
  related_message_id UUID, -- Reference to message if applicable
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'actioned', 'dismissed')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  reviewed_by TEXT -- Admin email who reviewed
);

-- Create indexes for better performance
CREATE INDEX idx_disputes_complainant ON disputes(complainant_email);
CREATE INDEX idx_disputes_respondent ON disputes(respondent_email);
CREATE INDEX idx_disputes_status ON disputes(status);
CREATE INDEX idx_disputes_type ON disputes(dispute_type);
CREATE INDEX idx_disputes_case_number ON disputes(case_number);
CREATE INDEX idx_disputes_created_at ON disputes(created_at);
CREATE INDEX idx_dispute_messages_dispute_id ON dispute_messages(dispute_id);
CREATE INDEX idx_dispute_messages_sender ON dispute_messages(sender_email);
CREATE INDEX idx_dispute_resolutions_dispute_id ON dispute_resolutions(dispute_id);
CREATE INDEX idx_user_reports_reporter ON user_reports(reporter_email);
CREATE INDEX idx_user_reports_reported ON user_reports(reported_user_email);
CREATE INDEX idx_user_reports_status ON user_reports(status);

-- Enable Row Level Security
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispute_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispute_resolutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reports ENABLE ROW LEVEL SECURITY;

-- RLS Policies for disputes table

-- Users can view disputes where they are complainant or respondent
CREATE POLICY disputes_select_involved_parties ON disputes
  FOR SELECT
  USING (
    complainant_email = current_setting('app.current_user_email', true) OR
    respondent_email = current_setting('app.current_user_email', true)
  );

-- Users can insert disputes as complainant
CREATE POLICY disputes_insert_complainant ON disputes
  FOR INSERT
  WITH CHECK (complainant_email = current_setting('app.current_user_email', true));

-- Users can update their own disputes (only specific fields like adding evidence)
CREATE POLICY disputes_update_own ON disputes
  FOR UPDATE
  USING (complainant_email = current_setting('app.current_user_email', true));

-- RLS Policies for dispute_messages table

-- Users can view messages in disputes they're involved in
CREATE POLICY dispute_messages_select_involved ON dispute_messages
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM disputes
      WHERE disputes.id = dispute_messages.dispute_id
      AND (
        disputes.complainant_email = current_setting('app.current_user_email', true) OR
        disputes.respondent_email = current_setting('app.current_user_email', true)
      )
    )
    AND (is_internal_note = false) -- Hide internal notes from users
  );

-- Users can insert messages to disputes they're involved in
CREATE POLICY dispute_messages_insert_involved ON dispute_messages
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM disputes
      WHERE disputes.id = dispute_messages.dispute_id
      AND (
        disputes.complainant_email = current_setting('app.current_user_email', true) OR
        disputes.respondent_email = current_setting('app.current_user_email', true)
      )
    )
  );

-- RLS Policies for dispute_resolutions table

-- Users can view resolutions for disputes they're involved in
CREATE POLICY dispute_resolutions_select_involved ON dispute_resolutions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM disputes
      WHERE disputes.id = dispute_resolutions.dispute_id
      AND (
        disputes.complainant_email = current_setting('app.current_user_email', true) OR
        disputes.respondent_email = current_setting('app.current_user_email', true)
      )
    )
  );

-- RLS Policies for user_reports table

-- Users can view their own reports
CREATE POLICY user_reports_select_own ON user_reports
  FOR SELECT
  USING (reporter_email = current_setting('app.current_user_email', true));

-- Users can insert their own reports
CREATE POLICY user_reports_insert_own ON user_reports
  FOR INSERT
  WITH CHECK (reporter_email = current_setting('app.current_user_email', true));

-- Function to generate unique case numbers
CREATE OR REPLACE FUNCTION generate_case_number()
RETURNS TEXT AS $$
DECLARE
  year TEXT;
  next_num INTEGER;
  case_num TEXT;
BEGIN
  year := TO_CHAR(NOW(), 'YYYY');

  -- Get the next number for this year
  SELECT COALESCE(MAX(CAST(SUBSTRING(case_number FROM 10) AS INTEGER)), 0) + 1
  INTO next_num
  FROM disputes
  WHERE case_number LIKE 'DSP-' || year || '-%';

  -- Format as DSP-YYYY-XXXXX
  case_num := 'DSP-' || year || '-' || LPAD(next_num::TEXT, 5, '0');

  RETURN case_num;
END;
$$ LANGUAGE plpgsql;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at on disputes table
CREATE TRIGGER update_disputes_updated_at
  BEFORE UPDATE ON disputes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Comments on tables
COMMENT ON TABLE disputes IS 'Main dispute case tracking with case management workflow';
COMMENT ON TABLE dispute_messages IS 'Communication thread for each dispute case between parties and mediators';
COMMENT ON TABLE dispute_resolutions IS 'Final resolution outcomes and actions taken for each dispute';
COMMENT ON TABLE user_reports IS 'Quick flagging system for inappropriate content, users, or behavior';

-- Comments on key columns
COMMENT ON COLUMN disputes.case_number IS 'Unique case identifier in format DSP-YYYY-XXXXX for easy reference';
COMMENT ON COLUMN disputes.evidence IS 'JSONB array of evidence files with URLs, filenames, and upload timestamps';
COMMENT ON COLUMN dispute_messages.is_internal_note IS 'Admin-only notes not visible to disputants';
COMMENT ON COLUMN dispute_resolutions.account_actions IS 'JSONB array of actions taken against accounts (warnings, suspensions, etc.)';
