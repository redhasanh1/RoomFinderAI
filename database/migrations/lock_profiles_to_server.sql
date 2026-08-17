-- Take the profiles table away from the browser key entirely.
--
-- restrict_profiles_columns.sql cut off the sensitive columns but had to leave
-- `email` readable, because every page filtered on it and Postgres needs SELECT
-- on a column to use it in a WHERE clause. That left the table enumerable: one
-- request returned all 30 addresses.
--
-- The pages now go through /api/profiles/me, /api/profiles/display and
-- /api/profiles/ensure, each of which answers about exactly one address and
-- cannot return a set of people. So the browser needs nothing here at all.
--
-- Run AFTER the frontend that uses those endpoints is deployed. Doing it first
-- breaks profile loading for the window in between.

REVOKE SELECT, INSERT, UPDATE, DELETE ON public.profiles FROM anon, authenticated;

-- RLS as well as the grants. Belt and braces: if a future migration hands the
-- table back to `anon` with a broad GRANT, this policy still denies every row,
-- so the leak cannot silently come back.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "No direct client access to profiles" ON public.profiles;
CREATE POLICY "No direct client access to profiles" ON public.profiles
    FOR ALL TO anon, authenticated
    USING (false)
    WITH CHECK (false);

-- The server is unaffected: it connects as the service role, which bypasses
-- both grants and RLS.
