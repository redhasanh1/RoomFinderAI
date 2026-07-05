-- Phase 1 (RoomFinderAI - Full End-to-End Audit & Remediation Plan)
--
-- roommate_profiles has no CREATE TABLE in this repo (it was created directly
-- in the Supabase dashboard) and has no unique constraint on (user_id, user_type).
-- Without it, saveSeekerProfile()'s upsert (frontend/js/roommate-api.js) can
-- accumulate duplicate rows per user/type instead of updating the existing one.
--
-- Run this once in the Supabase SQL editor. If duplicate rows already exist,
-- the ADD CONSTRAINT will fail -- in that case, de-duplicate first by keeping
-- only the most recently updated row per (user_id, user_type).

-- Safety check: surface any existing duplicates before the constraint is added.
DO $$
DECLARE
    dup_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO dup_count FROM (
        SELECT user_id, user_type
        FROM roommate_profiles
        GROUP BY user_id, user_type
        HAVING COUNT(*) > 1
    ) d;

    IF dup_count > 0 THEN
        RAISE NOTICE 'Found % (user_id, user_type) pairs with duplicate roommate_profiles rows -- de-duplicate before this migration can add the unique constraint.', dup_count;
    END IF;
END $$;

ALTER TABLE roommate_profiles
    ADD CONSTRAINT roommate_profiles_user_id_user_type_key UNIQUE (user_id, user_type);
