-- Close the private-message leak on `conversations` and `messages`.
--
-- ============================================================================
--  DO NOT RUN THIS YET. Read this header first.
-- ============================================================================
--
-- Applying this before every login path issues a real Supabase session will
-- take messaging down for everyone still holding a made-up token. That is not
-- a hypothetical: as of 2026-09-04 three login paths still mint their own
-- strings, and any account holding one has no auth.uid() and no JWT email, so
-- every policy below evaluates false for them.
--
-- WHY IT IS NEEDED
--
-- With nothing but the anon key that /api/config serves on every page load:
--
--     messages       200 READABLE   167 rows, including `content`
--     conversations  200 READABLE    17 rows, including `receiver_email`
--     profiles       401 correctly locked
--
-- `profiles` returning 401 is the proof that RLS works on this project. These
-- two tables were simply never given policies.
--
-- WHY IT CANNOT JUST BE SWITCHED ON
--
-- RealTimeChatService sent `Authorization: Bearer <ANON_KEY>` on all twelve of
-- its Supabase calls, so PostgREST saw every request as anonymous. The app did
-- not merely tolerate the open table - it depended on it.
--
-- PREREQUISITES, IN ORDER
--
--   1. DONE   The app sends the user's session token when it holds a real one
--             (RealTimeChatService.supabaseBearer, commit 1a575366).
--   2. WRITTEN, UNTESTED   Legacy password logins mint a real Auth session
--             (ensureRealSession, branch fix/real-sessions). Needs one run
--             against a real Supabase before it is trusted.
--   3. NOT STARTED   /api/auth/google-signin, /api/auth/verify-code and the
--             in-memory branch of /api/login still issue `token_<id>`. Google
--             users in particular will be locked out of messaging by this file
--             until that is fixed.
--   4. Only then: run this.
--
-- THE WEBSITE NEEDS NO CHANGE, WHICH IS NOT OBVIOUS
--
-- frontend/listings.html builds its client with the anon key and queries
-- `messages` directly, which looks like the same problem the app had. It is
-- not. login.html already calls UniversalAuth.applySupabaseSession() with the
-- tokens from /api/login, so the browser's client becomes authenticated - but
-- only behind this guard (login.html:417):
--
--     if (... && result.refresh_token) {
--
-- The legacy password branch never returned a refresh_token, so for exactly the
-- accounts this migration would lock out, that line never ran and the browser
-- stayed anonymous. ensureRealSession now returns one, so those sessions start
-- applying on the web the moment step 2 ships. The guard was already correct
-- and waiting for a value nothing supplied.
--
-- Consequence: fixing the server fixes both clients. Nothing in frontend/ needs
-- editing for this migration - but step 2 must ship first, or the website is
-- locked out alongside the app.
--
-- HOW TO CHECK BEFORE RUNNING
--
-- Every active account must appear in auth.users. Anyone in `profiles` but not
-- in auth.users is still on a fake token and will lose messaging:
--
--     SELECT p.email
--       FROM public.profiles p
--       LEFT JOIN auth.users u ON lower(u.email) = lower(p.email)
--      WHERE u.id IS NULL;
--
-- An empty result means it is safe to proceed.
--
-- IDENTITY MODEL
--
-- Participants are identified by email, not by user id: `conversations` carries
-- sender_email and receiver_email (landlord_id and tenant_id exist but are not
-- reliably populated). So the policies key on auth.jwt() ->> 'email', matching
-- the convention already used across database/migrations.
--
-- Comparisons are lower()ed on both sides. Email is case-insensitive in
-- practice and a row stored with different casing would otherwise silently
-- become unreadable by its own participant.

BEGIN;

-- ---------------------------------------------------------------- conversations

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS conversations_select_participant ON public.conversations;
CREATE POLICY conversations_select_participant
    ON public.conversations
    FOR SELECT
    TO authenticated
    USING (
        lower(auth.jwt() ->> 'email') IN (lower(sender_email), lower(receiver_email))
    );

-- A conversation may only be opened in your own name. Without this check
-- anyone could create a thread that appears to come from somebody else.
DROP POLICY IF EXISTS conversations_insert_as_self ON public.conversations;
CREATE POLICY conversations_insert_as_self
    ON public.conversations
    FOR INSERT
    TO authenticated
    WITH CHECK (
        lower(auth.jwt() ->> 'email') = lower(sender_email)
    );

-- Participants update their own read markers (last_read_at,
-- sender_last_read_at, receiver_last_read_at). WITH CHECK repeats the USING
-- condition so a row cannot be updated into somebody else's conversation.
DROP POLICY IF EXISTS conversations_update_participant ON public.conversations;
CREATE POLICY conversations_update_participant
    ON public.conversations
    FOR UPDATE
    TO authenticated
    USING (
        lower(auth.jwt() ->> 'email') IN (lower(sender_email), lower(receiver_email))
    )
    WITH CHECK (
        lower(auth.jwt() ->> 'email') IN (lower(sender_email), lower(receiver_email))
    );

-- Deliberately no DELETE policy. Nothing in the app deletes a conversation, and
-- a missing policy denies rather than permits.

-- --------------------------------------------------------------------- messages

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- A message is visible when you are a participant in its conversation. Note
-- this is NOT `sender_email = me` - that would hide the replies, which is the
-- half of the thread you actually want.
DROP POLICY IF EXISTS messages_select_participant ON public.messages;
CREATE POLICY messages_select_participant
    ON public.messages
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
              FROM public.conversations c
             WHERE c.id = messages.conversation_id
               AND lower(auth.jwt() ->> 'email')
                   IN (lower(c.sender_email), lower(c.receiver_email))
        )
    );

-- Sending requires both that the message is in your own name and that you are
-- in the conversation. The first alone would let anyone post into any thread;
-- the second alone would let you post as somebody else in your own thread.
DROP POLICY IF EXISTS messages_insert_as_participant ON public.messages;
CREATE POLICY messages_insert_as_participant
    ON public.messages
    FOR INSERT
    TO authenticated
    WITH CHECK (
        lower(auth.jwt() ->> 'email') = lower(sender_email)
        AND EXISTS (
            SELECT 1
              FROM public.conversations c
             WHERE c.id = messages.conversation_id
               AND lower(auth.jwt() ->> 'email')
                   IN (lower(c.sender_email), lower(c.receiver_email))
        )
    );

-- Marking as read (is_read, read_at) is an update by the recipient, so this is
-- scoped to participants rather than to the sender.
DROP POLICY IF EXISTS messages_update_participant ON public.messages;
CREATE POLICY messages_update_participant
    ON public.messages
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
              FROM public.conversations c
             WHERE c.id = messages.conversation_id
               AND lower(auth.jwt() ->> 'email')
                   IN (lower(c.sender_email), lower(c.receiver_email))
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
              FROM public.conversations c
             WHERE c.id = messages.conversation_id
               AND lower(auth.jwt() ->> 'email')
                   IN (lower(c.sender_email), lower(c.receiver_email))
        )
    );

-- Indexes the policies lean on. The messages SELECT policy runs the EXISTS
-- subquery per row, so conversation_id wants an index or long threads get slow.
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id
    ON public.messages (conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversations_sender_email
    ON public.conversations (lower(sender_email));
CREATE INDEX IF NOT EXISTS idx_conversations_receiver_email
    ON public.conversations (lower(receiver_email));

COMMIT;

-- ============================================================================
--  VERIFY AFTER RUNNING
-- ============================================================================
--
-- 1. The anon key must now get nothing. From a shell:
--
--      KEY=$(curl -s https://www.roomfinderai.com/api/config \
--            | python -c "import sys,json;print(json.load(sys.stdin)['SUPABASE_ANON_KEY'])")
--      curl -s "https://fkktwhjybuflxqzopaex.supabase.co/rest/v1/messages?select=id&limit=1" \
--           -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
--
--    Expect [] - an empty array, not rows. Before this migration it returned
--    real ids.
--
-- 2. A signed-in user must still see their own thread. In the app: open
--    Messages, confirm existing conversations load and a new message sends.
--    Do this on an account that logged in AFTER ensureRealSession shipped,
--    otherwise you are testing a fake token and it will fail for that reason
--    rather than because the policy is wrong.
--
-- 3. Confirm the policies are actually attached:
--
--      SELECT tablename, policyname, cmd
--        FROM pg_policies
--       WHERE schemaname = 'public'
--         AND tablename IN ('messages', 'conversations')
--       ORDER BY tablename, cmd;
--
-- ============================================================================
--  ROLLBACK
-- ============================================================================
--
-- If messaging breaks and the cause is not obvious, this restores the previous
-- behaviour immediately. It also restores the leak, so treat it as a way to buy
-- an hour, not as a resting state.
--
--     ALTER TABLE public.messages      DISABLE ROW LEVEL SECURITY;
--     ALTER TABLE public.conversations DISABLE ROW LEVEL SECURITY;
--
-- ============================================================================
--  NOT COVERED HERE
-- ============================================================================
--
-- `roommate_profiles` is also readable by the anon key (9 rows: bios, budgets,
-- lifestyle). It is left alone deliberately - a roommate directory may well be
-- meant to be browsable by signed-out visitors, and that is a product decision
-- rather than a bug. Worth an explicit answer either way, because right now it
-- is open by default rather than by choice.
