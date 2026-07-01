# Switch Railway Deploy Branch to `main`

**Do this in Railway dashboard** — the branch cannot be changed from `railway.json` in the repo.

---

## Steps (2 minutes)

1. Go to **[railway.app](https://railway.app)** and open the **RoomFinderAI** project
2. Click your **web service** (the one running `node backend/server.js`)
3. Open **Settings** tab
4. Scroll to **Source** (or **GitHub Repo**)
5. Find **Branch** — if it says `hasan` or anything other than `main`, change it to:
   ```
   main
   ```
6. Click **Save** / **Update**
7. Go to **Deployments** tab → click **Deploy** or **Redeploy** (latest commit)
8. Wait until status is **Success** and health check passes

---

## Verify it worked

### In Railway
- **Deployments** → latest deploy should show commit message like:
  - `Polish platform: fix storage buckets, new pages, cleanup dead code`
  - or newer commits on `main`

### In browser / terminal
```bash
curl https://www.roomfinderai.com/health
```

After redeploy you should see:
- `"environment": "production"` (also set `NODE_ENV=production` in Variables)
- New pages return **200**, not 404:
  - https://www.roomfinderai.com/sublease.html
  - https://www.roomfinderai.com/file-dispute.html

---

## If auto-deploy is off

Railway → Service → **Settings** → enable **Auto Deploy** (or **Deploy on push**) for `main`.

Then every `git push origin main` triggers a new deploy automatically.

---

## Required env vars (set before or right after redeploy)

| Variable | Value |
|----------|-------|
| `NODE_ENV` | `production` |
| `ENABLE_DEMO_MODE` | `false` |
| `SUPABASE_URL` | from Supabase |
| `SUPABASE_ANON_KEY` | from Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | from Supabase |
| `GROQ_API_KEY` | from console.groq.com |
| `ADMIN_KEY` | random strong string |

Full list: `.env.example` and `docs/RAILWAY_ONLY.md`

---

## Who can do this?

Only someone with **Railway project access** (project owner or invited member). GitHub push alone does not change Railway's branch — this dashboard step is required once.
