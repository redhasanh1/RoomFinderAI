# RoomFinderAI: Resume Metrics Audit

Audit date: 2026-11-15. Repo at commit `d92ce563` on `main`. The audit was read-only. Nothing was committed, pushed, deployed or run against production. No paid API was called.

**Confidence labels**
- **EXACT**: counted from code or git by the command shown.
- **ESTIMATE**: depends on a counting choice, such as raw `wc -l` lines rather than code-only lines.
- **NEEDS DASHBOARD**: the code can't show it. See section 6 or `audit/metrics_queries.sql`.

---

## 1. Code facts

### Lines of code (git-tracked files only, `node_modules` and `*.min.*` excluded)
Command: `git ls-files <dir> | grep -v node_modules/ | grep -v '\.min\.' | ... | xargs wc -l`. These are **physical lines** (blank lines and comments included), because `cloc`/`tokei` are not installed.

| Metric | Value | Source | Confidence |
|---|---|---|---|
| Backend JavaScript (Node/Express) | 15,402 lines in 14 files | `backend/*.js` (`server.js` alone is 13,077) | EXACT (physical lines) |
| Frontend HTML | 29,184 lines in 36 files | `frontend/**/*.html` | EXACT (physical lines) |
| Frontend JavaScript | 21,961 lines in 34 files (+31 in 1 `.mjs`) | `frontend/**/*.js` | EXACT (physical lines) |
| Frontend CSS | 6,028 lines in 13 files | `frontend/**/*.css` | EXACT (physical lines) |
| Cloudflare Worker | 603 TS + 296 JS | `cloudflare-worker/src/index.ts`, `worker.js` | EXACT |
| SQL (migrations + ad-hoc scripts) | 6,201 lines in 57 files | `database/migrations` (40) + `database/sql` (17) | EXACT |
| Scripts / tooling | 3,089 JS + 229 Py + 259 sh | `scripts/` | EXACT |
| **Web platform total (backend + frontend + worker + SQL)** | **~79,700 physical lines** (79,706) | sum of rows above | ESTIMATE (includes blank lines and comments) |
| Android (out of your stated scope) | 28,713 Java + 1,289 Kotlin | `android/` | EXACT, but authorship is mixed |
| iOS (out of your stated scope) | 17,900 Swift in 81 files | `ios/` | EXACT, but authorship is mixed |

### API surface
Command: `grep -nE "^[[:space:]]*(app|router)\.(get|post|put|patch|delete)\(" backend/*.js`

| Metric | Value | Source | Confidence |
|---|---|---|---|
| Express route registrations | 155 | `server.js` 138, `messaging.js` 6, `account-compliance.js` 5, `profiles.js` 3, `push.js` 3 | EXACT |
| Unique method + path routes | 153 (`GET /` and `POST /api/account/delete` are each registered twice) | same | EXACT |
| Routes under `/api/*` | 142 | same | EXACT |
| By HTTP method | 70 GET, 77 POST, 3 PUT, 5 DELETE | same | EXACT |
| Debug routes blocked in production | 7 (`/listings-new`, `/api/test-email`, `/api/brevo-status`, `/api/test-negotiate`, `/api/test-supabase`, `/debug-test`, `/api/sublease/debug`) | `blockInProduction`, `backend/reliability.js:8` | EXACT |
| AI-negotiation endpoints (`/api/negotiate/*`) | 14 | route list | EXACT |

### Database
| Metric | Value | Source | Confidence |
|---|---|---|---|
| Migration files | 40 `.sql` | `ls database/migrations/*.sql` | EXACT |
| Ad-hoc SQL scripts | 17 | `ls database/sql/*.sql` | EXACT |
| Tables created in migrations | 34 distinct `CREATE TABLE` | perl scan of `database/migrations/*.sql` (2 false hits, "if" and "in", removed) | EXACT |
| Tables queried by the backend | 24 distinct `supabase.from('…')` | `backend/*.js` | EXACT |
| Postgres functions in migrations | 25 `CREATE [OR REPLACE] FUNCTION` | `grep -ci` over migrations | EXACT |
| Row-level-security policies in migrations | 106 `CREATE POLICY` | `grep -hi "create policy"` | EXACT (count of statements; some replace earlier ones) |
| Live production table count | not known | 7 backend tables (e.g. `ai_usage`, `ai_negotiations`, `favorites`) have no migration | NEEDS DASHBOARD (query 0 in SQL file) |

### Background jobs, tests, CI, deploy
| Metric | Value | Source | Confidence |
|---|---|---|---|
| Background workers | 1 server-side AI negotiator daemon. It polls every 6 s and stops after 14 AI messages per conversation | `backend/negotiator-daemon.js:21,24,211` | EXACT |
| Automated test suite | **None.** `npm test` is `echo 'No tests specified'`. There are no `*.test.js`/`*.spec.js` files and no Jest, Vitest or Mocha | `package.json` scripts | EXACT |
| Manual test scripts | 4 in `tests/` + 9 `test-*.js` in `scripts/maintenance`. All hit live services, so they were **not run** | file listing | EXACT |
| Production smoke test | 1 bash script with 9 checks and 3 retries | `scripts/production-smoke-test.sh` | EXACT (not run; it hits production) |
| Local check run | `node --check` on 14 backend files + worker: **15/15 pass** (syntax only, Node v22.20.0) | run during this audit | EXACT |
| CI workflows | **None** for this project. The only `.github/workflows` are inside `archive/unrelated/...` | `git ls-files \| grep workflow` | EXACT |
| Deploy config | Railway (Nixpacks), `/health` healthcheck, 120 s timeout, restart on failure up to 3 times; Dockerfile `node:18-alpine` with 30 s HEALTHCHECK; Cloudflare Worker via `wrangler.toml` | `railway.json`, `nixpacks.toml`, `Dockerfile`, `cloudflare-worker/wrangler.toml` | EXACT |

### Git history
| Metric | Value | Source | Confidence |
|---|---|---|---|
| Total commits | 5,287 (5,036 non-merge, 251 merges) | `git rev-list --count HEAD` | EXACT |
| Contributors | 12 author names, 24 distinct author emails | `git shortlog -sn HEAD` | EXACT |
| Your commits (`Arsalan-05`) | 895 (834 non-merge), 16.9% of all commits | `git shortlog -sn` | EXACT |
| Commits by author | redhasanh1 1,842; EricT2003 1,267; Arsalan-05 895; "RoomFinder Dev" 792; Hasan Iqbal 268; "Your Name" 135; others ≤30 | `git shortlog -sn HEAD` | EXACT |
| First commit | 2025-05-06 (`e9230fe0 Initial commit`) | `git log --reverse` | EXACT |
| Latest commit | 2026-11-01 (`d92ce563`) | `git log -1` | EXACT |
| Days with at least one commit | 163 | `git log --date=short \| sort -u` | EXACT |
| Commits in the last 12 months | 1,810 | `git rev-list --since=2025-11-15` | EXACT |
| `backend/server.js` revisions | 360 commits | `git log -- backend/server.js` | EXACT |
| Your line churn in web dirs | +182,048 / −50,017 | `git log --author=Arsalan-05 --numstat` | ESTIMATE (counts generated files and moved files; not a "lines written" figure) |

---

## 2. Countable features

| Metric | Value | Source | Confidence |
|---|---|---|---|
| LLM providers with automatic failover | 3-step chain: OpenAI `gpt-4o-mini`, then Groq `llama-3.1-8b-instant`, then Groq `llama-3.3-70b-versatile` | `backend/ai-providers.js:13-15,88-91` | EXACT |
| Vision models | 2: OpenAI `gpt-4o-mini` photo validation; Cloudflare Workers AI `@cf/meta/llama-3.2-11b-vision-instruct` property analysis | `backend/photo-validation.js`, `cloudflare-worker/src/index.ts` | EXACT |
| LLM call sites (system prompts) | 14 `role: 'system'` prompts / 14 `callAI`/`callOpenAI` calls | `grep` in `backend/server.js` | EXACT |
| Negotiation conversation phases | 7: INTRODUCTION, RAPPORT_BUILDING, QUALIFICATION, PRICE_INTRODUCTION, AVAILABILITY_DISCUSSION, ACTIVE_NEGOTIATION, CLOSING | `frontend/ai-negotiation.js:30-88` | EXACT |
| Per-phase generation settings | CLOSING: 60 max tokens, temp 0.3; FRUSTRATED tone: 80 tokens, temp 0.3; otherwise 250 tokens, temp 0.8 | `backend/server.js:7348-7349` | EXACT |
| Deterministic output guardrails | at least 3 validators that rewrite model output (meeting agreed before price; accepting an above-target counter; reopening settled rent) | `backend/server.js:7357-7400, 8003-8020` | EXACT (count is a floor) |
| Auth methods | 3: email/password (Supabase Auth + bcrypt, codes emailed via Brevo), Google OAuth, Sign in with Apple. Plus Cloudflare Turnstile bot check | `/api/auth/*` routes, `backend/apple-auth.js`, `server.js:186` | EXACT |
| Payment flows | Stripe: Checkout (subscription), Customer Portal, webhook handling 4 event types (`checkout.session.completed`, `customer.subscription.updated`, `invoice.paid`, `customer.subscription.deleted`) | `backend/server.js:509-590, 8656, 8885` | EXACT |
| Pro plan price in code | $19.99 | `backend/server.js:532` | EXACT (check Stripe for the live price) |
| Identity verification | Azure Face (face match, head pose) + Azure Document Intelligence (ID upload) | `/api/verify/*`, env names | EXACT |
| Push notifications | APNs (iOS) is implemented. Web push is a **stub** (hard-coded dummy VAPID key) | `backend/push.js`, `server.js:2617-2621` | EXACT |
| External APIs called live (verified URLs in handlers) | 15: OpenAI, Groq, Cloudflare Workers AI, Supabase, Stripe, Brevo, Google Maps (geocode + distance matrix), Google OAuth, Apple ID, APNs, RentCast, Nominatim/OSM, Azure Face, Azure Document Intelligence, Cloudflare Turnstile | host grep in `backend/*.js` + handlers | EXACT |
| Public-data APIs | 6 call a real government URL: FBI CDE, Census ACS, USGS earthquakes, NWS weather, FEMA flood, EPA EJScreen. FEMA, EPA and NWS fall back to `Math.random` mock data when the call fails, so 3 are always live (FBI, Census, USGS) | handler bodies, `server.js:10623-11500` | EXACT |
| Mock-only "data" endpoints | 9 return `Math.random`/mock data: `bls/economic`, `greatschools`, `walkscore`, `transit/score`, `osm/poi`, `business/licenses`, `noaa/climate`, `realtymole/property`, `analytics/sentiment` | same | EXACT |
| AI agent tools, MCP tools | 0 / 0 | no tool-calling or MCP code found | EXACT |
| RAG: chunking, embeddings, retrieval (top-k) | **None in code.** `VOYAGE_API_KEY` is set in `.env` but no code reads it | grep for voyage/embedding/vector/top_k | EXACT |
| Eval harness | `scripts/negotiation_battle.js`: 3 tenant goal templates × 4 landlord personas, 18 max turns, 5 penalised failure types (penalties 0.15 to 0.5) + −0.25 for no deal; `negotiation_coach.js` is the interactive version | `scripts/negotiation_battle.js:37-84, 381-386` | EXACT |
| Public HTML pages | 36; sitemap lists 22 URLs | `frontend/*.html`, `frontend/sitemap.xml` | EXACT |

---

## 3. Evaluation and quality figures already in the repo

No saved eval outputs, CI artifacts, latency logs or cost logs exist. `scripts/_results/` (the harness output folder) is not in the repo or on disk. The only recorded results are **code comments** written after harness runs:

| Recorded finding | Quoted text | Source | Confidence |
|---|---|---|---|
| Meeting agreed before price was discussed | "The negotiation_battle harness surfaced this leak at 46% of conversations at N=50" | `backend/server.js:7361-7362` | EXACT quote; the underlying run is not saved |
| CLOSING-phase leak | "the harness showed 56% of CLOSING-phase replies affirming a meeting without price ever having been touched" | `backend/server.js:7374-7376` | EXACT quote; run not saved |
| Over-paying | "Harness at N=100 showed 71% of post-iter5 deals settled too high" | `backend/server.js:7385-7387` | EXACT quote; run not saved |

These are **failure rates before a fix**. There is no recorded rate after the fix. No recall@k, answer-quality score or regression threshold exists.

---

## 4. Performance and cost controls in code

| Control | Value | Source | Confidence |
|---|---|---|---|
| AI free tier: per-user daily cap | 25 calls/day (env `AI_DAILY_LIMIT`) | `backend/server.js:6759` | EXACT |
| AI free tier: per-user monthly cap | 200 calls/month (env `FREE_AI_MONTHLY_LIMIT`) | `server.js:6765` | EXACT |
| AI service-wide monthly ceiling | 20,000 calls/month (env `AI_SERVICE_MONTHLY_LIMIT`) | `server.js:6760` | EXACT |
| AI usage counters | stored in Supabase `ai_usage` (day/month windows), so they survive redeploys | `server.js` `bumpUsage()` (~6817) | EXACT |
| Old per-IP AI limits | 100/hour, 500/day: defined but **never used** | `server.js:6752-6753` (only 2 references in the file) | EXACT |
| Auth endpoint rate limit | 10 requests per minute per IP, on 6 routes (login, send-verification, verify-email, send-reset-code, verify-reset-code, account/delete) | `backend/reliability.js:42-46` | EXACT |
| Contact form rate limit | 3 per minute | `server.js:5200-5208` | EXACT |
| RentCast quota | 40 calls/month per IP (in memory, so it resets on redeploy) | `server.js:279` | EXACT |
| Nominatim geocoding throttle | 1 request/second | `server.js:5655, 5748` | EXACT |
| Negotiator daemon | 6 s tick, 14 AI messages max per conversation, in-flight dedup set | `negotiator-daemon.js:21,24,34` | EXACT |
| Outbound HTTP timeouts | 5 s, 8 s, 10 s (×7), 25 s (vision), 30 s (×4), 45 s (ID worker) | `server.js:138,198,3073,…,9511`; `photo-validation.js:71` | EXACT |
| Caches | Apple JWKS keys 1 h TTL; APNs auth token 45 min TTL; `/.well-known` files `max-age` 3600 and 300 | `apple-auth.js:21`, `push.js:48`, `server.js:831,870` | EXACT |
| Retries | LLM: 3-provider failover (no retry within a provider); Railway restart up to 3; smoke test 3 retries | `ai-providers.js`, `railway.json` | EXACT |
| Password reset code window | 10 minutes | `server.js:4926` | EXACT |

---

## 5. Production numbers (queries prepared, not run)

See `audit/metrics_queries.sql`. Each query is a SELECT. Paste it into the Supabase SQL editor.

| Metric | Query # | Confidence |
|---|---|---|
| Total users (auth + profiles, with and without test accounts) | 1, 1b | NEEDS DASHBOARD |
| Signups by month | 2 | NEEDS DASHBOARD |
| Active users in 30 days (3 definitions) | 3 | NEEDS DASHBOARD |
| Listings total, by month, by city; seeded vs real | 4, 4b, 4c | NEEDS DASHBOARD |
| Conversations, AI-run conversations, AI deals reached, deal rate | 5, 5b | NEEDS DASHBOARD |
| Messages sent, by month | 6, 6b | NEEDS DASHBOARD |
| AI calls per day and month (lower bound) | 7 | NEEDS DASHBOARD |
| Subscriptions / Pro users | 8 | NEEDS DASHBOARD |
| Average and p95 latency, error rate | 10: **not logged in the DB**. Use Railway. The query gives AI reply time only as a proxy | NEEDS DASHBOARD |

---

## 6. Dashboards to check yourself

| Dashboard | Metric to copy |
|---|---|
| **Supabase** (Auth → Users; Reports) | Total users, monthly signups, MAU; DB size; API requests per day |
| **Railway** (service → Metrics / Observability) | Requests per day, p50/p95 response time, 5xx error rate, uptime, deploy count, monthly cost |
| **Cloudflare** (Analytics → Traffic; Workers AI → `roomfinder-ai-vision`) | Unique visitors and requests over 30 days; Worker invocations; Turnstile challenges solved |
| **Stripe** (Home; Billing → Subscriptions) | Active subscriptions, MRR, total gross volume, number of successful charges, churn |
| **OpenAI usage** and **Groq console** | Total requests and tokens per month, monthly spend, so you can quote cost per negotiation |
| **Google Search Console** | Indexed pages, clicks and impressions over 3 months (the SEO pages under `frontend/*-ontario.html`) |
| **Google Analytics / Bing Webmaster** (verification files are in `frontend/`) | Users, sessions, top pages |
| **Brevo** | Transactional emails sent (verification and reset codes), delivery rate |
| **App Store Connect** | Units/installs, active devices, crash-free rate (only if you contributed to iOS) |
| **Google Play Console** | Installs, active users, ratings (only if you contributed to Android) |
| **GitHub** (Insights → Traffic, Contributors) | Repo views and clones over 14 days; your contribution graph |
| **Langfuse** | **Not integrated.** No Langfuse code in the repo, so there is nothing to collect |

---

## Security findings (no values printed)

- **A Supabase `service_role` JWT is committed in 12 tracked files**: `scripts/maintenance/` (7 files), `scripts/migrations/` (4 files), `scripts/tools/analyze-constraint.js`. All 12 contain the same token. Anyone with repo access gets full database access that bypasses RLS. **Rotate this key in Supabase and remove it from the files.** It also stays in git history.
- A real-looking OpenAI-style `sk-` key, a Google API key and a Supabase anon JWT are in `archive/legacy-android/.../config/ApiConfig.java`. There is also a Google API key in `archive/legacy-server/server.js`. Check them and rotate if they are still live.
- `.env` exists locally and is gitignored. Its values were not read.
- The `sk-` matches in `.env.example`, `docs/RAILWAY_DEPLOYMENT.md` and `validate-config.js` are placeholders.

---

## I could not verify

- Any production figure: users, listings, conversations, messages, revenue, traffic, latency, uptime, cost. These need the SQL file or the dashboards.
- Whether the 46% / 56% / 71% harness figures improved after the fixes. No run after the fixes was saved.
- Whether the tests pass. There is no automated test suite to run, and the manual scripts call live services.
- Which `EricT2003` commits are yours. `CLAUDE.md` says that name appears when you push from your laptop, but the 1,267 EricT2003 commits run from 2025-05-24 to 2025-09-28 and may belong to a teammate. Confirm before adding them to your count.
- The exact code-only line count. `cloc` isn't installed, so the figures include blank lines and comments.
- The live table count and schema. Migrations and backend code disagree.

---

## The 5 strongest resume numbers

1. **Built a server-side AI negotiation agent with a 7-phase conversation flow, 3-provider LLM failover (OpenAI then 2 Groq Llama models) and deterministic guardrails.** EXACT (`ai-providers.js`, `ai-negotiation.js:30-88`, `server.js:7357-7400`).
2. **Ran a simulated evaluation harness (3 goal templates × 4 landlord personas, scored on a rubric) that found failure modes in up to 71% of N=100 conversations, then added fixes.** The design is EXACT. The percentages are quotes from code comments, so you have to confirm them. Don't claim an improvement figure unless you rerun the harness and save the output.
3. **153 REST routes (142 under `/api`) on Node/Express over Supabase Postgres: 40 migrations, 34 tables, 106 row-level-security policies.** EXACT.
4. **Multi-layer AI cost controls: 25/day and 200/month per user, a 20,000/month service ceiling, stored in Postgres so they survive redeploys.** EXACT (`server.js:6759-6765`).
5. **Integrated 15 external services, including Stripe subscriptions (4 webhook events), Google and Apple sign-in, Azure Face/Document ID verification, APNs push and a Cloudflare Workers AI vision model.** EXACT. Add a user, signup or deal count from query 1/2/5 to make this stronger. Those need your confirmation.

## 3 numbers to be careful not to claim

1. **"Integrated 15+ public data sources" (crime, schools, walkability, transit, economics, and so on).** 9 of those endpoints return `Math.random` mock data and 3 more fall back to it. Only about 4 are reliably live.
2. **The total commit or line count as yours: 5,287 commits, ~80k lines, +614k churn.** There are 12 contributors. Your verified share is 895 commits (16.9%). Claim "contributed to" or use your own numbers.
3. **Test coverage, CI, RAG, embeddings, eval regression thresholds or measured latency.** None of these exist in the repo. Also don't claim the harness percentages as improvements: they are failure rates measured before the fixes.
