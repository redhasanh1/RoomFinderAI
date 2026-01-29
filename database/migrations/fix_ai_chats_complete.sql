-- Complete fix for ai_chats table
-- The app uses localStorage auth, not Supabase Auth, so auth.jwt() doesn't work
-- Solution: Use SECURITY DEFINER functions to bypass RLS

-- Ensure table exists
CREATE TABLE IF NOT EXISTS ai_chats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    conversation_data JSONB,
    title VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE ai_chats ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can view their own ai_chats" ON ai_chats;
DROP POLICY IF EXISTS "Allow all ai_chat inserts" ON ai_chats;
DROP POLICY IF EXISTS "Allow all selects" ON ai_chats;

-- Create simple policies that allow all operations for authenticated users
-- The security is handled at the application level (query filters by user_email)
CREATE POLICY "Allow authenticated select" ON ai_chats
    FOR SELECT TO authenticated, anon
    USING (true);

CREATE POLICY "Allow authenticated insert" ON ai_chats
    FOR INSERT TO authenticated, anon
    WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT ON ai_chats TO anon;
GRANT SELECT, INSERT ON ai_chats TO authenticated;

-- Create notification function (for inserting)
CREATE OR REPLACE FUNCTION create_notification(
    recipient_email TEXT,
    notification_title TEXT,
    notification_content TEXT
)
RETURNS UUID AS $$
DECLARE
    new_id UUID;
BEGIN
    INSERT INTO ai_chats (user_email, title, conversation_data, created_at)
    VALUES (
        recipient_email,
        notification_title,
        jsonb_build_array(jsonb_build_object('role', 'assistant', 'content', notification_content)),
        NOW()
    )
    RETURNING id INTO new_id;
    RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get notifications for a user (for reading)
CREATE OR REPLACE FUNCTION get_user_notifications(user_email_param TEXT)
RETURNS TABLE (
    id UUID,
    user_email VARCHAR(255),
    title VARCHAR(500),
    conversation_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT ac.id, ac.user_email, ac.title, ac.conversation_data, ac.created_at
    FROM ai_chats ac
    WHERE ac.user_email = user_email_param
    ORDER BY ac.created_at DESC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_notification(TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION create_notification(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_notifications(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_user_notifications(TEXT) TO authenticated;
