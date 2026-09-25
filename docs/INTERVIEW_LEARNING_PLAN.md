# RoomFinderAI — Interview Learning Plan

**Purpose:** Learn this codebase deeply enough to explain every major system in a technical interview — not just “we used AI to build it,” but *how it works, why it was designed that way, and what you would change*.

**Scope:** Website only (`frontend/` + `backend/`). Mobile folders (`*-CLOSED`, `ios/`) are secondary — know *why* they are closed, not every line.

**How to use this doc:**
1. Follow phases in order (foundation → core product → depth → drill).
2. For each topic: **read the files → draw the flow on paper → answer the drill questions out loud**.
3. Track yourself with the checklist at the bottom.
4. Do not memorize every route. Memorize *architecture*, *data flow*, and *tradeoffs*.

**Estimated total:** ~25–35 focused hours (fits weekday 30–45 min + one weekend deep session).

---

## 0. One-minute pitch (memorize this first)

> RoomFinderAI is an AI-powered rental marketplace. Tenants browse listings, match roommates (RoomPal), and use an AI negotiator that messages landlords on their behalf using a phased conversation strategy and market data. Landlords post listings; Pro unlocks unlimited AI sessions via Stripe. The web app is a vanilla HTML/JS frontend served by an Express API on Railway, with Supabase for Postgres, Auth, and Storage.

If an interviewer stops you there, add one sentence on *your* role (equity, website ownership, what you shipped).

---

## 1. Mental model of the system

```
Browser (frontend/*.html + JS)
    │
    ├─ GET /api/config          → Supabase URL + anon key (no secrets)
    ├─ Auth UI                  → universal-auth-manager.js
    ├─ REST calls               → Express (backend/server.js)
    └─ Direct Supabase (limited)→ anon key + RLS (profiles locked down)
         │
         ▼
Express on Railway (node backend/server.js)
    │
    ├─ Service role Supabase    → admin reads/writes, storage, auth admin
    ├─ OpenAI / Groq            → callAI() failover chain
    ├─ Stripe                   → Checkout + webhooks → profiles.is_pro
    ├─ Brevo                    → verification / reset / contact emails
    ├─ Google Maps / RentCast   → geocode + market comps
    └─ Negotiator daemon        → replies to landlords even when app closed
         │
         ▼
Supabase (Postgres + Auth + Storage + optional Realtime)
```

**Why this shape?** One Node process serves both API and static UI → simple Railway deploy. Secrets stay on the server. Client gets only anon key + publishable Stripe key via `/api/config`.

---

## Phase A — Foundations (Days 1–3)

### A1. Repo map (1–2 hrs)

| Path | What it is | Interview line |
|------|------------|----------------|
| `backend/server.js` | ~13k-line Express monolith, ~138 routes | “All API + static serving live here” |
| `backend/ai-providers.js` | OpenAI → Groq failover | “Provider chain, not a single LLM vendor” |
| `backend/reliability.js` | Rate limits, prod gates, error handler | “Abuse + safety middleware” |
| `backend/negotiator-daemon.js` | Background AI replies | “Server-side loop so negotiation continues offline” |
| `backend/messaging.js` | Listing / chat routes | “User↔user messaging around listings” |
| `backend/profiles.js` | Safe profile columns | “Profiles not fully readable from browser” |
| `frontend/` | Vanilla pages + JS modules | “No React build for main site” |
| `frontend/ai-negotiation.js` | Client negotiation engine / phases | “Phase state machine for human-like chats” |
| `database/migrations/` | Schema + RLS history | “Postgres schema as SQL migrations” |
| `ai-learning/` | Template learning module | “Outcome tracking for negotiation templates” |
| `cloudflare-worker/` | Optional photo vision | “Edge AI for listing photo analysis” |
| `railway.json` / `nixpacks.toml` | Deploy config | “Nixpacks → `node backend/server.js`” |
| `docs/` + `DOCUMENTATION.md` | Ops + architecture docs | Point here if asked for docs |

**Read:** `README.md`, `DOCUMENTATION.md` §§1–8, `docs/ALL_CONNECTIONS.md` (skim tables).

**Drill:** Without looking, name the 6 folders that matter for web production and what each does.

---

### A2. Request lifecycle (2 hrs)

Trace one request end-to-end:

1. User opens `listings.html`
2. `html-inject.js` injects nav + platform banner into HTML
3. `supabase-config-init.js` → `GET /api/config`
4. `universal-auth-manager.js` reads `localStorage.currentUser` / Supabase session
5. Page calls `GET /api/listings` (optional `?city=`)
6. Server uses Supabase client → returns JSON
7. Frontend renders cards + map (Google Maps key from config)

**Files:**
- `backend/html-inject.js`
- `frontend/js/supabase-config-init.js`
- `frontend/universal-auth-manager.js`
- `backend/server.js` → `GET /api/listings`, `GET /api/config`

**Drill:** Why does Express serve `frontend/` at `/` instead of `/frontend/`? (Static root mapping; asset paths assume site root.)

---

### A3. Environment & secrets (1 hr)

**Read:** `.env.example`, `DOCUMENTATION.md` §4, `validate-config.js`.

| Secret location | Examples |
|-----------------|----------|
| Railway variables | `SUPABASE_SERVICE_ROLE_KEY`, `OPENAI_API_KEY`, `STRIPE_SECRET_KEY`, `BREVO_API_KEY` |
| Client-safe via `/api/config` | Supabase URL, anon key, Stripe publishable key, Maps key |
| Never in git | `.env`, service role, secret Stripe/Brevo keys |

**Interview answer:** “Browser never sees the service role key. Anon key is public by design and constrained by RLS + server-side profile routes.”

**Drill:** Explain the difference between anon key and service role key in one minute.

---

## Phase B — Auth & users (Days 4–6)

### B1. Auth flows

| Flow | Entry | API | Side effects |
|------|-------|-----|--------------|
| Register | `signup.html` | `POST /api/register` | Supabase Auth user + profile |
| Email verify | modal / codes | `POST /api/send-verification`, `/api/verify-email` | Brevo 6-digit code |
| Login | `login.html` | `POST /api/login` | Session + `currentUser` in localStorage |
| Google | OAuth | `/api/auth/google*`, callback | Profile id = auth user id |
| Apple | native/web | `POST /api/auth/apple` | `apple-auth.js` |
| Password reset | `forgot-password.html` | send/verify/reset-code routes | Brevo + Turnstile optional |
| Account delete | `delete-account.html` | `POST /api/account/delete` | Compliance / store requirements |

**Files:** `frontend/universal-auth-manager.js`, `frontend/universal-auth-protection.js`, `backend/apple-auth.js`, auth section of `server.js` (~login/register/google).

**Key design choices:**
- Canonical auth UI is one manager shared across pages (avoids per-page drift).
- Profiles are fetched through the server (`profiles.js` / `RoomFinderProfiles`) so the browser cannot list everyone’s addresses.
- `requireAuth` middleware validates Bearer tokens on protected routes.

**Drill questions:**
1. Where is session state stored on the client?
2. Why lock direct profile SELECT from the anon key?
3. How would you migrate from localStorage-primary to cookie/JWT-only sessions?

---

### B2. Profiles & Pro

- Table: `profiles` with `is_pro`, `plan`
- Stripe Checkout → webhook `checkout.session.completed` → sets `is_pro=true`
- Free = 20 AI sessions/month; Pro = unlimited (enforced in `openAiRateLimitMiddleware` / related helpers in `server.js`)

**Drill:** Walk through “user pays → becomes Pro” including webhook signature verification (`STRIPE_WEBHOOK_SECRET`).

---

## Phase C — Listings & marketplace (Days 7–10)

### C1. CRUD & media

| Action | Route | Notes |
|--------|-------|-------|
| List | `GET /api/listings` | Optional city filter |
| Detail | `GET /api/listings/:id` | Used by details page + OG |
| Create | `POST /api/listings` | Auth required after validation |
| Photos | `POST /api/listings/photos` | Multer upload → Storage |
| AI draft | `POST /api/listings/draft` | LLM writes listing copy |
| Favorites | `/api/favorites*` | Per-user saved listings |

**Storage buckets:** `listing-media`, `profile-images`, `chat-attachments`, `verification-docs` (`database/sql/setup-supabase-storage.sql`).

**Geocoding:** `POST /api/geocode/batch`, `POST /api/reverse-geocode` (Google → Nominatim fallback).

**Files:** listings routes in `server.js`, `frontend/modules/forms/add-listing-form.js`, `photo-listing-wizard.js`, `photo-validation.js`.

**Drill:** Explain why postal-code validation on the server mattered for Android (see `LEARN.md` 2026-09-04) — contract between clients and API.

---

### C2. Chat around listings

- Tables: `conversations`, `messages`
- Module: `backend/messaging.js`
- Client: `frontend/chat-system.js`
- Landlord email relay: `POST /api/message-landlord` (Brevo)

**Drill:** Difference between listing chat vs RoomPal messaging tables.

---

### C3. Sublease & RoomPal

| Feature | UI | Schema | API |
|---------|----|--------|-----|
| Sublease | `sublease.html` | `simple_sublease_schema.sql` | `/api/sublease/*` |
| RoomPal | `roommate-matching.html` | `roommate_profiles_schema_v2.sql` + messaging SQL | `/api/roommate-profiles`, client `roommate-*.js` |

**Matching idea:** Multi-factor compatibility scores (client + stored profile JSON) — be ready to say “weighted preference matching,” not mysterious ML.

**Drill:** Name three RoomPal tables and what each stores.

---

## Phase D — AI systems (Days 11–16) — highest interview weight

This is the product differentiator. Learn it cold.

### D1. Provider failover (`backend/ai-providers.js`)

```
AI_PROVIDER=auto (default):
  1. OpenAI (gpt-4o-mini by default)
  2. Groq llama-3.1-8b-instant
  3. Groq llama-3.3-70b-versatile

AI_PROVIDER=groq → Groq first, OpenAI last
```

All providers use OpenAI-compatible `/chat/completions`. `callAI()` tries each until one succeeds.

**Interview talking points:**
- Resilience to quota/billing failures
- Cost control (Groq free tier as fallback)
- Same message schema → easy swap

**Drill:** What happens if OpenAI returns 429? Walk the code path.

---

### D2. AI entry points (know by name)

| Route | Use |
|-------|-----|
| `POST /api/ai-negotiate` | Core negotiation turns |
| `POST /api/negotiate/phase-message` | Phase-aware messages |
| `POST /api/negotiate/reply` | Generate reply to landlord |
| `POST /api/negotiate/analyze-reply` | Classify landlord message |
| `POST /api/negotiate/counter-offer` | Price counter |
| `POST /api/negotiate/judge` | Outcome judgment |
| `POST /api/negotiate/lease-review` | Legal lease analysis |
| `POST /api/negotiate/market-estimate` | Market rent estimate |
| `POST /api/chat` | Modes: rental / support / legal-document / legal-advice |
| `POST /api/landlord-simulator` | Practice against fake landlord |
| `POST /api/listings/draft` | AI listing writer |
| `POST /api/analyze-property-photo` | Vision (optional Cloudflare worker) |

Rate limiting: IP + per-user AI session caps (`openAiRateLimitMiddleware`).

---

### D3. Negotiation phase state machine (`frontend/ai-negotiation.js`)

Phases (order matters — interview gold):

1. **INTRODUCTION** — greeting, no pricing  
2. **RAPPORT_BUILDING** — interest in property  
3. **QUALIFICATION** — tenant background  
4. **PRICE_INTRODUCTION** — budget (before viewing!)  
5. **AVAILABILITY_DISCUSSION** — move-in / lease  
6. **ACTIVE_NEGOTIATION** — haggling  
7. **CLOSING** — terminal lock when deal language detected  

**Why price before availability?** Avoid burning leverage by agreeing to a viewing before discussing rent (documented in code comments).

**CLOSING lock:** Regex of deal signals (`CLOSING_SIGNALS_RE`). Once closed, AI must not reopen discovery questions (bug that was fixed: “ok deal” → AI asked about neighborhood).

**Drill:** Draw the phase diagram from memory and give one example message per phase.

---

### D4. Negotiator daemon (`backend/negotiator-daemon.js`)

**Problem:** Old design only replied while the client was open. Landlords waited; users thought AI was “slow.”

**Solution:** Server tick every ~6s (`NEGOTIATOR_TICK_MS`):
1. Find AI-managed conversations where last visible message is from landlord  
2. Skip if deal already recorded (`message_type = ai_deal`)  
3. Cap AI messages (`NEGOTIATOR_MAX_MESSAGES`, default 14)  
4. Load tenant goals from hidden `ai_goals` message  
5. Call negotiate reply path, insert message, push notify  

**Interview line:** “We moved the agent loop to the server so negotiations are asynchronous and reliable.”

---

### D5. Market intelligence

- RentCast: `/api/rentcast/*` (valuation, comps, market) — monthly call budget in code  
- Aggregated: `GET /api/market-intelligence`  
- Many `/api/census`, `/api/walkscore`, etc. — know which are real integrations vs stubs (see `docs/ALL_CONNECTIONS.md`)

**Honest interview stance:** Lead with RentCast + negotiation market-estimate. Mention other endpoints only if live.

---

### D6. AI learning module (`ai-learning/`)

- Tracks template performance / success patterns  
- Optimizes which response templates to pick  
- Wired conceptually to negotiation outcomes  

**Be precise:** Know it exists and its folders (`core/`, `optimizers/`, `analyzers/`). Do not oversell “ML” if it is heuristic + stats on templates.

---

### D7. Cloudflare worker (optional)

`cloudflare-worker/` — Workers AI analyzes property photos → luxury score, features, suggested price. Called via `CLOUDFLARE_WORKER_URL` / analyze-photo route.

---

## Phase E — Payments, email, verification (Days 17–18)

### E1. Stripe

1. `pricing.html` → `POST /api/create-checkout-session`  
2. User pays on Stripe  
3. `POST /api/stripe-webhook` (raw body!) verifies signature  
4. On `checkout.session.completed` → `profiles.is_pro = true`  
5. Customer portal / cancel routes update plan  

**Drill:** Why is the webhook registered *before* `express.json()`? (Stripe needs raw body for signature.)

### E2. Brevo

Verification, password reset, contact form, landlord messages, negotiation emails — all `BREVO_API_KEY`.

### E3. ID verification (optional Azure)

`/api/verify/upload-id`, `/api/verify/face-match`, admin review routes. Production often uses **manual admin review**; Azure is optional automation.

---

## Phase F — Database & security (Days 19–21)

### F1. Core tables (say them aloud)

`profiles`, `listings`, `favorites`, `conversations`, `messages`, `ai_chats` / `ai_chat_history`, `ai_negotiations`, `subscriptions`, `roommate_profiles`, `roommate_conversations`, `roommate_messages`, `sublease_requests`, `contact_messages`, `user_verifications` / related.

### F2. RLS

- Migrations under `database/migrations/` (many `fix_*_rls*.sql`)  
- Pattern evolved from email-based `current_setting` → Auth UID policies  
- Server often uses **service role** which bypasses RLS — so **authorization must also live in Express**  

**Interview tradeoff:** “RLS is defense in depth for direct client access; privileged server routes still enforce ownership checks.”

### F3. Reliability & security checklist

From `reliability.js` + server:
- Auth rate limit (10/min/IP)
- AI hourly/daily caps
- Debug routes blocked in production (`blockInProduction`)
- CORS allowlist
- `trust proxy` for Railway IPs
- Admin routes gated by `ADMIN_KEY`
- Demo mode off in prod

**Drill:** Name three ways you prevent AI cost abuse.

---

## Phase G — Deploy & ops (Days 22–23)

1. Push to `main` (Railway watches `main`)  
2. Nixpacks builds Node deps (`postinstall` also installs `backend/`)  
3. Start: `node backend/server.js`  
4. Health: `GET /health` — 503 if Supabase down in production  
5. Smoke: `scripts/production-smoke-test.sh`  

**Known ops lesson (`LEARN.md`):** Production can drift from branches — always verify live routes before concluding a feature “doesn’t exist.” Deploy from `main`, not old feature branches.

**Deep links:** `/.well-known/assetlinks.json` and `apple-app-site-association` served by **explicit routes** because `express.static` ignores dotfiles.

---

## Phase H — Product surfaces map (1 weekend afternoon)

Open each page and explain what it does + which APIs it hits:

| Page | Product job |
|------|-------------|
| `index.html` | Landing + 3D house showcase |
| `listings.html` | Browse / map / post / chat |
| `listing_details.html` | Single listing |
| `ai-negotiator.html` | Flagship AI negotiation UI |
| `legal.html` | Calculators + lease review + docs |
| `roommate-matching.html` | RoomPal |
| `sublease.html` | Sublease marketplace |
| `student-housing.html` | University + budget tools |
| `pricing.html` | Free vs Pro |
| `support.html` | FAQ + AI support + contact |
| `platform-status.html` | Mobile closed notice |

---

## Phase I — Interview drill bank (Days 24–28)

Practice out loud. Aim for 60–90 second answers, then go deeper if asked.

### Architecture
1. Draw the system on a whiteboard.  
2. Why Express monolith instead of microservices?  
3. Why vanilla JS instead of React/Next?  
4. What would you extract first if the server keeps growing?

### Auth & data
5. End-to-end login for email and for Google.  
6. Anon vs service role.  
7. How favorites stay private.  
8. How you would prevent IDOR on `PUT /api/listings/:id`.

### AI
9. Explain the negotiation phases and why order matters.  
10. How failover works when OpenAI is down.  
11. How the daemon differs from client-only polling.  
12. How Free vs Pro AI limits are enforced.  
13. Prompt injection risks on `/api/chat` and mitigations you would add.

### Marketplace
14. Post listing with photos end-to-end.  
15. How geocoding failure is handled.  
16. RoomPal matching: is it ML? (Be honest.)

### Money & email
17. Stripe webhook flow.  
18. Why webhook body must stay raw.  
19. What emails Brevo sends.

### Failure & scale
20. What does `/health` return when Supabase is down?  
21. Rate limiting strategy (in-memory Map — limitation on multi-instance).  
22. What breaks if Railway runs 2 replicas? (in-memory rate limits + daemon `inFlight` Set).  
23. Biggest technical debt in `server.js` and your refactor plan.

### Behavioral / ownership
24. A production bug you diagnosed (use `LEARN.md` stories: postal code, App Links, branch drift).  
25. Tradeoff you disagree with and what you’d change next.

---

## Recommended weekly schedule (fits your system)

| Slot | Focus |
|------|--------|
| Weekday 30–45 min | One topic from Phases A–G + 2 drill questions aloud |
| Weekend 1.5–3 hrs | One deep vertical: Auth **or** AI phases **or** Stripe+webhook **or** full listing post |
| Every Sunday | Re-say the 1-minute pitch + draw the architecture from memory |

**Order of mastery (priority for interviews):**
1. Pitch + architecture diagram  
2. AI negotiation phases + `callAI` failover + daemon  
3. Auth + Supabase roles  
4. Listings + storage  
5. Stripe Pro  
6. Deploy/ops stories  
7. RoomPal / sublease / legal (supporting features)

---

## Hands-on lab checklist (do these once)

- [ ] Run locally: `cp .env.example .env` → `npm install` → `npm run validate` → `npm start`  
- [ ] Hit `/health`, `/api/config`, `/api/listings`  
- [ ] Create an account, verify email path (or understand Brevo dependency)  
- [ ] Browse listings + open details  
- [ ] Start AI negotiator and watch network tab for `/api/negotiate/*`  
- [ ] Read one full negotiation reply in Network → Response  
- [ ] Trace Stripe webhook handler code (even without live payment)  
- [ ] Open `ai-providers.js` and explain failover without notes  
- [ ] Open `negotiator-daemon.js` and explain the tick loop  
- [ ] Skim 3 RLS migration files and summarize the trend  

---

## “Explain like an engineer” cheat sheet

| Topic | Strong answer skeleton |
|-------|------------------------|
| Stack | Express 5 + vanilla frontend + Supabase + Railway + Stripe + OpenAI/Groq + Brevo |
| Differentiator | Phased AI negotiation + server daemon + market estimates |
| Auth | Supabase Auth; client manager; server `requireAuth`; profiles via API |
| AI cost control | Provider failover, session quotas, IP rate limits, message caps |
| Data | Postgres tables + Storage buckets; RLS + server checks |
| Deploy | Single process, static + API, healthcheck, env on Railway |
| Mobile | Closed while web stabilized; status API + banner |
| Debt | Monolithic `server.js`; in-memory rate limits; some optional/stub market APIs |

---

## What *not* to say in interviews

- “AI wrote the whole thing” → instead: “We used AI-assisted development; I own the architecture, auth, negotiation design, and production ops.”  
- Overselling unused APIs as “our ML stack.”  
- Claiming mobile is live (it is closed / in preparation).  
- Pasting secrets or saying keys are in the repo.

---

## Source map (when you forget)

| Need | Open |
|------|------|
| Master docs | `DOCUMENTATION.md` |
| Every integration | `docs/ALL_CONNECTIONS.md` |
| Feature status | `docs/FEATURE_STATUS_AND_TODO.md` |
| Non-obvious production lessons | `LEARN.md` |
| Platform status | `docs/PLATFORM_STATUS.md` |
| This learning plan | `docs/INTERVIEW_LEARNING_PLAN.md` |

---

## Progress tracker

Copy into notes and tick as you complete:

- [ ] Phase A Foundations  
- [ ] Phase B Auth  
- [ ] Phase C Listings / chat / RoomPal / sublease  
- [ ] Phase D AI (providers, phases, daemon, market, learning)  
- [ ] Phase E Stripe / Brevo / verify  
- [ ] Phase F DB / RLS / security  
- [ ] Phase G Deploy  
- [ ] Phase H All product pages walked  
- [ ] Phase I Drill bank (all 25 answers aloud once)  
- [ ] Mock interview: 20 minutes whiteboard + 10 minutes deep-dive on AI  

When you can teach Phase D and B to someone else without the doc, you are interview-ready on this project.
