-- Stop the browser key from reading personal details out of profiles.
--
-- The anon key ships in the page source, so anything it can read is public.
-- It could read every column of all 30 profiles: email, full name, phone,
-- date of birth, gender, occupation, bio, and street/city/postcode. On a
-- rental site a home address and phone number next to a real name is the
-- worst possible combination to hand out.
--
-- Column privileges rather than RLS, deliberately. The app identifies people
-- by an email in localStorage and does not reliably hold a real Supabase
-- session, so an RLS policy keyed on auth.uid() would lock legitimate users
-- out of their own profile. Column grants cut the sensitive data off without
-- depending on a session existing.
--
-- The server is unaffected: it uses the service role, which bypasses both.

REVOKE SELECT ON public.profiles FROM anon, authenticated;

-- What is left is what the UI genuinely renders: who someone is, their
-- avatar, and their plan.
GRANT SELECT (
    id,
    email,
    first_name,
    last_name,
    profile_image,
    profile_image_url,
    user_id,
    is_pro,
    plan,
    created_at,
    updated_at
) ON public.profiles TO anon, authenticated;

-- Writes are untouched: the site still creates and updates a profile from the
-- browser, and narrowing that is a separate change with its own blast radius.

-- NOTE: `email` is still readable, so the table can still be enumerated for
-- addresses. Closing that means moving profile reads behind the server the way
-- messaging.js already does, because several pages look up another person's
-- profile by email to show their name. Tracked separately.
