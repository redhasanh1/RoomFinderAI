# RoomFinderAI — Project Completion Checklist

**Goal:** Web platform fully live at [roomfinderai.com](https://www.roomfinderai.com) with real data, AI, auth, listings, sublease, and RoomPal.

**Branch:** `main` · **Deploy:** Railway · **Database:** Supabase

Use this as your master list. Check items off in order.

---

## Phase 1 — Code & Git

| Status | Task | Where | Notes |
|--------|------|-------|-------|
| ☐ | Latest code on `main` | GitHub | Repo pushed and up to date |
| ☐ | Commit hook enabled (optional) | Local terminal | `git config core.hooksPath scripts/git-hooks` |
| ☐ | No secrets in repo | `.env` gitignored | Keys only in Railway + Supabase dashboards |

---

## Phase 2 — Supabase (database & storage)

Run each file in **Supabase → SQL Editor** as **one full query**.

| Status | Task | File |
|--------|------|------|
| ☐ | Storage buckets + policies | `database/sql/setup-supabase-storage.sql` |
| ☐ | RoomPal tables | `database/migrations/roommate_profiles_schema_v2.sql` |
| ☐ | Sublease tables | `database/migrations/simple_sublease_schema.sql` |

**If storage SQL fails** with `participant1_id` error → you ran an old copy. Use latest `setup-supabase-storage.sql` from `main`, or run `database/sql/setup-supabase-storage-buckets-only.sql` first, then the full file.

**Verify in Supabase Dashboard:**

| Status | Check |
|--------|-------|
| ☐ | Storage → buckets exist: `profile-images`, `listing-media`, `chat-attachments`, `verification-docs` |
| ☐ | Table Editor → `sublease_requests` exists |
| ☐ | Table Editor → `roommate_profiles` exists (or related RoomPal tables) |
| ☐ | Auth → email provider enabled |
| ☐ | Project URL + anon key + service role key copied for Railway |

**Optional Supabase (improves features, not required for first launch):**

| Status | Task | File |
|--------|------|------|
| ☐ | Listing map coordinates | `database/migrations/add_listings_coordinates.sql` |
| ☐ | Fix listings RLS for email auth | `database/migrations/fix_listings_rls_for_email_auth.sql` |
| ☐ | Disputes in database (UI currently uses localStorage) | `database/migrations/create_disputes_schema.sql` |

---

## Phase 3 — Railway (deploy to production)

Give this section to whoever has Railway access. Full detail: [`docs/RAILWAY_ONLY.md`](RAILWAY_ONLY.md).

### 3a — Project setup

| Status | Task | Where |
|--------|------|-------|
| ☐ | Railway project linked to GitHub repo `RoomFinderAI` | Railway → Settings → Source |
| ☐ | Deploy branch = **`main`** | Railway → Settings → Source |
| ☐ | Start command = `node backend/server.js` | Uses `railway.json` |
| ☐ | Health check path = `/health` | Railway → Settings → Deploy |
| ☐ | Custom domain `roomfinderai.com` attached | Railway → Settings → Domains |

### 3b — Required environment variables

Set in **Railway → Variables**. Never commit these to git.

| Status | Variable | Value |
|--------|----------|-------|
| ☐ | `NODE_ENV` | `production` |
| ☐ | `ENABLE_DEMO_MODE` | `false` |
| ☐ | `SUPABASE_URL` | Supabase → Settings → API |
| ☐ | `SUPABASE_ANON_KEY` | Supabase → Settings → API |
| ☐ | `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Settings → API (secret) |
| ☐ | `GROQ_API_KEY` | [console.groq.com](https://console.groq.com) (free) |
| ☐ | `ADMIN_KEY` | Generate: `openssl rand -base64 32` |
| ☐ | `ENABLE_ANONYMOUS_BROWSING` | `true` |

### 3c — Recommended environment variables

| Status | Variable | Purpose |
|--------|----------|---------|
| ☐ | `AI_PROVIDER` | `auto` |
| ☐ | `OPENAI_API_KEY` | AI fallback if Groq fails |
| ☐ | `BREVO_API_KEY` | Signup / verification emails |
| ☐ | `GOOGLE_API_KEY` | Maps on listings |
| ☐ | `STRIPE_SECRET_KEY` | Payments (test keys OK for launch) |
| ☐ | `STRIPE_PUBLISHABLE_KEY` | Payments (test keys OK for launch) |
| ☐ | `JWT_SECRET` | `openssl rand -base64 32` |
| ☐ | `SESSION_SECRET` | `openssl rand -base64 32` |

Full list template: `.env.example`

### 3d — Deploy

| Status | Task |
|--------|------|
| ☐ | Save all variables |
| ☐ | Click **Deploy** / **Redeploy** |
| ☐ | Build succeeds (no errors in Railway logs) |
| ☐ | Health check passes on `/health` |

---

## Phase 4 — Post-deploy verification

### 4a — API checks (terminal)

```bash
curl https://www.roomfinderai.com/health
curl https://www.roomfinderai.com/api/service-status
```

| Status | Expected result |
|--------|-----------------|
| ☐ | `/health` → `status: "running"` (not degraded) |
| ☐ | `/health` → `mode.environment: "production"` |
| ☐ | `/health` → `mode.demo: false` |
| ☐ | `/health` → `services.supabase: true` |
| ☐ | `/api/service-status` → `features.aiProviders` includes `groq` |

### 4b — Browser smoke test

| Status | Page / action | URL |
|--------|---------------|-----|
| ☐ | Homepage loads, nav works | `/` |
| ☐ | Platform status banner visible | `/platform-status.html` |
| ☐ | Browse listings + map | `/listings.html` |
| ☐ | Listing detail page | Click any listing |
| ☐ | **Post listing with photo** | Confirms `listing-media` bucket |
| ☐ | Login / register | `/login.html` |
| ☐ | Profile + my listings | `/profile.html` |
| ☐ | Favorites | `/favorites.html` |
| ☐ | AI negotiator sends message | `/ai-negotiator.html` |
| ☐ | Legal → generate document | `/legal.html` |
| ☐ | Legal → lease review | `/legal.html` |
| ☐ | Student housing | `/student-housing.html` |
| ☐ | Sublease → post request | `/sublease.html` |
| ☐ | RoomPal → profile | `/roommate-matching.html` |
| ☐ | File dispute → My Disputes | `/file-dispute.html` → `/my-disputes.html` |
| ☐ | Contact form on homepage | `/#contact` |
| ☐ | Pricing page | `/pricing.html` |
| ☐ | Support page | `/support.html` |

---

## Phase 5 — Third-party dashboards (launch quality)

Not blocking deploy, but do within the first week.

| Status | Task | Where | Why |
|--------|------|-------|-----|
| ☐ | Verify Brevo sender domain | Brevo dashboard | Emails don't go to spam |
| ☐ | Google Maps API referrer | Google Cloud Console | `https://www.roomfinderai.com/*` |
| ☐ | Google OAuth redirect URI | Google Cloud Console | `https://www.roomfinderai.com/api/auth/google/callback` |
| ☐ | Stripe webhook URL (if using payments) | Stripe dashboard | Point to Railway domain |
| ☐ | Stripe test → live keys | Stripe + Railway | When ready for real charges |

---

## Phase 6 — Project complete ✅

When **all** of these are true, the web project is **complete**:

| Criteria | Done? |
|----------|-------|
| `main` deployed on Railway | ☐ |
| Production env vars set (`NODE_ENV=production`, `ENABLE_DEMO_MODE=false`) | ☐ |
| Supabase SQL run (storage + RoomPal + sublease) | ☐ |
| `/health` and `/api/service-status` pass | ☐ |
| Core browser smoke test passes (listings, auth, AI, sublease, disputes) | ☐ |
| Listing photo upload works | ☐ |

---

## Troubleshooting quick reference

| Symptom | Fix |
|---------|-----|
| Upload fails on listings | Re-run `setup-supabase-storage.sql` — need `listing-media` bucket |
| AI returns errors | Set `GROQ_API_KEY` or `OPENAI_API_KEY` on Railway, redeploy |
| Health shows `development` | Set `NODE_ENV=production`, redeploy |
| Health `degraded` / supabase false | Check `SUPABASE_URL` + keys on Railway |
| Sublease / RoomPal empty | Run migration SQL in Supabase |
| 404 on new pages | Redeploy latest `main` from GitHub |
| Email verification broken | Fix `BREVO_API_KEY` + sender in Brevo |
| Maps blank | Set `GOOGLE_API_KEY` + referrer restriction |

---

## Not in scope (future work)

These are **not** required to mark the web project complete:

- Android / iOS apps (`*-CLOSED` folders)
- Mortgage calculator web page
- Disputes stored in Supabase (currently localStorage + email)
- Push notifications (VAPID)
- Stripe live mode / real billing

---

## Related docs

| Document | Purpose |
|----------|---------|
| [`DOCUMENTATION.md`](../DOCUMENTATION.md) | Full technical reference |
| [`RAILWAY_ONLY.md`](RAILWAY_ONLY.md) | Railway-only quick guide |
| [`FEATURE_STATUS_AND_TODO.md`](FEATURE_STATUS_AND_TODO.md) | Feature matrix |
| [`.env.example`](../.env.example) | All environment variables |
