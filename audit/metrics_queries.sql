-- =====================================================================
-- RoomFinderAI: read-only production metrics queries
-- =====================================================================
-- Paste these into the Supabase SQL editor (or psql) yourself.
-- Every statement is a SELECT. Nothing here inserts, updates or deletes.
--
-- Where the table names come from: the backend's supabase.from('...') calls
-- (backend/server.js, backend/messaging.js, backend/negotiator-daemon.js) and
-- database/migrations/*.sql.
--
-- WARNING ABOUT SCHEMA DRIFT: the migrations folder does not match the live
-- schema exactly. The backend queries ai_usage, ai_negotiations, govdocs,
-- favorites, roommate_profiles, bank_information and
-- negotiation_tactics_effectiveness, and none of those has a CREATE TABLE in
-- database/migrations. Some columns used below, such as conversations.ai_managed,
-- were found only in backend code. If a query errors on a missing column, run
-- query 0 first to see what is really there.
--
-- Run them one at a time. Each block says what it returns.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Schema check: list the real tables and their row-count estimates
--    Returns: one row per public table with Postgres's estimated row count.
--    Estimates come from planner statistics, so they are approximate. Use
--    the exact queries below for anything you will put on a resume.
-- ---------------------------------------------------------------------
SELECT relname AS table_name, n_live_tup AS estimated_rows
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;


-- ---------------------------------------------------------------------
-- 1. Total users
--    Returns: total accounts in Supabase Auth, how many confirmed their
--    email, and the profiles row count for comparison. The two can differ
--    because some legacy accounts were created through the custom
--    /api/register path.
-- ---------------------------------------------------------------------
SELECT
  (SELECT count(*) FROM auth.users)                                  AS auth_users_total,
  (SELECT count(*) FROM auth.users WHERE email_confirmed_at IS NOT NULL) AS auth_users_confirmed,
  (SELECT count(*) FROM public.profiles)                             AS profiles_total;

-- 1b. Same count with test and seed accounts left out.
--     database/sql/seed-test-data.sql exists, so check how many accounts
--     are test data. Adjust the patterns to match your own test emails.
SELECT count(*) AS real_users_estimate
FROM auth.users
WHERE email NOT ILIKE '%@example.com'
  AND email NOT ILIKE '%test%'
  AND email NOT ILIKE '%+%';


-- ---------------------------------------------------------------------
-- 2. Signups by month
--    Returns: one row per month with new auth accounts and a running total.
-- ---------------------------------------------------------------------
SELECT
  date_trunc('month', created_at)::date AS month,
  count(*)                              AS signups,
  sum(count(*)) OVER (ORDER BY date_trunc('month', created_at)) AS cumulative
FROM auth.users
GROUP BY 1
ORDER BY 1;


-- ---------------------------------------------------------------------
-- 3. Active users in the last 30 days
--    Returns: three different definitions of "active". Choose one and
--    say which one you used.
--      a) signed in during the last 30 days (Supabase Auth)
--      b) sent at least one message during the last 30 days
--      c) used the AI at least once during the last 30 days (ai_usage)
-- ---------------------------------------------------------------------
SELECT count(*) AS active_by_sign_in_30d
FROM auth.users
WHERE last_sign_in_at >= now() - interval '30 days';

SELECT count(DISTINCT lower(sender_email)) AS active_by_messages_30d
FROM public.messages
WHERE created_at >= now() - interval '30 days';

-- ai_usage columns, from backend/server.js bumpUsage():
-- user_key, window_kind ('day' | 'month'), window_start (date), calls.
-- The '__service__' row is the service-wide total, so it is left out here.
SELECT count(DISTINCT user_key) AS active_by_ai_use_30d
FROM public.ai_usage
WHERE window_kind = 'day'
  AND window_start >= (now() - interval '30 days')::date
  AND user_key <> '__service__';


-- ---------------------------------------------------------------------
-- 4. Listings
--    Returns: total listings, listings created in the last 30 days, and
--    how many distinct cities they cover.
--    Note: scripts/seed-live-data.js and scripts/refresh-listings.js exist.
--    Check how many listings were seeded rather than posted by real users
--    before you claim a count (see 4b).
-- ---------------------------------------------------------------------
SELECT
  count(*)                                                     AS listings_total,
  count(*) FILTER (WHERE created_at >= now() - interval '30 days') AS listings_last_30d,
  count(DISTINCT lower(city))                                  AS distinct_cities
FROM public.listings;

-- 4b. Listings per posting account (spots seed or bulk accounts).
SELECT lower(user_email) AS poster, count(*) AS listings
FROM public.listings
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- 4c. Listings by month.
SELECT date_trunc('month', created_at)::date AS month, count(*) AS listings
FROM public.listings
GROUP BY 1 ORDER BY 1;


-- ---------------------------------------------------------------------
-- 5. Conversations and AI negotiations
--    Returns: total conversations, how many were run by the AI negotiator
--    (conversations.ai_managed = true, see backend/negotiator-daemon.js),
--    and how many reached an agreed deal (a hidden message with
--    message_type = 'ai_deal' is written once per agreed deal).
-- ---------------------------------------------------------------------
SELECT
  count(*)                                   AS conversations_total,
  count(*) FILTER (WHERE ai_managed IS TRUE) AS ai_managed_conversations
FROM public.conversations;

SELECT count(DISTINCT conversation_id) AS ai_deals_reached
FROM public.messages
WHERE message_type = 'ai_deal';

-- 5b. AI negotiation success rate (deals divided by AI-run conversations).
SELECT
  round(100.0 * d.deals / NULLIF(c.ai_convos, 0), 1) AS ai_deal_rate_pct,
  d.deals, c.ai_convos
FROM (SELECT count(DISTINCT conversation_id) AS deals
      FROM public.messages WHERE message_type = 'ai_deal') d,
     (SELECT count(*) AS ai_convos
      FROM public.conversations WHERE ai_managed IS TRUE) c;

-- 5c. Legacy AI tables. These exist in backend code; row counts only.
SELECT
  (SELECT count(*) FROM public.ai_negotiations) AS ai_negotiations_rows,
  (SELECT count(*) FROM public.ai_chats)        AS ai_chats_rows;


-- ---------------------------------------------------------------------
-- 6. Messages sent
--    Returns: total visible messages, the AI's hidden bookkeeping rows
--    (left out), and messages in the last 30 days.
-- ---------------------------------------------------------------------
SELECT
  count(*) FILTER (WHERE coalesce(message_type,'text') NOT IN ('ai_goals','ai_deal')) AS messages_total,
  count(*) FILTER (WHERE coalesce(message_type,'text') NOT IN ('ai_goals','ai_deal')
                     AND created_at >= now() - interval '30 days')                    AS messages_last_30d
FROM public.messages;

-- 6b. Messages by month.
SELECT date_trunc('month', created_at)::date AS month, count(*) AS messages
FROM public.messages
WHERE coalesce(message_type,'text') NOT IN ('ai_goals','ai_deal')
GROUP BY 1 ORDER BY 1;


-- ---------------------------------------------------------------------
-- 7. AI requests per day and per month (closest thing to request volume)
--    Returns: total AI calls per day and per month from the ai_usage
--    counter, which is written by openAiRateLimitMiddleware
--    (backend/server.js, around line 6745). It counts only metered AI
--    calls from free users. Pro and allowlisted users skip the counter,
--    so this is a lower bound.
--    No table in the repo logs all HTTP requests. For total traffic, use
--    the Railway or Cloudflare dashboards.
-- ---------------------------------------------------------------------
SELECT window_start AS day, sum(calls) AS ai_calls
FROM public.ai_usage
WHERE window_kind = 'day' AND user_key <> '__service__'
GROUP BY 1 ORDER BY 1 DESC
LIMIT 90;

SELECT window_start AS month, calls AS ai_calls_service_total
FROM public.ai_usage
WHERE user_key = '__service__' AND window_kind = 'month'
ORDER BY 1;


-- ---------------------------------------------------------------------
-- 8. Payments and subscriptions
--    Returns: subscription rows by status, and Pro accounts.
--    Stripe is the source of truth for revenue. Use the Stripe dashboard
--    for MRR and charges, not this table.
-- ---------------------------------------------------------------------
SELECT status, count(*) FROM public.subscriptions GROUP BY 1 ORDER BY 2 DESC;

SELECT count(*) AS pro_profiles FROM public.profiles WHERE is_pro IS TRUE;


-- ---------------------------------------------------------------------
-- 9. Other feature usage (row counts only)
--    Returns: how much each secondary feature has been used.
-- ---------------------------------------------------------------------
SELECT
  (SELECT count(*) FROM public.favorites)          AS favorites,
  (SELECT count(*) FROM public.user_verifications) AS id_verifications,
  (SELECT count(*) FROM public.sublease_requests)  AS sublease_requests,
  (SELECT count(*) FROM public.roommate_profiles)  AS roommate_profiles,
  (SELECT count(*) FROM public.device_tokens)      AS push_device_tokens,
  (SELECT count(*) FROM public.content_reports)    AS content_reports,
  (SELECT count(*) FROM public.contact_messages)   AS contact_messages;


-- ---------------------------------------------------------------------
-- 10. Latency and error rate
--     NOT AVAILABLE FROM THE DATABASE. The repo has no request-log, latency
--     or error table. Errors go only to console.error (Railway logs).
--     Get average and p95 latency and error rate from Railway
--     (Observability / Metrics) or Cloudflare Analytics.
--     As a rough proxy, this shows how long the AI took to answer a landlord:
--     seconds between a landlord message and the next AI-side message in
--     AI-run conversations. It includes the daemon's 6-second polling
--     interval, so it is not model latency.
-- ---------------------------------------------------------------------
WITH ordered AS (
  SELECT m.conversation_id, m.created_at,
         (lower(m.sender_email) = lower(c.sender_email)) AS is_tenant_side,
         lag(m.created_at)  OVER w AS prev_at,
         lag(lower(m.sender_email) = lower(c.sender_email)) OVER w AS prev_is_tenant
  FROM public.messages m
  JOIN public.conversations c ON c.id = m.conversation_id
  WHERE c.ai_managed IS TRUE
    AND coalesce(m.message_type,'text') NOT IN ('ai_goals','ai_deal')
  WINDOW w AS (PARTITION BY m.conversation_id ORDER BY m.created_at)
)
SELECT
  count(*)                                                            AS ai_replies_measured,
  round(avg(extract(epoch FROM created_at - prev_at))::numeric, 1)    AS avg_reply_seconds,
  round((percentile_cont(0.5)  WITHIN GROUP (ORDER BY extract(epoch FROM created_at - prev_at)))::numeric, 1) AS p50_reply_seconds,
  round((percentile_cont(0.95) WITHIN GROUP (ORDER BY extract(epoch FROM created_at - prev_at)))::numeric, 1) AS p95_reply_seconds
FROM ordered
WHERE is_tenant_side AND prev_is_tenant IS FALSE
  AND created_at - prev_at < interval '1 hour';  -- drops replies made by hand much later
