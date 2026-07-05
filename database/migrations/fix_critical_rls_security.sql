-- Phase 0 security remediation (RoomFinderAI - Full End-to-End Audit & Remediation Plan)
--
-- Background: backend/server.js connects to Supabase using SUPABASE_SERVICE_ROLE_KEY
-- (confirmed present in .env), which bypasses RLS entirely. That means every policy
-- below only governs direct browser/anon-key access -- tightening these does not
-- break any backend write path.
--
-- Run this whole file once in the Supabase SQL editor (or via `psql`).

-- =====================================================================
-- 1) user_verifications -- currently "FOR ALL WITH CHECK (true)", meaning
--    any client can PATCH their own (or anyone else's) verification status
--    directly, bypassing actual ID/face verification. This is an account-
--    verification bypass and is the highest-priority fix in the whole audit.
-- =====================================================================
DROP POLICY IF EXISTS "System can manage user verifications" ON user_verifications;
DROP POLICY IF EXISTS "Users can view their own verification status" ON user_verifications;

-- Read-only for the owning user; no client INSERT/UPDATE/DELETE policy is
-- created at all, so those default-deny for anon/authenticated. All writes
-- must go through the backend's service-role client (/api/verify/upload-id,
-- /api/verify/face-match, /api/admin/verify-user).
CREATE POLICY "Users can view their own verification status" ON user_verifications
    FOR SELECT USING (user_email = auth.email());

-- =====================================================================
-- 2) subscriptions -- currently USING(true) for SELECT/INSERT/UPDATE,
--    meaning any client can view or alter any user's plan/status.
-- =====================================================================
DROP POLICY IF EXISTS "Anyone can insert subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Anyone can view subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Anyone can update subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Users can view own subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Users can insert own subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Users can update own subscriptions" ON subscriptions;

-- Read-only for the owning user. No client INSERT/UPDATE policy -- plan/status
-- changes should only ever happen server-side (checkout webhook, cancel route).
CREATE POLICY "Users can view own subscriptions" ON subscriptions
    FOR SELECT USING (auth.email() = email);

-- =====================================================================
-- 3) sublease_requests / sublease_matches / sublease_transfers -- currently
--    "Allow all authenticated users" with FOR ALL USING (auth.role() = 'authenticated'),
--    i.e. any logged-in user can read/update/delete any other user's sublease
--    data. Restore participant-scoped policies (originally present in
--    sublease_matching_schema.sql before fix_rls_policies.sql stripped them),
--    using auth.email() instead of the fragile current_setting() session-var
--    pattern (which silently denies everything if the app forgets to call
--    set_user_context() first).
-- =====================================================================
DROP POLICY IF EXISTS "Allow all authenticated users" ON sublease_requests;
DROP POLICY IF EXISTS "Allow all authenticated users" ON sublease_matches;
DROP POLICY IF EXISTS "Allow all authenticated users" ON sublease_transfers;

CREATE POLICY "Users can view own sublease requests" ON sublease_requests
    FOR SELECT USING (user_email = auth.email());
CREATE POLICY "Users can insert own sublease requests" ON sublease_requests
    FOR INSERT WITH CHECK (user_email = auth.email());
CREATE POLICY "Users can update own sublease requests" ON sublease_requests
    FOR UPDATE USING (user_email = auth.email());
CREATE POLICY "Users can delete own sublease requests" ON sublease_requests
    FOR DELETE USING (user_email = auth.email());

CREATE POLICY "Users can view matches for their requests" ON sublease_matches
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM sublease_requests sr
            WHERE sr.id = sublease_matches.transfer_request_id
            AND sr.user_email = auth.email()
        ) OR EXISTS (
            SELECT 1 FROM sublease_requests sr
            WHERE sr.id = sublease_matches.seeking_request_id
            AND sr.user_email = auth.email()
        )
    );
CREATE POLICY "Users can update matches for their requests" ON sublease_matches
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM sublease_requests sr
            WHERE sr.id = sublease_matches.transfer_request_id
            AND sr.user_email = auth.email()
        ) OR EXISTS (
            SELECT 1 FROM sublease_requests sr
            WHERE sr.id = sublease_matches.seeking_request_id
            AND sr.user_email = auth.email()
        )
    );

CREATE POLICY "Users can view their transfers" ON sublease_transfers
    FOR SELECT USING (
        transferor_email = auth.email() OR transferee_email = auth.email()
    );
CREATE POLICY "Users can update their transfers" ON sublease_transfers
    FOR UPDATE USING (
        transferor_email = auth.email() OR transferee_email = auth.email()
    );

-- =====================================================================
-- 4) roommate_conversations / roommate_messages -- RLS was enabled with
--    zero policies (default-deny for anon/authenticated). Add participant-
--    scoped access so the client can actually read/send roommate messages
--    directly (used by frontend/js/roommate-api.js, which authenticates via
--    supabase.auth and uses auth.uid() as user1_id/user2_id/sender_id).
-- =====================================================================
DROP POLICY IF EXISTS "Participants can view their conversations" ON roommate_conversations;
DROP POLICY IF EXISTS "Participants can create conversations" ON roommate_conversations;
DROP POLICY IF EXISTS "Participants can view their messages" ON roommate_messages;
DROP POLICY IF EXISTS "Participants can send messages" ON roommate_messages;

CREATE POLICY "Participants can view their conversations" ON roommate_conversations
    FOR SELECT USING (auth.uid() = user1_id OR auth.uid() = user2_id);
CREATE POLICY "Participants can create conversations" ON roommate_conversations
    FOR INSERT WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "Participants can view their messages" ON roommate_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM roommate_conversations c
            WHERE c.id = roommate_messages.conversation_id
            AND (auth.uid() = c.user1_id OR auth.uid() = c.user2_id)
        )
    );
CREATE POLICY "Participants can send messages" ON roommate_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND EXISTS (
            SELECT 1 FROM roommate_conversations c
            WHERE c.id = roommate_messages.conversation_id
            AND (auth.uid() = c.user1_id OR auth.uid() = c.user2_id)
        )
    );

-- =====================================================================
-- 5) listings -- RLS is deliberately DISABLED (see disable_listings_rls.sql,
--    comment: "auth handled at the application level"). Not re-enabled here
--    on purpose -- Phase 3 of the remediation plan moves listing creation
--    behind the backend's service-role client with real server-side
--    validation instead of relying on DB-level RLS for this table.
-- =====================================================================
