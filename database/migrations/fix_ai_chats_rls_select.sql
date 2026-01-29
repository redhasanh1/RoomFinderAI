-- Fix RLS SELECT policy for ai_chats table
-- The previous policy used current_setting() which doesn't work with Supabase auth
-- This version uses auth.jwt() to properly identify the logged-in user

-- Drop the broken SELECT policy
DROP POLICY IF EXISTS "Users can view their own ai_chats" ON ai_chats;

-- Create a new SELECT policy that uses Supabase's auth.jwt()
-- This allows users to see ai_chats where the user_email matches their authenticated email
CREATE POLICY "Users can view their own ai_chats" ON ai_chats
    FOR SELECT USING (user_email = auth.jwt() ->> 'email');

-- Also ensure the INSERT policy is correct (allow all inserts for notifications)
DROP POLICY IF EXISTS "Allow all ai_chat inserts" ON ai_chats;
CREATE POLICY "Allow all ai_chat inserts" ON ai_chats
    FOR INSERT WITH CHECK (true);

-- Verify grants are in place
GRANT SELECT, INSERT ON ai_chats TO anon;
GRANT SELECT, INSERT ON ai_chats TO authenticated;
