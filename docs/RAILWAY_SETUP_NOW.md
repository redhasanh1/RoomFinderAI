# Railway Setup — Do This Now (5 minutes)

You have Railway access. Follow these steps exactly.

## Step 1 — Branch

Railway → your service → **Settings** → **Source**  
Set branch to **`main`** → Save

## Step 2 — Variables (fastest method)

1. Railway → **Variables** tab  
2. Click **RAW Editor** (or "Bulk edit")  
3. Open the file **`.env`** in your project root (gitignored — only on your laptop)  
4. Copy **entire contents** → paste into Railway RAW editor  
5. **Save**

> `.env` includes `NODE_ENV=production`, all your keys, and generated `ADMIN_KEY` / `JWT_SECRET` / `SESSION_SECRET`.

## Step 3 — Deploy

1. **Deployments** tab  
2. Click **Deploy** / **Redeploy**  
3. Wait until status = **Success** (1–3 min)

## Step 4 — Verify

In terminal from project folder:

```bash
bash scripts/production-smoke-test.sh
```

All checks should pass. Or manually:

- https://www.roomfinderai.com/health → `"environment":"production"`
- https://www.roomfinderai.com/sublease.html → loads (not 404)
- https://www.roomfinderai.com/debug-test → 404

## Optional — Groq (free AI backup)

1. https://console.groq.com → API Keys  
2. Add to Railway: `GROQ_API_KEY=gsk_...`  
3. Redeploy again

OpenAI already works without Groq.

## Security note

If keys were shared in chat, rotate them in each dashboard after launch.
