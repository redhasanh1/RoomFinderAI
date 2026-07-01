# Railway — Last Step to Go Live

Everything else (code, Supabase SQL, docs) is ready. **Only Railway deployment** needs dashboard access.

> **Branch must be `main`:** If Railway still deploys `hasan`, follow **[`RAILWAY_SWITCH_TO_MAIN.md`](RAILWAY_SWITCH_TO_MAIN.md)** first.

---

## Before Railway (you can do tonight)

1. **Supabase SQL Editor** — run each file as **one query**:
   - `database/sql/setup-supabase-storage.sql` (creates `listing-media` bucket — matches upload code)
   - `database/migrations/roommate_profiles_schema_v2.sql`
   - `database/migrations/simple_sublease_schema.sql`

2. **Git** (if history was rewritten):
   ```bash
   git config core.hooksPath scripts/git-hooks
   git push --force origin main
   ```

---

## Railway checklist (friend / tomorrow)

### Source
- Project linked to **RoomFinderAI** GitHub repo
- Branch: **`main`** ← **change in Railway → Settings → Source if not already `main`**
- See **[`RAILWAY_SWITCH_TO_MAIN.md`](RAILWAY_SWITCH_TO_MAIN.md)** for step-by-step
- Root directory: repo root (default)
- Build/start: uses `railway.json` → `node backend/server.js`
- Health check path: `/health`

### Required variables

| Variable | Value | Notes |
|----------|-------|--------|
| `NODE_ENV` | `production` | Fixes health `environment` field |
| `SUPABASE_URL` | From Supabase → Settings → API | |
| `SUPABASE_ANON_KEY` | From Supabase | |
| `SUPABASE_SERVICE_ROLE_KEY` | From Supabase (secret) | Storage + admin |
| `GROQ_API_KEY` | From [console.groq.com](https://console.groq.com) | Free AI tier |
| `ADMIN_KEY` | Random strong string | `openssl rand -base64 32` |
| `ENABLE_DEMO_MODE` | `false` | Real data only in prod |
| `ENABLE_ANONYMOUS_BROWSING` | `true` | Optional |

### Recommended (if already configured)

| Variable | Purpose |
|----------|---------|
| `OPENAI_API_KEY` | AI fallback |
| `AI_PROVIDER` | `auto` |
| `STRIPE_SECRET_KEY` / `STRIPE_PUBLISHABLE_KEY` | Payments |
| `BREVO_API_KEY` | Email verification |
| `GOOGLE_API_KEY` | Maps |
| `JWT_SECRET` / `SESSION_SECRET` | Auth sessions |

Copy full list from `.env.example` — never commit real values to git.

### Deploy
1. Trigger **Redeploy** after env vars are saved
2. Wait for health check green on `/health`

---

## Smoke test (after deploy)

```bash
curl https://www.roomfinderai.com/health
curl https://www.roomfinderai.com/api/service-status
```

Expected:
- `health.mode.environment` → `"production"`
- `health.mode.demo` → `false`
- `service-status.features.aiProviders` includes `groq` (if key set)

Browser:
- Homepage, listings, AI negotiator, legal, sublease, disputes
- Post a listing with photo (needs `listing-media` bucket from SQL)

---

## Custom domain

If `roomfinderai.com` is already pointed at Railway, no DNS change needed — just redeploy `main`.

---

## If something fails

| Symptom | Fix |
|---------|-----|
| Upload fails on listings | Re-run `setup-supabase-storage.sql` (`listing-media` bucket) |
| AI returns errors | Set `GROQ_API_KEY` or `OPENAI_API_KEY` |
| Health shows `development` | Set `NODE_ENV=production` and redeploy |
| Sublease/RoomPal empty | Run the two migration SQL files in Supabase |
| 404 on new pages | Deploy latest `main` from GitHub |
