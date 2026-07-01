# RoomFinderAI — Full Documentation

**Last updated:** July 1, 2026  
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

> **Only the website is live for users.** Native mobile app folders are renamed with `-CLOSED` so contributors and GitHub visitors see they are paused. Source code is kept for a future re-launch.

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
│   ├── platform-status.js    # Platform flags (web/android/ios)
│   ├── reliability.js        # Rate limits, error handling, prod gates
│   └── html-inject.js        # Injects platform banner into HTML
├── frontend/                 # Web UI (HTML/CSS/vanilla JS)
│   ├── index.html            # Homepage
│   ├── listings.html         # Listings + chat
│   ├── ai-negotiator.html    # AI negotiation UI
│   ├── platform-status.html  # Public platform notice page
│   └── js/                   # Client scripts (auth, config, banner)
├── RoomFinderAndroid-CLOSED/ # Native Android (Java) — LOCKED
├── RoomFinderAI-IOS-CLOSED/  # Native iOS (SwiftUI) — LOCKED
├── database/
│   ├── migrations/           # Supabase schema migrations
│   └── sql/                  # One-off SQL scripts
├── scripts/
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
├── 3D House Models/          # Static 3D assets
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

---

## 4. Environment variables

Copy `.env.example` → `.env`. On **Railway**, set the same keys in the project Variables dashboard.

### Required (production web)

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Public anon key for client auth |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin ops (storage buckets, auth admin) — **set on Railway** |
| `OPENAI_API_KEY` | AI negotiator & chat |
| `PORT` | Server port (Railway sets automatically) |
| `NODE_ENV` | `production` on Railway |

### Payments & maps

| Variable | Purpose |
|----------|---------|
| `STRIPE_SECRET_KEY` | Stripe server-side |
| `STRIPE_PUBLISHABLE_KEY` | Stripe client (via `/api/config`) |
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
- **AI:** OpenAI API (negotiation, chat, landlord simulator)
- **Payments:** Stripe
- **Email:** Brevo (Sendinblue)
- **Deploy:** Railway (Nixpacks)

### Key modules

| File | Role |
|------|------|
| `backend/server.js` | Routes, Supabase init, static serving, AI endpoints |
| `backend/platform-status.js` | Single source of truth for platform availability |
| `backend/reliability.js` | Rate limits, prod debug gating, global errors |
| `backend/html-inject.js` | Injects platform banner into all HTML responses |

### Static serving

- Serves **`frontend/`** at site root (not entire repo).
- Also serves **`3D House Models/`** for 3D assets.
- HTML pages get platform-status banner injected automatically.

### Reliability features (recent)

- Global error handler + unhandled rejection logging
- `trust proxy` for Railway (correct client IPs for rate limits)
- Auth endpoint rate limiting (login, verify, reset)
- OpenAI endpoint rate limiting
- Debug/test routes blocked in production
- `GET /api/listings/:id` queries Supabase (not demo-only)
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
| GET | `/api/listings` | All listings (Supabase) |
| GET | `/api/listings/:id` | Single listing |
| POST | `/api/listings` | Create listing |
| POST | `/api/login` | Login |
| POST | `/api/ai-negotiate` | AI negotiation |
| POST | `/api/chat` | AI chat |

Full API docs: `docs/API_DOCUMENTATION.md`

---

## 6. Frontend architecture

**Stack:** Vanilla HTML/CSS/JavaScript (no React build step for main site)

### Key pages

| Page | File | Purpose |
|------|------|---------|
| Home | `frontend/index.html` | Landing, auth, hero |
| Listings | `frontend/listings.html` | Browse, search, chat, post |
| AI Negotiator | `frontend/ai-negotiator.html` | AI rental negotiation |
| RoomPal | `frontend/roommate-matching.html` | Roommate matching |
| Login / Signup | `frontend/login.html`, `signup.html` | Auth |
| Platform status | `frontend/platform-status.html` | Mobile-closed notice |
| Support | `frontend/support.html` | Help & FAQ |

### Client config flow

1. Pages load `frontend/js/supabase-config-init.js`
2. Fetches `GET /api/config` for Supabase URL + anon key
3. Auth via `universal-auth-manager.js` or `supabase-auth-only.js`

### Path convention

Assets are served from **site root**, not `/frontend/`:

- ✅ `/modules/css/main.css`
- ✅ `/ai-negotiation.js`
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
  - `supabase-migrations.sql` — core tables

### Storage buckets

- `listing-media` — property photos
- Run `database/sql/setup-supabase-storage.sql` in Supabase SQL editor if uploads fail
- Requires `SUPABASE_SERVICE_ROLE_KEY` on server for bucket creation at startup

### Auth

- Supabase Auth for sign-up, login, sessions
- Client loads anon key from `/api/config`
- Server validates Bearer tokens via `requireAuth` middleware on protected routes

---

## 8. Railway deployment

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
- [ ] `OPENAI_API_KEY`
- [ ] `BREVO_API_KEY` (valid — check `/health` → `brevo: true`)
- [ ] `STRIPE_SECRET_KEY` + `STRIPE_PUBLISHABLE_KEY`
- [ ] `GOOGLE_API_KEY` (referrer-restricted)
- [ ] `ADMIN_KEY` (strong random)
- [ ] `ENABLE_DEMO_MODE=false`
- [ ] `NODE_ENV=production`

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
| AI negotiator 429 | OpenAI rate limit | Wait or check key quota |
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
| Platform status (detail) | `docs/PLATFORM_STATUS.md` |
| Setup guide | `docs/guides/SETUP_GUIDE.md` |
| Railway deployment | `docs/RAILWAY_DEPLOYMENT.md` |
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

---

## 14. Summary

**RoomFinderAI is a web-first platform** deployed on Railway with Supabase as the backend. The website at [roomfinderai.com](https://www.roomfinderai.com) is the only active user-facing product. Android and iOS native apps exist in `*-CLOSED` folders for future development but must not be distributed. Use this document as the single reference for structure, setup, deployment, and platform status.
