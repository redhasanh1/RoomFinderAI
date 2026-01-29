-- Create a function to insert notifications that bypasses RLS
-- This allows tenants to create notifications for landlords

-- Drop the function if it exists (to allow updates)
DROP FUNCTION IF EXISTS create_notification(TEXT, TEXT, TEXT);

-- Create the notification function with SECURITY DEFINER to bypass RLS
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

-- Grant execute permission to all users
GRANT EXECUTE ON FUNCTION create_notification(TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION create_notification(TEXT, TEXT, TEXT) TO authenticated;

-- Comment for documentation
COMMENT ON FUNCTION create_notification IS 'Creates a notification in ai_chats table for any user. Uses SECURITY DEFINER to bypass RLS, allowing tenants to create notifications for landlords.';
