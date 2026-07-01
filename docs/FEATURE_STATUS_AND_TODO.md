# RoomFinderAI — Feature Status & Your Action List

**Last updated:** July 1, 2026  
**Production:** [roomfinderai.com](https://www.roomfinderai.com) · Branch: **`main`**

This document lists every major feature, what was fixed in code, what works today, and **what only you can do** (Railway keys, Supabase dashboard, third-party accounts).

---

## Production status right now

| Service | Status |
|---------|--------|
| Supabase | ✅ Connected |
| Stripe | ✅ Connected |
| OpenAI | ✅ Connected |
| Brevo (email) | ✅ Connected |
| Google Maps | ✅ Connected |
| Azure ID verify | ✅ Connected |
| Web platform | ✅ Active |
| Android / iOS | 🔒 Closed (`*-CLOSED` folders) |

---

## Feature matrix

| Feature | Works? | Notes |
|---------|--------|-------|
| **Homepage** | ✅ Yes | Platform banner, auth, navigation |
| **Listings (browse)** | ✅ Yes | Supabase data, map (Leaflet/OSM) |
| **Listings (post)** | ⚠️ Partial | Needs Supabase storage + RLS configured |
| **Listings (search/filter)** | ✅ Yes | Client + API search |
| **Favorites** | ✅ Yes | Backend API + Supabase |
| **Listing details** | ✅ Yes | CSS path fixed |
| **AI negotiator / chat** | ✅ Yes | OpenAI + **Groq fallback** added |
| **User-to-user chat** | ⚠️ Partial | Supabase realtime; auth must match session |
| **Login / register** | ✅ Yes | Use `login.html` (signup redirects there) |
| **Google / Apple OAuth** | ⚠️ Partial | Needs OAuth keys + redirect URLs in Google Console |
| **Email verification** | ✅ Yes | Brevo — key must stay valid on Railway |
| **Password reset** | ✅ Yes | Brevo + Turnstile optional |
| **RoomPal (roommate)** | ⚠️ Partial | UI works; **you must run SQL** for tables |
| **Student housing** | ⚠️ Partial | UI + calculator; housing data is simulated |
| **Maps / location** | ✅ Yes | Leaflet + OpenStreetMap (free); Google optional |
| **Mortgage tools** | ❌ No web page | Nav → coming soon; Android-only code exists |
| **Sublease** | ❌ No UI | Backend API exists; no frontend page yet |
| **Payments (Stripe)** | ⚠️ Partial | Page exists; test mode keys; legacy charge API |
| **Pricing / free trial** | ⚠️ Static | Marketing pages; not full subscription flow |
| **Legal center** | ⚠️ Partial | Static content; lease AI not wired to UI |
| **Profile + ID verify** | ⚠️ Partial | Needs Azure keys for document/face verify |
| **Notifications** | ⚠️ Partial | In-app via Supabase; push needs VAPID setup |
| **3D house models** | ✅ Yes | Static assets served |
| **Mobile apps** | 🔒 Closed | Use website on phone browser |

---

## Fixes applied in this pass (code)

1. **Groq free AI fallback** — `backend/ai-providers.js`; set `GROQ_API_KEY` on Railway (free at [console.groq.com](https://console.groq.com))
2. **13 pages** — fixed broken CSS path `/frontend/modules/...` → `/modules/css/main.css`
3. **signup.html** — redirects to `login.html` (real Supabase + Brevo flow)
4. **Dead `/sublease` links** — point to `coming-soon.html` on key pages
5. **AI service status** — `/api/service-status` reports `openai`, `groq`, `aiProviders`

---

## YOUR action list (manual — only you can do these)

### 🔴 Critical (do first)

| # | Task | Where | Why |
|---|------|-------|-----|
| 1 | **Confirm Railway deploys from `main`** | Railway → Settings → Source | Ensures latest code deploys |
| 2 | **Set `GROQ_API_KEY`** (free) | Railway Variables | Free AI backup if OpenAI rate-limits; get key at [console.groq.com](https://console.groq.com) |
| 3 | **Set `SUPABASE_SERVICE_ROLE_KEY`** | Railway Variables | Storage uploads, admin ops, geocode batch writes |
| 4 | **Set strong `ADMIN_KEY`** | Railway Variables | Protects admin routes in production |
| 5 | **Run storage SQL** | Supabase SQL Editor | Run `database/sql/setup-supabase-storage.sql` if photo uploads fail |
| 6 | **Run RoomPal SQL** | Supabase SQL Editor | Run `frontend/database/roommate_profiles_schema_v2.sql` for RoomPal tables |

### 🟡 Important (this week)

| # | Task | Where | Why |
|---|------|-------|-----|
| 7 | **Verify Brevo sender** | [Brevo dashboard](https://app.brevo.com) | Sender `humblewoslayer@gmail.com` must stay verified |
| 8 | **Restrict Google Maps key** | Google Cloud Console | HTTP referrer: `https://www.roomfinderai.com/*` |
| 9 | **Google OAuth redirect URIs** | Google Cloud Console | Add `https://www.roomfinderai.com/api/auth/google/callback` |
| 10 | **Stripe live vs test** | Stripe dashboard + Railway | Switch to live keys when ready to charge real users |
| 11 | **Run listings coordinates migration** | Supabase | `database/migrations/add_listings_coordinates.sql` if map pins missing |
| 12 | **Review Supabase RLS** | Supabase → Authentication → Policies | Listings insert/update must allow authenticated users |

### 🟢 Features to build or finish (your product work)

| # | Feature | Effort | What to do |
|---|---------|--------|------------|
| 13 | **Sublease UI** | Medium | Create `frontend/sublease.html` wired to `/api/sublease/*` OR remove feature from roadmap |
| 14 | **Mortgage calculator (web)** | Medium | Port from `RoomFinderAndroid-CLOSED` or embed calculator on new page |
| 15 | **Student housing real data** | Large | Replace mock data with API or Supabase `student_listings` table |
| 16 | **Legal page + AI lease review** | Small | Wire `legal.html` to `POST /api/negotiate/lease-review` |
| 17 | **Unified auth** | Medium | One session source: Supabase Auth everywhere (not mixed `localStorage`) |
| 18 | **Push notifications** | Medium | Generate VAPID keys, set on Railway, test `sw.js` |
| 19 | **RentCast market data** | Small | Set `RENTCAST_KEY` on Railway (optional; has fallback endpoint) |
| 20 | **iOS / Android reopen** | Large | When ready: rename `*-CLOSED` folders, update `platform-status.js`, store listings |

### 🔵 Free services you can use

| Service | Use for | Sign up | Env var |
|---------|---------|---------|---------|
| **Groq** | AI chat / negotiator (free tier) | [console.groq.com](https://console.groq.com) | `GROQ_API_KEY` |
| **Supabase** | DB, auth, storage, realtime | [supabase.com](https://supabase.com) | `SUPABASE_*` |
| **OpenStreetMap / Nominatim** | Maps & geocoding (no key) | Built-in | — |
| **Leaflet** | Map display | CDN | — |
| **Brevo** | Email (free tier limited) | [brevo.com](https://www.brevo.com) | `BREVO_API_KEY` |
| **Railway** | Hosting | [railway.app](https://railway.app) | — |
| **Stripe** | Payments (test free) | [stripe.com](https://stripe.com) | `STRIPE_*` |
| **Cloudflare Turnstile** | CAPTCHA (free) | [dash.cloudflare.com](https://dash.cloudflare.com) | `TURNSTILE_SITE_KEY` |

**Not integrated (would need dev work):** Voyage AI (embeddings), Hugging Face Inference, Ollama (self-hosted). Groq is the easiest free LLM drop-in and is now wired.

### AI provider env vars

```bash
# Prefer Groq only (free):
AI_PROVIDER=groq
GROQ_API_KEY=gsk_...
GROQ_MODEL=llama-3.1-8b-instant

# Or auto (Groq first if both set, then OpenAI fallback):
AI_PROVIDER=auto
GROQ_API_KEY=gsk_...
OPENAI_API_KEY=sk-...
```

---

## Quick verification checklist

After setting Railway variables, redeploy and run:

```bash
curl https://www.roomfinderai.com/health
curl https://www.roomfinderai.com/api/service-status
curl https://www.roomfinderai.com/api/listings | head -c 200
```

Manual browser tests:

- [ ] Homepage loads, one platform banner
- [ ] Listings page — cards + map
- [ ] Login → register → email code (check inbox)
- [ ] AI negotiator — login required, send a message
- [ ] RoomPal — page loads (matching needs SQL tables)
- [ ] Favorites — save/remove a listing
- [ ] Profile — loads when logged in

---

## Related docs

- [`DOCUMENTATION.md`](../DOCUMENTATION.md) — full project reference
- [`docs/PLATFORM_STATUS.md`](PLATFORM_STATUS.md) — mobile closed notice
- [`.env.example`](../.env.example) — all environment variables

---

**Summary:** Web platform is live and most core features work. Your highest-impact tasks are Railway env vars (Groq, service role, admin key), Supabase SQL migrations (storage + RoomPal), and OAuth/Google key restrictions. Product gaps: sublease UI, mortgage web page, student housing real data, auth unification.
