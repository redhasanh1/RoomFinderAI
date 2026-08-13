-- Sublease interest + messaging support.
--
-- Applied to the live database on 2026-08-13. Kept here so the schema is
-- reproducible.
--
-- Why: "Express interest" used to route through the compatibility matcher. With
-- no opposite-type request of your own it fabricated a throwaway request row,
-- then required findAndCreateMatches() to produce a match — but that helper only
-- inserts above a score of 30, and a same-city pair with only city/state/rent
-- scores exactly 30. Every such click returned 500 "Could not create match
-- record" and left junk behind. Interest is now its own fact.

CREATE TABLE IF NOT EXISTS public.sublease_interests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    request_id UUID NOT NULL REFERENCES public.sublease_requests(id) ON DELETE CASCADE,
    interested_email TEXT NOT NULL,
    owner_email TEXT NOT NULL,
    conversation_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- Makes repeat clicks idempotent instead of piling up duplicates.
    UNIQUE (request_id, interested_email)
);

CREATE INDEX IF NOT EXISTS idx_sublease_interests_owner ON public.sublease_interests(owner_email);
CREATE INDEX IF NOT EXISTS idx_sublease_interests_req ON public.sublease_interests(request_id);

-- Distinguishes sublease threads from listing threads in the shared inbox.
-- Existing rows default to 'listing', so nothing changes for current chats.
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS context TEXT DEFAULT 'listing';

-- conversations.listing_id previously had a FK to listings(id), which made it
-- impossible to open a thread about a sublease_request. The column is now a
-- polymorphic reference disambiguated by `context`, so the constraint has to go.
--
-- TRADE-OFF: the old constraint was ON DELETE CASCADE, so deleting a listing
-- also removed its conversations. That no longer happens automatically —
-- deleting a listing or sublease request leaves its conversations behind.
-- Clean-up is now the application's responsibility.
ALTER TABLE public.conversations DROP CONSTRAINT IF EXISTS conversations_listing_id_fkey;
