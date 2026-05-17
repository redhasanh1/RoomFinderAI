-- Auto-create a public.profiles row whenever auth.users gets a new entry.
--
-- Why this exists: signups can land in auth.users (Supabase Auth) without going
-- through the app's signup endpoint that writes to public.profiles. When that
-- happened, the user was effectively orphaned:
--   * signup said "email already registered" (auth.users row blocks it)
--   * forgot-password said nothing (no profile row, hits the anti-enumeration
--     silent-200 path, no email is sent)
--   * the user can't log in or recover access
-- One real example as of 2026-05-17: cryptocoins0@yahoo.com had been in
-- auth.users since 2025-08-05 with no profile and no email_confirmed_at. A snapshot
-- of all auth.users found 15 of 16 rows in this state.
--
-- The trigger below makes the data-drift impossible going forward. The companion
-- backfill statement (run once on 2026-05-17 via the Supabase management API)
-- repaired the existing 11 orphans by inserting profile rows for each.
--
-- Idempotent: re-running this file is safe. The function uses WHERE NOT EXISTS so
-- duplicate firings (or re-application after a manual profile insert) do nothing.
--
-- profile.user_id is left NULL because public.profiles.user_id is a FK to a
-- separate public.users table that's barely populated (1 row at audit time) and
-- we don't have a clean way to satisfy that constraint from here. The forgot-
-- password handler at backend/server.js:3528-3611 looks up profiles by email
-- only, so leaving user_id null is sufficient to unblock account recovery.

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
BEGIN
    INSERT INTO public.profiles (email, first_name, last_name, created_at)
    SELECT NEW.email,
           NEW.raw_user_meta_data->>'first_name',
           NEW.raw_user_meta_data->>'last_name',
           NEW.created_at
    WHERE NEW.email IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE email = NEW.email);
    RETURN NEW;
END;
$func$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_auth_user();

-- One-time backfill (also run on 2026-05-17, idempotent so re-running is safe):
INSERT INTO public.profiles (email, created_at)
SELECT u.email, u.created_at
FROM auth.users u
LEFT JOIN public.profiles p ON p.email = u.email
WHERE p.email IS NULL AND u.email IS NOT NULL;
