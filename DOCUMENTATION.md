# RoomFinderAI — Full Documentation

**Last updated:** July 4, 2026 (full platform overhaul — nav, listings, RoomPal, Stripe Pro, legal, support)  
**Production URL:** [https://www.roomfinderai.com](https://www.roomfinderai.com)  
**Primary branch:** `main` (deploy from `main`; `hasan` merged in July 2026)

---

## 1. Platform status (read this first)

| Platform | Folder | Status | Public access |
|----------|--------|--------|---------------|
| **Web** | `frontend/` + `backend/` | **ACTIVE** | [roomfinderai.com](https://www.roomfinderai.com) |
| **Android** | `RoomFinderAndroid-CLOSED/` | **CLOSED (temporary)** | Not on Google Play. Do not distribute APKs. |
| **iOS** | `RoomFinderAI-IOS-CLOSED/` | **CLOSED (temporary)** | Not on App Store or TestFlight. |
| Legacy Android | `archive/legacy-android/android/` | Archived | Deprecated Capacitor app |

> **Only the website is live for users.** Native mobile app folders are renamed with `-CLOSED` so contributors see they are paused. Source code is kept for a future re-launch.

**Public status page:** [/platform-status.html](https://www.roomfinderai.com/platform-status.html)  
**API:** `GET /api/platform-status` · `GET /health`

### Why mobile is closed

1. Web platform is stabilized first (auth, listings, AI negotiator, Supabase).
2. Backend integrations (storage, email, OpenAI rate limits) need parity before mobile ships.
3. Reduces support load from incomplete native builds.

### When mobile reopens

1. Rename folders back: `RoomFinderAndroid-CLOSED` → `RoomFinderAndroid`, `RoomFinderAI-IOS-CLOSED` → `RoomFinderAI-IOS`.
2. Set `status: 'active'` in `backend/platform-status.js`.
3. Update this file, `README.md`, and `docs/PLATFORM_STATUS.md`.
4. Remove or reduce web banner in `frontend/js/platform-status-banner.js`.
5. Complete store listings, signing, and E2E tests before public release.

---

## 2. Repository structure

```
RoomFinderAI/
├── DOCUMENTATION.md          # This file — master reference
├── README.md                 # GitHub landing page (short overview)
├── backend/                  # Express 5 API server (production entry)
│   ├── server.js             # Main server (~10k lines)
│   ├── ai-providers.js       # OpenAI + Groq failover chain
│   ├── platform-status.js    # Platform flags (web/android/ios)
│   ├── reliability.js        # Rate limits, error handling, prod gates
│   └── html-inject.js        # Injects platform banner into HTML
├── frontend/                 # Web UI (HTML/CSS/vanilla JS)
│   ├── index.html            # Homepage (3D house model showcase)
│   ├── listings.html         # Listings + chat + add listing
│   ├── ai-negotiator.html    # AI negotiation UI
│   ├── legal.html            # Legal tools, calculators, document generator
│   ├── sublease.html         # Sublease marketplace
│   ├── student-housing.html  # University search + budget tools
│   ├── roommate-matching.html # RoomPal roommate matching
│   ├── pricing.html          # Free vs Pro plans + Stripe Checkout
│   ├── support.html          # FAQ, AI support agent, contact form
│   ├── platform-status.html  # Public platform notice page
│   ├── universal-auth-manager.js  # Canonical auth UI (all pages)
│   ├── 3D House Models/      # Homepage showcase PNG assets
│   └── js/
│       ├── site-nav.js       # Canonical nav injection
│       └── platform-status-banner.js
├── RoomFinderAndroid-CLOSED/ # Native Android (Java) — LOCKED
├── RoomFinderAI-IOS-CLOSED/  # Native iOS (SwiftUI) — LOCKED
├── database/
│   ├── migrations/           # Supabase schema migrations
│   └── sql/                  # One-off SQL scripts (storage, seed data)
├── scripts/
│   ├── refresh-listings.js   # Replace junk listings with photo catalog
│   ├── maintenance/          # Debug & test scripts
│   ├── migrations/           # Data migration scripts
│   └── tools/                # Utilities (encrypt, analyze)
├── docs/
│   ├── PLATFORM_STATUS.md    # Platform availability detail
│   └── guides/               # Setup, deployment, feature docs
├── archive/                  # Legacy code & unrelated files
├── builds/                   # APK artifacts (gitignored locally)
├── ai-learning/              # AI learning module
├── cloudflare-worker/        # Edge worker
├── tests/                    # Integration tests
├── railway.json              # Railway deploy config
├── nixpacks.toml             # Nixpacks build config
├── start.sh                  # Manual start script
├── validate-config.js        # Env validation CLI
└── .env.example              # Environment template (copy to .env)
```

---

## 3. Quick start (web — local)

```bash
# 1. Clone and install
git clone https://github.com/redhasanh1/RoomFinderAI.git
cd RoomFinderAI
git checkout main
npm install

# 2. Configure environment
cp .env.example .env
# Edit .env with your Supabase + API keys (never commit .env)

# 3. Validate
npm run validate

# 4. Start server
npm start
# → http://localhost:3000
```

**Health checks:**
- `GET http://localhost:3000/health`
- `GET http://localhost:3000/api/platform-status`
- `GET http://localhost:3000/api/service-status`

**Production smoke test (after deploy):**
```bash
bash scripts/production-smoke-test.sh
# If TLS fails locally: SMOKE_CURL_INSECURE=1 bash scripts/production-smoke-test.sh
```
Verify in browser: `/health` (JSON), `/debug-test` (404), `/listings.html` (map loads).

---

## 4. Environment variables

Copy `.env.example` → `.env`. On **Railway**, set the same keys in the project Variables dashboard.

### Required (production web)

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Public anon key for client auth |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin ops (storage buckets, auth admin) — **set on Railway** |
| `OPENAI_API_KEY` | AI negotiator & chat (primary provider) |
| `GROQ_API_KEY` | AI fallback when OpenAI fails or is out of quota (free at console.groq.com) |
| `AI_PROVIDER` | `auto` (default), `openai`, or `groq` |
| `GROQ_MODEL` | Groq primary model (default `llama-3.1-8b-instant`) |
| `GROQ_FALLBACK_MODEL` | Groq secondary model (default `llama-3.3-70b-versatile`) |
| `PORT` | Server port (Railway sets automatically) |
| `NODE_ENV` | `production` on Railway |

### Payments & maps

| Variable | Purpose |
|----------|---------|
| `STRIPE_SECRET_KEY` | Stripe server-side |
| `STRIPE_PUBLISHABLE_KEY` | Stripe client (via `/api/config`) |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signature verification (`POST /api/stripe-webhook`) |
| `STRIPE_PRO_PRICE_ID` | Optional — Stripe Price ID for Pro; if unset, checkout uses inline $19.99/mo |
| `GOOGLE_API_KEY` | Google Maps (restrict by HTTP referrer in Google Cloud) |
| `GOOGLE_OAUTH_CLIENT_ID` | Google sign-in |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Google OAuth server |

### Email & verification

| Variable | Purpose |
|----------|---------|
| `BREVO_API_KEY` | Transactional email (verification, reset) — **must be valid** |

### Optional

| Variable | Purpose |
|----------|---------|
| `AZURE_DOCUMENT_INTELLIGENCE_*` | ID document verification |
| `AZURE_FACE_*` | Face API verification |
| `RENTCAST_KEY` | Market data API |
| `VOYAGE_API_KEY` | Voyage embeddings — **reserved** for future semantic search (not implemented yet) |
| `TURNSTILE_SITE_KEY` | Cloudflare Turnstile |
| `ADMIN_KEY` | Protected admin routes (required in production) |
| `ENABLE_DEMO_MODE` | `false` in production |
| `ENABLE_ANONYMOUS_BROWSING` | Allow browse without login (default `true`) |
| `ENABLE_DEBUG_ROUTES` | `false` in production |

**Never commit:** `.env`, `config.js`, service role keys, or API secrets in source files.

---

## 5. Backend architecture

**Entry point:** `node backend/server.js` (via `railway.json` / `npm start`)

### Stack

- **Runtime:** Node.js 18+
- **Framework:** Express 5
- **Database / Auth:** Supabase (PostgreSQL + Auth + Storage + Realtime)
- **AI:** OpenAI (primary) with Groq failover (`backend/ai-providers.js`)
  - Chain when `AI_PROVIDER=auto`: OpenAI → `llama-3.1-8b-instant` → `llama-3.3-70b-versatile`
  - Set `GROQ_API_KEY` on Railway so AI keeps working if OpenAI quota/billing fails
- **Payments:** Stripe Checkout (subscriptions) + legacy Elements/charges endpoint
- **Email:** Brevo (Sendinblue)
- **Deploy:** Railway (Nixpacks)

### Key modules

| File | Role |
|------|------|
| `backend/server.js` | Routes, Supabase init, static serving, AI endpoints |
| `backend/ai-providers.js` | Multi-provider AI with automatic failover |
| `backend/platform-status.js` | Single source of truth for platform availability |
| `backend/reliability.js` | Rate limits, prod debug gating, global errors |
| `backend/html-inject.js` | Injects canonical nav + platform banner into all HTML responses |

### Static serving

- Serves **`frontend/`** at site root (not entire repo).
- Also serves **`frontend/3D House Models/`** for homepage showcase assets.
- HTML pages get canonical nav (`site-nav.js`) and platform-status banner injected automatically.

### Reliability features

- Global error handler + unhandled rejection logging
- `trust proxy` for Railway (correct client IPs for rate limits)
- Auth endpoint rate limiting (login, verify, reset)
- **AI session limits:** Free plan = 20 AI sessions/month per user; Pro = unlimited (`profiles.is_pro`)
- Hourly/daily abuse caps on AI endpoints (100/hr, 500/day)
- Debug/test routes blocked in production
- `GET /api/listings` supports `?city=` filter; `GET /api/listings/:id` queries Supabase
- Demo data only when `ENABLE_DEMO_MODE=true`
- Health returns `degraded` + 503 if Supabase down in production
- CORS restricted to `roomfinderai.com` + localhost

### Important API routes

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Service + platform health |
| GET | `/api/platform-status` | Web/android/ios availability JSON |
| GET | `/api/config` | Client-safe config (Supabase URL, Stripe pub key, etc.) |
| GET | `/api/service-status` | Feature flags for frontend |
| GET | `/api/listings` | All listings; optional `?city=` filter |
| GET | `/api/listings/:id` | Single listing |
| POST | `/api/listings` | Create listing |
| POST | `/api/login` | Login |
| POST | `/api/ai-negotiate` | AI negotiation |
| POST | `/api/chat` | AI chat (modes: `rental`, `support`, `legal-document`, `legal-advice`) |
| POST | `/api/create-checkout-session` | Stripe Checkout for Pro subscription |
| POST | `/api/stripe-webhook` | Stripe webhook — activates Pro on `checkout.session.completed` |
| POST | `/api/contact` | Support contact form → `contact_messages` + Brevo |
| GET | `/api/sublease/search` | Sublease browse (public without login; excludes own rows when logged in) |
| POST | `/api/sublease/express-interest` | Express interest on a sublease request |
| GET | `/api/user-profile/:email` | Profile data including `isPro`, `plan` |

Full API docs: `docs/API_DOCUMENTATION.md`

### Pricing plans

| Plan | Price | AI sessions | Checkout |
|------|-------|-------------|----------|
| Free | $0/mo | 20/month | N/A — sign up at `/login.html` |
| Pro | $19.99/mo | Unlimited | `/pricing.html` → Stripe Checkout via `POST /api/create-checkout-session` |

Pro status is stored on `profiles.is_pro` and reflected in the nav profile badge. Stripe webhook (`checkout.session.completed`) activates Pro automatically.

---

## 6. Frontend architecture

**Stack:** Vanilla HTML/CSS/JavaScript (no React build step for main site)

### Site-wide navigation (canonical)

All pages share one header via `frontend/js/site-nav.js`, injected by `backend/html-inject.js`:

| Item | Link |
|------|------|
| Home | `index.html` |
| RoomPal | `roommate-matching.html` |
| Browse → Listings | `listings.html` |
| Browse → Student Housing | `student-housing.html` |
| Browse → Subleasing | `sublease.html` |
| Tools → AI Negotiator | `ai-negotiator.html` |
| Tools → Legal Help | `legal.html` |
| More → About, Pricing, Contact, Support | respective pages |
| Profile (logged in only) | `profile.html` |

Notification bell slot is preserved for the AI negotiator page.

### Authentication (canonical)

- **`frontend/universal-auth-manager.js`** is the single auth UI updater on all pages.
- Login, forgot-password, and verification-modal also load it.
- `currentUser` in `localStorage` uses the real Supabase `profiles.id`.
- Google OAuth new-user path creates profiles with the auth user id (not random UUIDs).
- **Verification modal** is a one-time Turnstile gate — skipped if already verified.
- Pro users see a **PRO** badge on the profile avatar in the nav.

### Key pages

| Page | File | Purpose |
|------|------|---------|
| Home | `frontend/index.html` | Landing + 3D house model showcase grid |
| Listings | `frontend/listings.html` | Browse, search, chat, post, favorites |
| AI Negotiator | `frontend/ai-negotiator.html` | AI rental negotiation |
| Legal | `frontend/legal.html` | Quick scenarios, calculators, documents, lease review |
| Sublease | `frontend/sublease.html` | Post (default tab), browse, my requests |
| Disputes | `frontend/file-dispute.html`, `my-disputes.html` | File and track disputes |
| Student housing | `frontend/student-housing.html` | University search, budget tools, city listings |
| RoomPal | `frontend/roommate-matching.html` | Profile-first roommate matching + messaging |
| Pricing | `frontend/pricing.html` | Free ($0) vs Pro ($19.99/mo) + Stripe Checkout |
| Support | `frontend/support.html` | AI assistant, customer care ticket, FAQ |
| Login / Signup | `frontend/login.html`, `signup.html` | Auth |
| Platform status | `frontend/platform-status.html` | Mobile-closed notice |

### Client config flow

1. Pages load `frontend/js/supabase-config-init.js`
2. Fetches `GET /api/config` for Supabase URL + anon key
3. Auth via **`universal-auth-manager.js`** (canonical on all pages)

### Path convention

Assets are served from **site root**, not `/frontend/`:

- ✅ `/modules/css/main.css`
- ✅ `/3D House Models/WhatsApp_Image_...png`
- ✅ `/universal-auth-manager.js`
- ❌ `/frontend/modules/css/main.css` (404)

### Site-wide platform banner

- `frontend/js/platform-status-banner.js` — injected on every HTML page
- `frontend/css/platform-status.css` — layout offsets for fixed headers
- Dismissible per browser session

---

## 7. Supabase setup

### Project

Production uses a Supabase project configured via env vars. Credentials are **never** in the repo.

### Database

- Schema migrations: `database/migrations/`
- One-off fixes: `database/sql/`
  - `setup-supabase-storage.sql` — storage buckets
  - `seed-test-data.sql` — demo listings, sublease, RoomPal, AI history (safe to re-run)
  - `seed-test-data-cleanup.sql` — remove all `@roomfinderai.test` seed rows
  - `supabase-migrations.sql` — core tables

### Tables (feature coverage)

| Table | Feature | Migration / seed |
|-------|---------|------------------|
| `listings` | Browse, map, post | Core schema + `add_listings_coordinates.sql` |
| `sublease_requests` | Sublease marketplace | `simple_sublease_schema.sql` |
| `roommate_profiles` | RoomPal matching | `roommate_profiles_schema_v2.sql` |
| `roommate_conversations` | RoomPal messaging | `create_roommate_messaging.sql` |
| `roommate_messages` | RoomPal chat messages | `create_roommate_messaging.sql` |
| `profiles.is_pro`, `profiles.plan` | Pro membership flag | `add_profiles_is_pro.sql` |
| `subscriptions` | Pro billing records | `create_subscriptions_table.sql` + `confirm_subscriptions_pro_wallet.sql` |
| `contact_messages` | Support contact form | `create_contact_messages.sql` |
| `ai_negotiations` | AI negotiator history | Created by backend inserts |
| `ai_chat_history` | AI chat persistence | `add_ai_chat_history.sql` |
| `conversations`, `messages` | Listing chat | Core schema |
| `favorites` | Saved listings | Core schema |

### Listings catalog maintenance

Use `scripts/refresh-listings.js` to replace junk or pictureless rows with a permanent photo catalog:

```bash
node scripts/refresh-listings.js            # dry run — shows plan
node scripts/refresh-listings.js --apply    # delete junk + insert 8 city listings
```

Requires `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` in `.env`. Listings are tagged `[rf-catalog]` in the description for idempotent re-runs.

### Storage buckets

- `listing-media` — property photos (upload path: `listing-media/Photos/...`)
- `profile-images`, `chat-attachments`, `verification-docs`
- Run **`database/sql/setup-supabase-storage.sql`** in Supabase SQL Editor as **one query** (idempotent — safe to re-run)
- If you see `column "participant1_id" does not exist`, you ran an **old** copy — use the file from latest `main`, or run `setup-supabase-storage-buckets-only.sql` first, then the full file
- Requires `SUPABASE_SERVICE_ROLE_KEY` on server for admin storage operations

### Auth

- Supabase Auth for sign-up, login, sessions
- Client loads anon key from `/api/config`
- Server validates Bearer tokens via `requireAuth` middleware on protected routes

---

## 8. Railway deployment

**Short checklist (only step left for go-live):** [`docs/RAILWAY_ONLY.md`](docs/RAILWAY_ONLY.md)

### Config files

| File | Purpose |
|------|---------|
| `railway.json` | Build + start + healthcheck |
| `nixpacks.toml` | Node build, `NODE_ENV=production` |
| `.railwayignore` | Excludes mobile apps, archive, tests from deploy |

### Deploy command

```bash
node backend/server.js
```

### Healthcheck

- Path: `/health`
- Timeout: 120s
- Returns 503 in production if Supabase is unavailable

### Deploy branch

**Railway must deploy from `main`.** In Railway → Project → Settings → Source → set branch to `main` (if it still points to `hasan`).

### Before each push

```bash
git pull origin main   # Always pull first
# ... make changes ...
git push origin main
```

### Railway variables checklist

- [ ] `SUPABASE_URL`
- [ ] `SUPABASE_ANON_KEY`
- [ ] `SUPABASE_SERVICE_ROLE_KEY`
- [ ] `OPENAI_API_KEY` or `GROQ_API_KEY` (at least one for AI)
- [ ] `GROQ_API_KEY` (recommended — free tier)
- [ ] `BREVO_API_KEY` (valid — check `/health` → `brevo: true`)
- [ ] `STRIPE_SECRET_KEY` + `STRIPE_PUBLISHABLE_KEY`
- [ ] `STRIPE_WEBHOOK_SECRET` (Stripe Dashboard → Webhooks → `https://www.roomfinderai.com/api/stripe-webhook`)
- [ ] `STRIPE_PRO_PRICE_ID` (optional — omit to use inline $19.99/mo)
- [ ] `GOOGLE_API_KEY` (referrer-restricted)
- [ ] `ADMIN_KEY` (strong random)
- [ ] `ENABLE_DEMO_MODE=false`
- [ ] `NODE_ENV=production`

### Supabase SQL checklist

- [ ] `database/sql/setup-supabase-storage.sql` — listing photo uploads
- [ ] `database/migrations/roommate_profiles_schema_v2.sql` — RoomPal profiles
- [ ] `database/migrations/create_roommate_messaging.sql` — RoomPal chat tables
- [ ] `database/migrations/add_profiles_is_pro.sql` — Pro flag on profiles
- [ ] `database/migrations/confirm_subscriptions_pro_wallet.sql` — allow `pro` plan + `wallet` payment method
- [ ] `database/migrations/simple_sublease_schema.sql` — sublease marketplace
- [ ] `database/migrations/create_contact_messages.sql` — support contact form
- [ ] `database/sql/seed-test-data.sql` — sample data (optional; production uses `refresh-listings.js` catalog)

---

## 9. Mobile apps (CLOSED — do not ship)

### Android — `RoomFinderAndroid-CLOSED/`

- **Stack:** Java, Android Views, Retrofit, Material Design 3
- **Status:** Folder renamed with `-CLOSED`. See `PLATFORMS_LOCKED.md` inside.
- **Build (contributors only):** JDK 17, Android SDK, `local.properties`
- **Do not:** Publish APKs, share debug builds, or point users to Play Store

### iOS — `RoomFinderAI-IOS-CLOSED/`

- **Stack:** SwiftUI, Supabase Swift SDK, iOS 16+
- **Status:** Folder renamed with `-CLOSED`. See `PLATFORMS_LOCKED.md` inside.
- **Build:** Requires Xcode + signing team. See `BUILD-AND-RUN.md`.
- **Do not:** Submit to App Store Connect or distribute TestFlight builds

### Legacy Android

- `archive/legacy-android/android/` — old Capacitor-style app, fully archived

---

## 10. Security notes

- Admin routes require `ADMIN_KEY` (no default in production)
- Debug routes (`/api/test-*`, `/api/debug/*`) disabled in production
- Rate limits on auth and OpenAI endpoints
- CORS limited to production domain + localhost
- Rotate any keys that were ever committed in old migration scripts
- Google Maps key: HTTP referrer restriction in Google Cloud Console
- Service role key: server-only, never expose to frontend

---

## 11. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Listings empty / demo data | Supabase down or `ENABLE_DEMO_MODE` | Check `/health`, verify env vars |
| Email verification broken | Invalid `BREVO_API_KEY` | Rotate key in Brevo, update Railway |
| AI negotiator error / blank | OpenAI quota or no AI keys | Add `GROQ_API_KEY`; chain is OpenAI → Groq. Check `/health` and Railway logs. |
| AI negotiator 429 | Free monthly limit (20) or hourly cap | Upgrade to Pro on `/pricing.html`; Pro users have unlimited AI sessions |
| Pro checkout fails | Missing Stripe webhook secret | Set `STRIPE_WEBHOOK_SECRET`; configure webhook URL in Stripe Dashboard |
| RoomPal chat empty | Messaging tables missing | Run `create_roommate_messaging.sql` in Supabase |
| Sublease browse requires login | Old deploy | Browse is public; express interest still requires login |
| Upload fails | Storage bucket missing | Run `database/sql/setup-supabase-storage.sql` |
| AI negotiator blank page | Wrong asset paths | Use root paths, not `/frontend/...` |
| Maps not loading | Google key missing/restricted | Set `GOOGLE_API_KEY`, check referrer rules |
| Health `degraded` | Supabase connection failed | Verify URL + anon key on Railway |

**Validate locally:**
```bash
npm run validate
curl http://localhost:3000/health
```

---

## 12. Related documentation

| Document | Location |
|----------|----------|
| QA audit (July 2026) | `docs/QA_AUDIT_JULY_2026.md` |
| **Live integrations audit** | `docs/LIVE_INTEGRATIONS_AUDIT.md` |
| **All connections (auth, payments, maps, AI)** | `docs/ALL_CONNECTIONS.md` |
| Phase 5 setup guide | `docs/PHASE_5_SETUP_GUIDE.md` |
| **Project completion checklist** | `docs/PROJECT_COMPLETION_CHECKLIST.md` |
| **Feature status & your action list** | `docs/FEATURE_STATUS_AND_TODO.md` |
| Production smoke test | `scripts/production-smoke-test.sh` |
| Platform status (detail) | `docs/PLATFORM_STATUS.md` |
| Setup guide | `docs/guides/SETUP_GUIDE.md` |
| Railway deployment | `docs/RAILWAY_ONLY.md` (quick) · `docs/RAILWAY_DEPLOYMENT.md` (full) |
| API reference | `docs/API_DOCUMENTATION.md` |
| Android locked notice | `RoomFinderAndroid-CLOSED/PLATFORMS_LOCKED.md` |
| iOS locked notice | `RoomFinderAI-IOS-CLOSED/PLATFORMS_LOCKED.md` |
| Archive index | `archive/README.md` |
| Gemini / codebase analysis | `CLAUDE.md` |

---

## 13. Git & commit guidelines

- Pull `main` before pushing
- Descriptive commit messages — no AI references in commits
- Never commit `.env`, secrets, or APK files
- Website only (not mobile app releases while folders are `-CLOSED`)
- **No `Co-authored-by` trailers** — Cursor, Claude, and bot co-authors pollute the contributor list. History was scrubbed July 2026; prevent recurrence:

```bash
chmod +x scripts/git-hooks/prepare-commit-msg
git config core.hooksPath scripts/git-hooks
```

To re-scrub history if needed: pipe `scripts/git-hooks/clean-commit-msg.sh` through `git filter-branch --msg-filter`.

---

## 15. July 2026 full overhaul — change log

Delivered in 7 phases (commits `5e99c4ea` → `d559ba60`). Summary of what changed:

### Phase 1 — Nav + auth consistency
- Canonical nav on every page: Home, RoomPal, Browse (Listings / Student Housing / Subleasing), Tools (AI Negotiator / Legal Help), More, Profile (when logged in).
- Removed per-page custom auth renderers; all pages use `universal-auth-manager.js`.
- Google OAuth uses real Supabase profile ids; profile image column unified to `profile_image_url`.
- Verification modal is a one-time Turnstile gate (not shown on every login).

### Phase 2 — Listings + favorites
- Live catalog refreshed via `scripts/refresh-listings.js --apply` (8 permanent listings with real Unsplash photos across Canadian cities).
- Fixed double-submit on add-listing form; photo wizard targets `#add-listing`.
- Search bar wired to filter listings; favorites work in profile and `favorites.html`.
- Removed junk/demo listings (including user-posted test rows like "CANUCKS").

### Phase 3 — RoomPal (roommate matching)
- Profile-first flow: matches grid hidden until user creates a roommate profile.
- Match cards sorted high→low; detail modal; View + Connect buttons.
- Fixed tab handlers, contact modal, header auth wiring.
- "I have a space" opens add-listing flow on listings page.
- Migration: `roommate_conversations` + `roommate_messages`.

### Phase 4 — Sublease + student housing
- Sublease default tab is **Post Request**; browse works without login.
- Fixed `express-interest` API (`requestId` + `userEmail` from browse cards).
- Optional photo upload on sublease create form.
- Student housing: `setBudget` / `updateSimpleBudget`; university housing URLs; city-filtered `/api/listings?city=`.
- Removed mock roommate cards from student portal → links to RoomPal.

### Phase 5 — Legal + AI
- AI provider chain: OpenAI → Groq (`llama-3.1-8b-instant` → `llama-3.3-70b-versatile`) with clear 503 errors when all fail.
- Legal: `quickStartScenario`, `switchCalculator`, prorated/late-fee/damages calculators wired.
- Document download label corrected to "Download Text".

### Phase 6 — Pricing + Pro (Stripe Checkout)
- **Free:** $0/mo, 20 AI sessions/month.
- **Pro:** $19.99/mo, unlimited AI sessions.
- `POST /api/create-checkout-session` → Stripe Checkout subscription.
- `POST /api/stripe-webhook` → sets `profiles.is_pro` + `subscriptions` on payment success.
- Pricing page "Choose Pro" button starts Checkout (replaces broken `/payment` route).
- Pro badge shown in nav profile avatar.

### Phase 7 — Support
- AI support agent via `/api/chat` mode `support` with FAQ fallback.
- Contact form → `POST /api/contact` → `contact_messages` + Brevo email.
- Customer Care ticket card added; FAQ pricing corrected to $19.99/mo.

### Homepage assets
- 11 house model PNGs committed to `frontend/3D House Models/` for the index showcase grid.
- IntersectionObserver reveal fix so homepage sections are visible on scroll.

---

## 16. Summary

**RoomFinderAI is a web-first platform** deployed on Railway with Supabase as the backend. The website at [roomfinderai.com](https://www.roomfinderai.com) is the only active user-facing product. Android and iOS native apps exist in `*-CLOSED` folders for future development but must not be distributed. Use this document as the single reference for structure, setup, deployment, and platform status.
