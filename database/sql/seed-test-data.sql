-- =====================================================================
-- RoomFinderAI — Test / Demo Seed Data
-- =====================================================================
-- Purpose: populate every user-facing feature with realistic sample data
-- so you can verify listings, map, student housing, favorites, sublease,
-- RoomPal, and the AI negotiator end-to-end.
--
-- SAFE TO RE-RUN: every section first deletes its own seed rows
-- (identified by the '@roomfinderai.test' email domain) and is wrapped in
-- an exception guard, so a missing table or a schema difference only skips
-- that one section instead of aborting the whole script.
--
-- Run in: Supabase → SQL Editor (paste whole file, Run).
-- To remove all seed data later, run database/sql/seed-test-data-cleanup.sql
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. AI negotiations table (used by POST /api/ai-negotiate for history)
--    The backend inserts here; the table was missing from migrations, so
--    create it now. Service-role (backend) writes; users read their own.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_negotiations (
    id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_email    TEXT NOT NULL,
    user_message  TEXT,
    ai_response   TEXT,
    session_type  TEXT DEFAULT 'negotiation_assistant',
    listing_details JSONB DEFAULT '{}'::jsonb,
    provider      TEXT,
    tokens_used   INTEGER DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_negotiations_user_email ON public.ai_negotiations(user_email);
CREATE INDEX IF NOT EXISTS idx_ai_negotiations_created_at ON public.ai_negotiations(created_at DESC);


-- ---------------------------------------------------------------------
-- 1. Make sure the listings map columns exist (idempotent)
-- ---------------------------------------------------------------------
ALTER TABLE public.listings
    ADD COLUMN IF NOT EXISTS latitude    DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude   DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS geocoded_at TIMESTAMPTZ;


-- ---------------------------------------------------------------------
-- 2. Seed owner users (only if a `users` table with these columns exists).
--    listings.user_email may FK to users(email); insert owners first so the
--    listing inserts below never violate a foreign key.
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.users') IS NOT NULL THEN
        INSERT INTO public.users (first_name, last_name, email, password_hash, profile_image)
        VALUES
            ('Alex',  'Morgan',  'seed.alex@roomfinderai.test',  'seed-not-a-real-hash', 'https://i.pravatar.cc/100?img=12'),
            ('Maria', 'Santos',  'seed.maria@roomfinderai.test', 'seed-not-a-real-hash', 'https://i.pravatar.cc/100?img=45'),
            ('James', 'Chen',    'seed.james@roomfinderai.test', 'seed-not-a-real-hash', 'https://i.pravatar.cc/100?img=33'),
            ('Priya', 'Sharma',  'seed.priya@roomfinderai.test', 'seed-not-a-real-hash', 'https://i.pravatar.cc/100?img=47')
        ON CONFLICT (email) DO NOTHING;
        RAISE NOTICE '✅ Seed users inserted (or already present)';
    ELSE
        RAISE NOTICE 'ℹ️ No public.users table — skipping user seed (listings have no users FK)';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Seed users skipped: %', SQLERRM;
END $$;

-- Mirror into a `profiles` table too, if that is what the app uses.
DO $$
BEGIN
    IF to_regclass('public.profiles') IS NOT NULL THEN
        BEGIN
            INSERT INTO public.profiles (email, full_name)
            VALUES
                ('seed.alex@roomfinderai.test',  'Alex Morgan'),
                ('seed.maria@roomfinderai.test', 'Maria Santos'),
                ('seed.james@roomfinderai.test', 'James Chen'),
                ('seed.priya@roomfinderai.test', 'Priya Sharma')
            ON CONFLICT (email) DO NOTHING;
            RAISE NOTICE '✅ Seed profiles inserted (or already present)';
        EXCEPTION WHEN undefined_column THEN
            RAISE NOTICE 'ℹ️ profiles table has different columns — skipping profile seed';
        END;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Seed profiles skipped: %', SQLERRM;
END $$;


-- ---------------------------------------------------------------------
-- 3. Seed LISTINGS (powers homepage, /listings, map, student housing,
--    favorites, and gives the AI negotiator real inventory to reference).
-- ---------------------------------------------------------------------
DO $$
BEGIN
    DELETE FROM public.listings WHERE user_email LIKE 'seed.%@roomfinderai.test';

    INSERT INTO public.listings
        (title, price, city, street, postal_code, house_type, bedrooms, utilities, description, media, user_email, latitude, longitude, geocoded_at)
    VALUES
        ('Bright Downtown Condo Near Union Station', 2150, 'Toronto', '88 Harbour St', 'M5J 0C3', 'Condo', 1, 'Included',
         'Sun-filled 1-bed condo steps from the waterfront, gym and 24/7 concierge. Perfect for young professionals.',
         '[{"url":"https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&q=80","type":"image/jpeg","name":"condo1.jpg"}]'::jsonb,
         'seed.alex@roomfinderai.test', 43.6420, -79.3760, now()),

        ('Cozy 2-Bed Apartment in The Annex', 2650, 'Toronto', '412 Bloor St W', 'M5S 1X6', 'Apartment', 2, 'Not included',
         'Charming 2-bedroom near U of T with hardwood floors, updated kitchen and a quiet leafy street.',
         '[{"url":"https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800&q=80","type":"image/jpeg","name":"apt-annex.jpg"}]'::jsonb,
         'seed.maria@roomfinderai.test', 43.6656, -79.4070, now()),

        ('Modern Studio for Students - Waterloo', 1250, 'Waterloo', '256 Phillip St', 'N2L 6B6', 'Apartment', 0, 'Included',
         'Fully furnished student studio a 5-minute walk to the University of Waterloo. All utilities and WiFi included.',
         '[{"url":"https://images.unsplash.com/photo-1554995207-c18c203602cb?w=800&q=80","type":"image/jpeg","name":"studio-waterloo.jpg"}]'::jsonb,
         'seed.james@roomfinderai.test', 43.4723, -80.5449, now()),

        ('Spacious 3-Bed Townhouse in Mississauga', 3200, 'Mississauga', '55 Eglinton Ave W', 'L5R 3E7', 'Townhouse', 3, 'Not included',
         'Family-friendly 3-bed townhouse with garage, finished basement and backyard. Close to Square One.',
         '[{"url":"https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800&q=80","type":"image/jpeg","name":"townhouse.jpg"}]'::jsonb,
         'seed.priya@roomfinderai.test', 43.5890, -79.6441, now()),

        ('Luxury 1-Bed with Mountain View - Vancouver', 2450, 'Vancouver', '1200 Georgia St W', 'V6E 4R2', 'Condo', 1, 'Included',
         'Stunning downtown Vancouver condo with floor-to-ceiling windows and mountain views. Steps to Stanley Park.',
         '[{"url":"https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800&q=80","type":"image/jpeg","name":"van-condo.jpg"}]'::jsonb,
         'seed.alex@roomfinderai.test', 49.2870, -123.1300, now()),

        ('Charming Plateau Apartment - Montreal', 1650, 'Montreal', '4200 Rue Saint-Denis', 'H2J 2K9', 'Apartment', 2, 'Not included',
         'Classic Montreal 2-bed on the Plateau with exposed brick, spiral staircase and a balcony. Great cafes nearby.',
         '[{"url":"https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800&q=80","type":"image/jpeg","name":"mtl-apt.jpg"}]'::jsonb,
         'seed.maria@roomfinderai.test', 45.5230, -73.5810, now()),

        ('Quiet Detached House Near Carleton - Ottawa', 2800, 'Ottawa', '1125 Colonel By Dr', 'K1S 5B6', 'House', 4, 'Not included',
         'Roomy 4-bedroom detached house ideal for a group of students or a family. Minutes from Carleton University.',
         '[{"url":"https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800&q=80","type":"image/jpeg","name":"ottawa-house.jpg"}]'::jsonb,
         'seed.james@roomfinderai.test', 45.3870, -75.6960, now()),

        ('Affordable Room in Shared Condo - Calgary', 950, 'Calgary', '500 Eau Claire Ave SW', 'T2P 3R8', 'Condo', 1, 'Included',
         'Private room in a friendly shared downtown Calgary condo. Utilities, internet and in-suite laundry included.',
         '[{"url":"https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800&q=80","type":"image/jpeg","name":"calgary-room.jpg"}]'::jsonb,
         'seed.priya@roomfinderai.test', 51.0530, -114.0720, now()),

        ('Renovated 2-Bed Near Yorkdale - Toronto', 2400, 'Toronto', '3401 Dufferin St', 'M6A 2T9', 'Apartment', 2, 'Included',
         'Freshly renovated 2-bed with stainless appliances and subway access. Steps from Yorkdale Mall.',
         '[{"url":"https://images.unsplash.com/photo-1567767292278-a4f21aa2d36e?w=800&q=80","type":"image/jpeg","name":"yorkdale.jpg"}]'::jsonb,
         'seed.alex@roomfinderai.test', 43.7250, -79.4520, now()),

        ('Student House Steps from Western - London', 1100, 'London', '1151 Richmond St', 'N6A 3K7', 'House', 5, 'Not included',
         'Five-bedroom student house right by Western University. Big common area, two bathrooms, parking for three.',
         '[{"url":"https://images.unsplash.com/photo-1576941089067-2de3c901e126?w=800&q=80","type":"image/jpeg","name":"london-house.jpg"}]'::jsonb,
         'seed.maria@roomfinderai.test', 43.0090, -81.2730, now()),

        ('Sleek Studio in Griffintown - Montreal', 1400, 'Montreal', '1010 Rue William', 'H3C 1P3', 'Condo', 0, 'Included',
         'Brand-new studio in trendy Griffintown with rooftop pool, gym and co-working lounge. Utilities included.',
         '[{"url":"https://images.unsplash.com/photo-1502005229762-cf1b2da7c5d6?w=800&q=80","type":"image/jpeg","name":"griffintown.jpg"}]'::jsonb,
         'seed.james@roomfinderai.test', 45.4940, -73.5590, now()),

        ('Family Home with Backyard - Surrey', 2900, 'Surrey', '10800 King George Blvd', 'V3T 2X6', 'House', 4, 'Not included',
         'Spacious 4-bed family home with fenced backyard, double garage and close to SkyTrain and schools.',
         '[{"url":"https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800&q=80","type":"image/jpeg","name":"surrey-home.jpg"}]'::jsonb,
         'seed.priya@roomfinderai.test', 49.1900, -122.8490, now());

    RAISE NOTICE '✅ Seed listings inserted (12 rows across 7 cities, with coordinates)';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Seed listings skipped: %', SQLERRM;
END $$;


-- ---------------------------------------------------------------------
-- 4. Seed SUBLEASE requests (powers /sublease.html — transfer + seeking).
-- ---------------------------------------------------------------------
DO $$
BEGIN
    DELETE FROM public.sublease_requests WHERE user_email LIKE 'seed.%@roomfinderai.test';

    INSERT INTO public.sublease_requests
        (user_email, type, status, title, description, address, city, state, zip_code,
         rent_amount, min_budget, max_budget, utilities_included, security_deposit,
         available_from, available_until, duration_months, flexible_dates,
         property_type, bedrooms, bathrooms, square_feet, furnished,
         amenities, pet_friendly, smoking_allowed, cleanliness_level, noise_tolerance, social_level,
         schedule_type, work_from_home, urgency_level, contact_method)
    VALUES
        ('seed.alex@roomfinderai.test', 'transfer', 'active',
         'Summer Sublet - Downtown Toronto 1BR', 'Leaving for a summer co-op, need someone to take over my lease May–Aug. Fully furnished.',
         '88 Harbour St', 'Toronto', 'ON', 'M5J 0C3',
         2150, NULL, NULL, true, 2150,
         '2026-05-01', '2026-08-31', 4, true,
         'condo', 1, 1.0, 620, true,
         '["gym","laundry","concierge","wifi"]'::jsonb, false, false, 4, 3, 3,
         'regular', true, 4, 'platform'),

        ('seed.maria@roomfinderai.test', 'seeking', 'active',
         'Grad Student Seeking 8-Month Sublet', 'Incoming grad student looking for a quiet furnished room near U of T, Sept–Apr.',
         NULL, 'Toronto', 'ON', NULL,
         NULL, 900, 1500, true, NULL,
         '2026-09-01', '2027-04-30', 8, true,
         'apartment', 1, 1.0, NULL, true,
         '["wifi","quiet","furnished"]'::jsonb, false, false, 5, 2, 2,
         'early_bird', true, 3, 'platform'),

        ('seed.james@roomfinderai.test', 'transfer', 'active',
         'Waterloo Co-op Term Sublet - Studio', 'Off for a Waterloo work term, subletting my furnished studio 5 min from campus.',
         '256 Phillip St', 'Waterloo', 'ON', 'N2L 6B6',
         1250, NULL, NULL, true, 1250,
         '2026-01-01', '2026-04-30', 4, false,
         'studio', 0, 1.0, 400, true,
         '["wifi","furnished","utilities"]'::jsonb, false, false, 4, 3, 3,
         'night_owl', true, 5, 'platform'),

        ('seed.priya@roomfinderai.test', 'seeking', 'active',
         'Young Professional Seeking Condo Sublet', 'Relocating for work, need a 1BR condo downtown for 6 months. Clean, non-smoker.',
         NULL, 'Vancouver', 'BC', NULL,
         NULL, 1800, 2600, false, NULL,
         '2026-06-01', '2026-12-01', 6, true,
         'condo', 1, 1.0, NULL, false,
         '["gym","parking","wifi"]'::jsonb, false, false, 5, 2, 3,
         'regular', true, 3, 'platform');

    RAISE NOTICE '✅ Seed sublease requests inserted (2 transfer + 2 seeking)';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Seed sublease requests skipped: %', SQLERRM;
END $$;


-- ---------------------------------------------------------------------
-- 5. Seed ROOMMATE (RoomPal) profiles — powers /roommate-matching.html.
--    The base table was created outside these migrations, so this section
--    is defensive: it tries the common column layout and skips cleanly if
--    the live schema differs.
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.roommate_profiles') IS NULL THEN
        RAISE NOTICE 'ℹ️ No roommate_profiles table — skipping RoomPal seed';
        RETURN;
    END IF;

    DELETE FROM public.roommate_profiles WHERE user_email LIKE 'seed.%@roomfinderai.test';

    INSERT INTO public.roommate_profiles
        (user_email, name, age, gender, occupation, bio, budget_min, budget_max, preferred_location, move_in_date, compatibility_scores)
    VALUES
        ('seed.alex@roomfinderai.test', 'Alex Morgan', 25, 'male', 'Software Developer',
         'Tidy, easy-going dev who works hybrid. Love cooking on weekends and quiet weeknights.',
         900, 1500, 'Toronto',  '2026-05-01',
         '{"cleanliness":8,"noiseLevel":3,"socialLevel":6,"smokingPolicy":1,"petPolicy":6,"sleepScheduleBedtime":"23:00","rentSplitPreference":"equal","kitchenCleanupTiming":"immediate"}'::jsonb),

        ('seed.maria@roomfinderai.test', 'Maria Santos', 23, 'female', 'Grad Student',
         'Grad student, early riser, very organized. Looking for a calm, respectful home base.',
         800, 1300, 'Toronto',  '2026-09-01',
         '{"cleanliness":9,"noiseLevel":2,"socialLevel":4,"smokingPolicy":1,"petPolicy":3,"sleepScheduleBedtime":"22:00","rentSplitPreference":"equal","kitchenCleanupTiming":"immediate"}'::jsonb),

        ('seed.james@roomfinderai.test', 'James Chen', 21, 'male', 'Engineering Student',
         'Co-op engineering student, night owl, social but respectful of shared space. Dog-friendly.',
         700, 1200, 'Waterloo', '2026-01-01',
         '{"cleanliness":6,"noiseLevel":5,"socialLevel":8,"smokingPolicy":1,"petPolicy":9,"sleepScheduleBedtime":"01:00","rentSplitPreference":"equal","kitchenCleanupTiming":"end_of_day"}'::jsonb),

        ('seed.priya@roomfinderai.test', 'Priya Sharma', 27, 'female', 'Nurse',
         'Healthcare worker on rotating shifts. Clean, quiet, and considerate. Non-smoker, no pets.',
         1000, 1700, 'Vancouver', '2026-06-01',
         '{"cleanliness":9,"noiseLevel":2,"socialLevel":5,"smokingPolicy":1,"petPolicy":2,"sleepScheduleBedtime":"23:30","rentSplitPreference":"equal","kitchenCleanupTiming":"immediate"}'::jsonb);

    RAISE NOTICE '✅ Seed roommate profiles inserted (4 profiles)';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Seed roommate profiles skipped (schema mismatch is OK): %', SQLERRM;
END $$;


-- ---------------------------------------------------------------------
-- 6. Seed a couple of AI negotiation history rows (optional demo data).
-- ---------------------------------------------------------------------
DO $$
BEGIN
    DELETE FROM public.ai_negotiations WHERE user_email LIKE 'seed.%@roomfinderai.test';

    INSERT INTO public.ai_negotiations
        (user_email, user_message, ai_response, session_type, listing_details, provider, tokens_used)
    VALUES
        ('seed.alex@roomfinderai.test',
         'The listing is $2150/mo. Can you help me negotiate it down?',
         'Absolutely. Given comparable 1-bed condos nearby rent for $1950–$2050, a fair opening counter is $1975 with a 12-month lease. Emphasize your stable income and move-in flexibility.',
         'negotiation_assistant',
         '{"location":"Toronto","rent":2150,"type":"Condo","size":"1 bed"}'::jsonb, 'openai', 128),

        ('seed.maria@roomfinderai.test',
         'How do I ask for utilities to be included?',
         'Frame it as simplifying payments: "I''d prefer one predictable monthly figure — could we fold utilities in at $2750 all-in?" It gives the landlord a clean number while saving you the variable cost.',
         'negotiation_assistant',
         '{"location":"Toronto","rent":2650,"type":"Apartment","size":"2 bed"}'::jsonb, 'openai', 96);

    RAISE NOTICE '✅ Seed AI negotiation history inserted (2 rows)';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Seed AI negotiations skipped: %', SQLERRM;
END $$;


-- ---------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------
DO $$
DECLARE
    n_listings INTEGER := 0;
    n_sublease INTEGER := 0;
BEGIN
    BEGIN SELECT count(*) INTO n_listings FROM public.listings WHERE user_email LIKE 'seed.%@roomfinderai.test'; EXCEPTION WHEN OTHERS THEN n_listings := -1; END;
    BEGIN SELECT count(*) INTO n_sublease FROM public.sublease_requests WHERE user_email LIKE 'seed.%@roomfinderai.test'; EXCEPTION WHEN OTHERS THEN n_sublease := -1; END;
    RAISE NOTICE '==============================================';
    RAISE NOTICE '🌱 Seed complete. Listings: %, Sublease: %', n_listings, n_sublease;
    RAISE NOTICE 'All seed rows use the @roomfinderai.test email domain.';
    RAISE NOTICE '==============================================';
END $$;
