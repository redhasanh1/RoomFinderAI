-- Device tokens for Apple push notifications.
--
-- The iOS app registered for remote notifications, computed a token, and then
-- had nowhere to put it, so nothing was ever delivered to a phone. This is the
-- missing store.
--
-- The token is the primary key, not the email: a row follows the DEVICE, and
-- whoever last signed in on it owns it. Keying on email instead would leave a
-- shared or resold phone receiving the previous owner's messages.

CREATE TABLE IF NOT EXISTS device_tokens (
    token       TEXT PRIMARY KEY,
    user_email  TEXT NOT NULL,
    -- Sandbox and production APNs are different hosts and a token minted for
    -- one is rejected by the other, so the app tells us which build it is.
    environment TEXT NOT NULL DEFAULT 'production'
                CHECK (environment IN ('production', 'development')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Every send starts with "which devices does this person have?".
CREATE INDEX IF NOT EXISTS device_tokens_user_email_idx
    ON device_tokens (LOWER(user_email));

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- No browser access at all. Registration and delivery both run server-side
-- through the service key, and a device token readable with the anon key would
-- let anyone enumerate which addresses own which phones.
DROP POLICY IF EXISTS "No client access to device tokens" ON device_tokens;
CREATE POLICY "No client access to device tokens" ON device_tokens
    FOR ALL TO authenticated, anon
    USING (false)
    WITH CHECK (false);
