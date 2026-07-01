# RoomFinderAI — Feature Status & Your Action List

**Last updated:** July 1, 2026  
**Production:** [roomfinderai.com](https://www.roomfinderai.com) · Branch: **`main`**

This document lists every major feature, what works in code today, and **what only you can do** (Railway keys, Supabase SQL, third-party accounts).

---

## Production status right now

| Service | Status |
|---------|--------|
| Supabase | ✅ Connected (when env vars set) |
| Stripe | ✅ Connected (test keys by default) |
| OpenAI / Groq | ✅ Code supports both (`AI_PROVIDER=auto`) |
| Brevo (email) | ✅ Connected (when key valid) |
| Google Maps | ✅ Connected |
| Azure ID verify | ✅ Connected (when keys set) |
| Web platform | ✅ Active |
| Android / iOS | 🔒 Closed (`*-CLOSED` folders) |

---

## Feature matrix (after July 2026 code pass)

| Feature | Works? | Notes |
|---------|--------|-------|
| **Homepage** | ✅ Yes | Nav includes student housing + sublease |
| **Listings (browse)** | ✅ Yes | Supabase data, map |
| **Listings (post)** | ⚠️ Partial | Needs storage SQL + RLS |
| **Favorites** | ✅ Yes | Backend API + Supabase |
| **Listing details** | ✅ Yes | Fixed Supabase bootstrap order |
| **AI negotiator / chat** | ✅ Yes | Groq + OpenAI via `callAI` |
| **Legal center** | ✅ Yes | AI document gen + lease review wired |
| **Disputes** | ✅ Yes | `file-dispute.html`, `my-disputes.html` + email notify |
| **Sublease** | ⚠️ Partial | UI live — **you must run sublease SQL** |
| **RoomPal** | ⚠️ Partial | UI works — **you must run RoomPal SQL** |
| **Student housing** | ✅ Yes | Real `/api/listings` + offline university search |
| **Login / register** | ✅ Yes | Supabase + Brevo |
| **Google OAuth** | ⚠️ Partial | Needs redirect URIs in Google Console |
| **Payments (Stripe)** | ⚠️ Partial | Test mode until you switch keys |
| **Mortgage tools** | ❌ Not available | Removed from navigation (no web page) |
| **Mobile apps** | 🔒 Closed | Use website on phone |

---

## YOUR action list (manual — only you can do these)

### 🔴 Critical — Supabase (tonight, no Railway needed)

| # | Task | Where | Why |
|---|------|-------|-----|
| 1 | **Run storage SQL** | Supabase SQL Editor | `database/sql/setup-supabase-storage.sql` (`listing-media` bucket) |
| 2 | **Run RoomPal SQL** | Supabase SQL Editor | `database/migrations/roommate_profiles_schema_v2.sql` |
| 3 | **Run sublease SQL** | Supabase SQL Editor | `database/migrations/simple_sublease_schema.sql` |
| 4 | **Force-push git history** (if not done) | Terminal | `git push --force origin main` |
| 5 | **Enable commit hook** | Local | `git config core.hooksPath scripts/git-hooks` |

### 🔴 Critical — Railway only (when you have access)

See **[`docs/RAILWAY_ONLY.md`](RAILWAY_ONLY.md)** for the full list. Summary:

| # | Task | Where |
|---|------|-------|
| 6 | Deploy from **`main`** | Railway → Source |
| 7 | **`NODE_ENV=production`**, **`ENABLE_DEMO_MODE=false`** | Railway Variables |
| 8 | **`GROQ_API_KEY`**, **`SUPABASE_SERVICE_ROLE_KEY`**, **`ADMIN_KEY`** | Railway Variables |
| 9 | **Redeploy** + smoke test | `/health`, `/api/service-status` |

### 🟡 Important (this week)

| # | Task | Where | Why |
|---|------|-------|-----|
| 11 | **Verify Brevo sender** | Brevo dashboard | Email verification works |
| 12 | **Google Maps referrer** | Google Cloud | `https://www.roomfinderai.com/*` |
| 13 | **Google OAuth redirects** | Google Cloud | `/api/auth/google/callback` |
| 14 | **Stripe live keys** | Stripe + Railway | When ready for real charges |
| 15 | **Listings coordinates SQL** | Supabase | `database/migrations/add_listings_coordinates.sql` |
| 16 | **Review Supabase RLS** | Supabase Policies | Listings insert for auth users |

### 🟢 Optional product work (later)

| # | Feature | Notes |
|---|---------|-------|
| 17 | Mortgage calculator web page | Port from Android or new page |
| 18 | Student housing real data | Supabase table or external API |
| 19 | Dispute backend in Supabase | Currently localStorage + email to support |
| 20 | Push notifications | VAPID keys + `sw.js` |
| 21 | Mobile app reopen | Rename `*-CLOSED` folders when ready |

---

## Quick verification checklist

After Railway variables + SQL:

```bash
curl https://www.roomfinderai.com/health
curl https://www.roomfinderai.com/api/service-status
```

Browser:

- [ ] Homepage → student housing + sublease links work
- [ ] Listings load with map
- [ ] AI negotiator sends a message
- [ ] Legal → generate document + lease review
- [ ] File dispute → appears in My Disputes
- [ ] Sublease → post request (after SQL)
- [ ] RoomPal → profiles load (after SQL)

---

## AI provider env vars

```bash
AI_PROVIDER=auto
GROQ_API_KEY=gsk_...
OPENAI_API_KEY=sk-...
```

At least one of Groq or OpenAI is required for AI features.
