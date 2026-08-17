-- Content reports and user blocking.
--
-- Required by App Store Review Guideline 1.2: an app carrying user-generated
-- content must let people report it and block the users posting it. RoomFinder
-- carries listings, roommate profiles and direct messages, so it qualifies.

CREATE TABLE IF NOT EXISTS public.content_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    -- Nullable: someone browsing logged-out must still be able to report.
    reporter_email TEXT,
    -- 'listing' | 'roommate_profile' | 'message' | 'sublease' | 'user'
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    details TEXT,
    -- 'pending' | 'reviewed' | 'actioned' | 'dismissed'
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ
);

-- The moderation queue is read by status and date, in that order.
CREATE INDEX IF NOT EXISTS idx_content_reports_status ON public.content_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_content_reports_target ON public.content_reports(target_type, target_id);

CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    blocker_email TEXT NOT NULL,
    blocked_email TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- Blocking twice is the same as blocking once; this makes the endpoint
    -- idempotent so a double tap cannot pile up rows.
    UNIQUE (blocker_email, blocked_email)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON public.blocked_users(blocker_email);

-- Both tables are written only through the backend using the service key, so
-- RLS is enabled with no permissive policy: the anon key cannot read anyone's
-- block list or the reports filed against them.
ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
