# Live Integrations Audit — Deployment, Supabase & Third Parties

**Last probed:** July 1, 2026 · **Production:** https://www.roomfinderai.com  
**GitHub `main`:** ahead of live Railway deploy (redeploy required)

This document covers **everything outside local code** — Railway, Supabase dashboard, and third-party accounts.

---

## Executive summary

| Layer | Status | Blocker |
|-------|--------|---------|
| **GitHub code** | 🟢 Ready | None |
| **Railway deploy** | 🔴 Stale | Branch/redeploy + `NODE_ENV=production` |
| **Supabase SQL** | 🟢 Done (you) | Verify buckets in dashboard |
| **Google Maps/OAuth** | 🟡 Configured (you) | New OAuth keys on Railway tomorrow |
| **Brevo** | 🟢 API works live | Sender verified |
| **Stripe** | 🟡 Test mode live | Live keys later |
| **Cloudflare Turnstile** | 🟡 Pending access | Domain whitelist |
| **Groq AI** | 🔴 Not on Railway | Set `GROQ_API_KEY` + redeploy |

**One sentence:** Code and Supabase are ready; **production is still running an old Railway build** — redeploy `main` tomorrow to go green.

---

## 1. Railway (live deploy)

### Probed live (July 1, 2026)

| Check | Expected | **Live now** | After redeploy |
|-------|----------|--------------|----------------|
| `/health` → `environment` | `production` | 🔴 `development` | Set `NODE_ENV=production` |
| `/health` → `demo` | `false` | 🟢 `false` | OK |
| `/sublease.html` | 200 | 🔴 **404** | 200 |
| `/file-dispute.html` | 200 | 🔴 **404** | 200 |
| `/debug-test` | 404 (prod) | 🔴 **200** (exposed) | 404 |
| `/api/brevo-status` | 404 (prod) | 🔴 **200** (exposed) | 404 |
| `/api/service-status` → `ai` | object with providers | 🔴 missing | present |
| Uptime | fresh after deploy | ~76 min (old build) | reset |

### Railway checklist (you / friend)

| # | Task | Where |
|---|------|-------|
| 1 | Source branch = **`main`** | Railway → Settings → Source |
| 2 | `NODE_ENV=production` | Railway → Variables |
| 3 | `ENABLE_DEMO_MODE=false` | Railway → Variables |
| 4 | `GROQ_API_KEY` | [console.groq.com](https://console.groq.com) |
| 5 | `SUPABASE_SERVICE_ROLE_KEY` | Supabase → API |
| 6 | `ADMIN_KEY` | `openssl rand -base64 32` |
| 7 | `GOOGLE_OAUTH_CLIENT_ID` + `SECRET` | Your new Google OAuth client |
| 8 | **Redeploy** | Deployments → Deploy |
| 9 | Run smoke test | `bash scripts/production-smoke-test.sh` |

Guide: [`RAILWAY_SWITCH_TO_MAIN.md`](RAILWAY_SWITCH_TO_MAIN.md)

### Config files (repo — OK)

| File | Purpose |
|------|---------|
| `railway.json` | Build + `node backend/server.js` + `/health` |
| `nixpacks.toml` | `NODE_ENV=production` at build time |
| `.railwayignore` | Excludes mobile apps, tests, archive |

> **Note:** `nixpacks.toml` sets `NODE_ENV=production` at **build** only. You still need `NODE_ENV=production` in **Railway Variables** at **runtime**.

---

## 2. Supabase

### SQL you ran (confirm in dashboard)

| File | Verify in dashboard |
|------|---------------------|
| `database/sql/setup-supabase-storage.sql` | Storage → `listing-media`, `profile-images`, `chat-attachments`, `verification-docs` |
| `database/migrations/roommate_profiles_schema_v2.sql` | Table Editor → `roommate_profiles` |
| `database/migrations/simple_sublease_schema.sql` | Table Editor → `sublease_requests`, `sublease_matches` |

### Auth URL configuration (you did)

| Setting | Value |
|---------|-------|
| Site URL | `https://www.roomfinderai.com` |
| Redirect URLs | `https://www.roomfinderai.com/**`, `http://localhost:3000/**` |

### Railway variables (Supabase)

| Variable | Required | Purpose |
|----------|----------|---------|
| `SUPABASE_URL` | ✅ | DB + auth |
| `SUPABASE_ANON_KEY` | ✅ | Client auth |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ | Storage admin, user admin ops |

**Live:** `/health` shows `supabase: true` — connection works.

### Optional Supabase (not blocking launch)

| Migration | When |
|-----------|------|
| `add_listings_coordinates.sql` | If map pins missing |
| `fix_listings_rls_for_email_auth.sql` | If listing insert fails |
| `create_disputes_schema.sql` | When moving disputes off localStorage |

---

## 3. Third-party services matrix

### Brevo (email)

| Item | Status |
|------|--------|
| API on production | 🟢 `brevo: true` in `/health` |
| Sender | `humblewoslayer@gmail.com` (verified) |
| Railway var | `BREVO_API_KEY` (xkeysib-...) |
| Optional env | `BREVO_SENDER_EMAIL`, `CONTACT_EMAIL` |
| Custom domain | Optional later (`noreply@roomfinderai.com`) |

**Test:** Register account → confirmation email arrives.

---

### Google Cloud

| Item | Status |
|------|--------|
| Maps API key | 🟢 On production via `/api/config` |
| Referrer restriction | 🟡 You set **Websites** — confirm saved |
| OAuth client | 🟡 You created — add ID/secret to Railway |
| Consent screen | Test users or Publish app |
| Billing | Required for Maps (free tier) |

**Railway vars:** `GOOGLE_API_KEY`, `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`

**Test:** Listings map loads; Login → Continue with Google.

---

### Groq (AI — recommended)

| Item | Status |
|------|--------|
| Code support | 🟢 `callAI` + `AI_PROVIDER=auto` |
| Railway `GROQ_API_KEY` | 🔴 **Likely missing** — not in `/api/config` (correct) |
| Live AI | Uses OpenAI today (`openai: true` in health) |

**Action:** Get free key at [console.groq.com](https://console.groq.com) → Railway → redeploy.

**Test:** AI negotiator + Legal center send a message.

---

### OpenAI (AI fallback)

| Item | Status |
|------|--------|
| Live | 🟢 `openai: true` |
| Railway | `OPENAI_API_KEY` (optional if Groq set) |

---

### Stripe (payments)

| Item | Status |
|------|--------|
| Live mode | 🟡 **Test keys** (`pk_test_...` in `/api/config`) |
| Webhooks | ❌ Not implemented in backend — skip for launch |
| Currency | USD in code (Canadian product — post-launch) |

**Test:** `/payment.html` with card `4242 4242 4242 4242`.

---

### Cloudflare Turnstile

| Item | Status |
|------|--------|
| Site key on production | 🟢 `0x4AAAAAABjjAXWppygcnbuz` |
| Domain whitelist | 🔴 Needs Cloudflare access |
| Server verify | 🔴 `TURNSTILE_SECRET_KEY` not in code yet |

**Test:** `/forgot-password.html` — captcha appears.

---

### Azure (ID verification)

| Item | Status |
|------|--------|
| Live health | 🟢 Both services report true |
| Actual flow | Manual review path in app (not full Azure auto-verify) |

**Railway vars:** `AZURE_DOCUMENT_INTELLIGENCE_KEY/ENDPOINT`, `AZURE_FACE_KEY/ENDPOINT`

---

### RentCast (optional market data)

| Item | Status |
|------|--------|
| Railway | `RENTCAST_KEY` optional |
| Rate limit | 40 calls/month per user in code |

---

### Apple Sign-In

| Item | Status |
|------|--------|
| Client ID in config | May be empty |
| Priority | Low — Google auth primary |

---

## 4. DNS & domain

| Item | Status |
|------|--------|
| `roomfinderai.com` | 🟢 Points to Railway |
| `www.roomfinderai.com` | 🟢 Works |
| Old `roompal.space` in sitemap | 🟢 Fixed in code (redeploy to serve new `sitemap.xml`) |

---

## 5. Security — live vs code

| Issue | Live today | After redeploy `main` |
|-------|------------|----------------------|
| `/debug-test` public | 🔴 Exposed | 🟢 404 in production |
| `/api/brevo-status` public | 🔴 Account info leak | 🟢 404 in production |
| `NODE_ENV=development` | 🔴 Wrong | 🟢 `production` |
| Google Maps key in `/api/config` | 🟡 Expected — use referrer lock | Same |
| Auth IDOR on some routes | 🟡 Code backlog | Post-launch hardening |

---

## 6. Post-deploy verification

Run after Railway redeploy:

```bash
bash scripts/production-smoke-test.sh
```

Or manually:

```bash
curl -s https://www.roomfinderai.com/health | python3 -m json.tool
curl -s https://www.roomfinderai.com/api/service-status | python3 -m json.tool
```

**All green when:**
- `environment: "production"`
- `/sublease.html` → 200
- `/debug-test` → 404
- `service-status.features.aiProviders` includes `groq` (if key set)

---

## 7. Who fixes what

| You (no Railway) | Friend / Railway access |
|------------------|-------------------------|
| Groq API key | Paste into Railway |
| Google OAuth secrets | Paste into Railway |
| Supabase dashboard checks | `SUPABASE_SERVICE_ROLE_KEY` on Railway |
| Cloudflare Turnstile domains | Redeploy from `main` |
| | `NODE_ENV=production` |
| | Switch branch to `main` |

---

## Related docs

| Doc | Purpose |
|-----|---------|
| [`PROJECT_COMPLETION_CHECKLIST.md`](PROJECT_COMPLETION_CHECKLIST.md) | Master launch checklist |
| [`PHASE_5_SETUP_GUIDE.md`](PHASE_5_SETUP_GUIDE.md) | Third-party dashboard steps |
| [`QA_AUDIT_JULY_2026.md`](QA_AUDIT_JULY_2026.md) | Code-level fixes |
| [`RAILWAY_SWITCH_TO_MAIN.md`](RAILWAY_SWITCH_TO_MAIN.md) | Branch + redeploy |
