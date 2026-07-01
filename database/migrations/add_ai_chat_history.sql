-- Persist the user's AI Negotiator chat history across sessions.
--
-- Background: frontend/ai-chat.js had loadConversationHistory / saveConversationHistory
-- stubbed out with `return;` because this table didn't exist. Each session
-- started fresh. This migration creates the table; the same commit re-enables
-- the save/load functions so the UI restores the prior chat on every page load.
--
-- Schema: one row per user (PK is user_email), full chat as a JSONB array.
-- That keeps reads to a single PK lookup and writes to a single upsert. Cap
-- enforced client-side at ~200 messages so the row can't grow unbounded.
--
-- Idempotent: CREATE TABLE IF NOT EXISTS + DROP POLICY IF EXISTS pattern, so
-- re-running this migration is safe.

CREATE TABLE IF NOT EXISTS public.ai_chat_history (
    user_email text PRIMARY KEY,
    messages   jsonb NOT NULL DEFAULT '[]'::jsonb,
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ai_chat_history ENABLE ROW LEVEL SECURITY;

-- Users can read/write their own row, gated on the Supabase Auth JWT email.
DROP POLICY IF EXISTS ai_chat_history_self_read ON public.ai_chat_history;
CREATE POLICY ai_chat_history_self_read
    ON public.ai_chat_history FOR SELECT TO authenticated
    USING (auth.jwt() ->> 'email' = user_email);

DROP POLICY IF EXISTS ai_chat_history_self_write ON public.ai_chat_history;
CREATE POLICY ai_chat_history_self_write
    ON public.ai_chat_history FOR INSERT TO authenticated
    WITH CHECK (auth.jwt() ->> 'email' = user_email);

DROP POLICY IF EXISTS ai_chat_history_self_update ON public.ai_chat_history;
CREATE POLICY ai_chat_history_self_update
    ON public.ai_chat_history FOR UPDATE TO authenticated
    USING (auth.jwt() ->> 'email' = user_email)
    WITH CHECK (auth.jwt() ->> 'email' = user_email);

DROP POLICY IF EXISTS ai_chat_history_self_delete ON public.ai_chat_history;
CREATE POLICY ai_chat_history_self_delete
    ON public.ai_chat_history FOR DELETE TO authenticated
    USING (auth.jwt() ->> 'email' = user_email);
