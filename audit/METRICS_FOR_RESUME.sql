-- =================================================================
-- RoomFinderAI: resume traction numbers (read-only)
-- =================================================================
-- Paste each query into the Supabase SQL Editor one at a time.
-- Every statement is a SELECT. Nothing modifies data.
--
-- Test / seed accounts are excluded where possible (see comments).
-- =================================================================


-- 1. Total signed-up users (excluding test accounts)
--    Reads: auth.users
--    Excludes @example.com, emails containing "test", and + aliases
SELECT count(*) AS total_real_users
FROM auth.users
WHERE email NOT ILIKE '%@example.com'
  AND email NOT ILIKE '%test%'
  AND email NOT ILIKE '%+%';


-- 2. Users who signed up in the last 30 days (excluding test accounts)
--    Reads: auth.users
SELECT count(*) AS signups_last_30_days
FROM auth.users
WHERE created_at >= now() - interval '30 days'
  AND email NOT ILIKE '%@example.com'
  AND email NOT ILIKE '%test%'
  AND email NOT ILIKE '%+%';


-- 3a. Total listings
--    Reads: public.listings
SELECT count(*) AS total_listings
FROM public.listings;

-- 3b. Active listings (created in the last 90 days as a proxy)
--     Reads: public.listings
--     Note: no "status" or "active" column was found in the schema.
--     Adjust the interval to whatever you consider "active".
SELECT count(*) AS active_listings_last_90d
FROM public.listings
WHERE created_at >= now() - interval '90 days';


-- 4. Paid subscribers
--    Reads: public.subscriptions, public.profiles
--    Returns subscription counts by status and the number of Pro profiles.
SELECT
  (SELECT count(*) FROM public.subscriptions
   WHERE status IN ('active', 'trialing'))    AS active_subscribers,
  (SELECT count(*) FROM public.profiles
   WHERE is_pro IS TRUE)                      AS pro_profiles;


-- 5a. AI negotiation conversations started
--     Reads: public.conversations (ai_managed column)
SELECT count(*) AS ai_negotiation_conversations
FROM public.conversations
WHERE ai_managed IS TRUE;

-- 5b. AI negotiations that reached a deal
--     Reads: public.messages (message_type = 'ai_deal')
--     A hidden message with type 'ai_deal' is written once per agreed deal.
SELECT count(DISTINCT conversation_id) AS ai_deals_reached
FROM public.messages
WHERE message_type = 'ai_deal';

-- 5c. AI negotiation success rate
--     Reads: public.conversations, public.messages
SELECT
  round(100.0 * d.deals / NULLIF(c.ai_convos, 0), 1) AS ai_deal_success_rate_pct,
  d.deals                                              AS deals_reached,
  c.ai_convos                                          AS ai_conversations_started
FROM (SELECT count(DISTINCT conversation_id) AS deals
      FROM public.messages WHERE message_type = 'ai_deal') d,
     (SELECT count(*) AS ai_convos
      FROM public.conversations WHERE ai_managed IS TRUE) c;


-- 6. First user signup date
--    Reads: auth.users
SELECT min(created_at) AS first_user_signup
FROM auth.users
WHERE email NOT ILIKE '%@example.com'
  AND email NOT ILIKE '%test%'
  AND email NOT ILIKE '%+%';
