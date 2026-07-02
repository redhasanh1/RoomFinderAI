-- =====================================================================
-- RoomFinderAI — Remove all test/demo seed data
-- =====================================================================
-- Deletes every row created by seed-test-data.sql. Identified by the
-- '@roomfinderai.test' email domain. Safe to run multiple times.
-- Run in: Supabase → SQL Editor.
-- =====================================================================

DO $$
BEGIN
    BEGIN DELETE FROM public.ai_negotiations   WHERE user_email LIKE 'seed.%@roomfinderai.test'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'skip ai_negotiations: %', SQLERRM; END;
    BEGIN DELETE FROM public.sublease_requests WHERE user_email LIKE 'seed.%@roomfinderai.test'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'skip sublease_requests: %', SQLERRM; END;
    BEGIN DELETE FROM public.roommate_profiles WHERE user_email LIKE 'seed.%@roomfinderai.test'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'skip roommate_profiles: %', SQLERRM; END;
    BEGIN DELETE FROM public.listings          WHERE user_email LIKE 'seed.%@roomfinderai.test'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'skip listings: %', SQLERRM; END;
    BEGIN DELETE FROM public.profiles          WHERE email      LIKE 'seed.%@roomfinderai.test'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'skip profiles: %', SQLERRM; END;
    BEGIN DELETE FROM public.users             WHERE email      LIKE 'seed.%@roomfinderai.test'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'skip users: %', SQLERRM; END;
    RAISE NOTICE '🧹 Seed data cleanup complete.';
END $$;
