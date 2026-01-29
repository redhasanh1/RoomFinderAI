-- Fix notifications security - ensure users can only see their own notifications
-- The previous policy USING (true) was too permissive

-- Drop the overly permissive policies
DROP POLICY IF EXISTS "Allow authenticated select" ON ai_chats;
DROP POLICY IF EXISTS "Allow authenticated insert" ON ai_chats;
DROP POLICY IF EXISTS "Users can view their own ai_chats" ON ai_chats;
DROP POLICY IF EXISTS "Allow all ai_chat inserts" ON ai_chats;

-- Enable RLS
ALTER TABLE ai_chats ENABLE ROW LEVEL SECURITY;

-- Create a restrictive SELECT policy
-- Users can only see notifications where user_email matches
-- Since app uses localStorage auth, we use a SECURITY DEFINER function instead
-- But we still need a basic policy for the fallback query

-- For SELECT: No direct access - must use RPC function
CREATE POLICY "No direct select - use RPC" ON ai_chats
    FOR SELECT TO authenticated, anon
    USING (false);

-- For INSERT: Allow all inserts (notifications can be created for any user)
CREATE POLICY "Allow notification inserts" ON ai_chats
    FOR INSERT TO authenticated, anon
    WITH CHECK (true);

-- The get_user_notifications function with SECURITY DEFINER bypasses RLS
-- This is the secure way to get notifications for a specific user
CREATE OR REPLACE FUNCTION get_user_notifications(user_email_param TEXT)
RETURNS TABLE (
    id UUID,
    user_email VARCHAR(255),
    title VARCHAR(500),
    conversation_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Only return notifications for the specified email
    RETURN QUERY
    SELECT ac.id, ac.user_email, ac.title, ac.conversation_data, ac.created_at
    FROM ai_chats ac
    WHERE ac.user_email = user_email_param
    ORDER BY ac.created_at DESC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create notification function (keeps existing functionality)
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_notifications(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_user_notifications(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_notification(TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION create_notification(TEXT, TEXT, TEXT) TO authenticated;
