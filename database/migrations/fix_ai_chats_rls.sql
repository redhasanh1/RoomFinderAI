-- Fix Row Level Security for ai_chats table to allow AI negotiator to insert records

-- Create ai_chats table if it doesn't exist
CREATE TABLE IF NOT EXISTS ai_chats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    conversation_data JSONB,
    title VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS if not already enabled
ALTER TABLE ai_chats ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view their own ai_chats" ON ai_chats;
DROP POLICY IF EXISTS "Users can insert their own ai_chats" ON ai_chats;
DROP POLICY IF EXISTS "AI can insert ai_chats for any user" ON ai_chats;
DROP POLICY IF EXISTS "Allow AI negotiator to insert notifications" ON ai_chats;

-- Create policies for ai_chats table

-- Policy 1: Users can view their own ai_chats
CREATE POLICY "Users can view their own ai_chats" ON ai_chats
    FOR SELECT USING (user_email = current_setting('app.current_user_email', true));

-- Policy 2: Allow all inserts (simplified to fix AI notification issue)
-- This allows both users to insert their own chats AND AI to insert for any user
CREATE POLICY "Allow all ai_chat inserts" ON ai_chats
    FOR INSERT WITH CHECK (true);

-- Alternative approach: Allow all inserts (simpler)
-- This is more permissive but ensures AI notifications work
-- CREATE POLICY "Allow all ai_chat inserts" ON ai_chats
--     FOR INSERT WITH CHECK (true);

-- Grant necessary permissions
GRANT SELECT, INSERT ON ai_chats TO anon;
GRANT SELECT, INSERT ON ai_chats TO authenticated;

-- Function to set current user email (if not exists)
CREATE OR REPLACE FUNCTION set_current_user_email(email TEXT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_email', email, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;