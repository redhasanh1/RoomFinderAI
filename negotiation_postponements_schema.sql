-- Negotiation Postponements Table
-- Tracks when negotiations are postponed and schedules follow-ups

CREATE TABLE IF NOT EXISTS negotiation_postponements (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    conversation_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    landlord_email VARCHAR(255) NOT NULL,
    
    -- Postponement details
    postponement_reason TEXT NOT NULL,
    postponed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expected_follow_up_time TIMESTAMP WITH TIME ZONE,
    
    -- Original negotiation context to restore
    last_offer_amount INTEGER,
    negotiation_round INTEGER DEFAULT 1,
    conversation_context JSONB DEFAULT '{}'::jsonb,
    
    -- Follow-up status
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'followed_up', 'resumed', 'expired')),
    follow_up_sent_at TIMESTAMP WITH TIME ZONE,
    resumed_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Foreign keys
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_postponements_conversation_id ON negotiation_postponements(conversation_id);
CREATE INDEX IF NOT EXISTS idx_postponements_status ON negotiation_postponements(status);
CREATE INDEX IF NOT EXISTS idx_postponements_follow_up_time ON negotiation_postponements(expected_follow_up_time);
CREATE INDEX IF NOT EXISTS idx_postponements_created_at ON negotiation_postponements(created_at);

-- Trigger to update updated_at column
CREATE TRIGGER update_postponements_updated_at 
    BEFORE UPDATE ON negotiation_postponements 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE negotiation_postponements ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own postponements" ON negotiation_postponements
    FOR SELECT USING (
        user_email = current_setting('app.current_user_email', true) OR 
        landlord_email = current_setting('app.current_user_email', true)
    );

CREATE POLICY "Users can create postponements for their conversations" ON negotiation_postponements
    FOR INSERT WITH CHECK (
        user_email = current_setting('app.current_user_email', true) OR 
        landlord_email = current_setting('app.current_user_email', true)
    );

CREATE POLICY "Users can update their own postponements" ON negotiation_postponements
    FOR UPDATE USING (
        user_email = current_setting('app.current_user_email', true) OR 
        landlord_email = current_setting('app.current_user_email', true)
    );