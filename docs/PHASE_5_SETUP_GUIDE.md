# Phase 5 — Third-Party Dashboard Setup (Step-by-Step)

**Production site:** https://www.roomfinderai.com  
**Do this tonight** — no Railway access required for dashboard config (testing needs Railway redeploy).

---

## Quick status (checked July 2026)

| Service | Already working? | Your action |
|---------|------------------|-------------|
| Brevo | ✅ API key valid, sender verified | Optional: add custom domain |
| Google Maps | ✅ Key on production | Lock down referrers |
| Google OAuth | ✅ Client ID on production | Add origins in Google Console |
| Stripe | ✅ Test keys on production | Skip webhooks (not implemented yet) |
| Supabase Auth URLs | ⚠️ Verify | Set Site URL + redirect URLs |

---

## Task 1 — Brevo (email)

**Dashboard:** https://app.brevo.com

### 1a. Confirm sender (required — likely done)

1. Go to **Transactional** → **Senders, Domains & dedicated IPs** → **Senders**
2. Confirm this sender is **Verified**:
   - Email: `humblewoslayer@gmail.com`
   - Name: `RoomFinderAI`

This matches `EMAIL_CONFIG.SENDER_EMAIL` in `backend/server.js`.

### 1b. Confirm API key on Railway (friend does tomorrow)

Railway variable: `BREVO_API_KEY`  
Format must start with: `xkeysib-`

**Test after Railway redeploy:**
```bash
curl https://www.roomfinderai.com/api/brevo-status
```
Should return `"configured": true`.

### 1c. Optional — custom domain (reduces spam)

1. Brevo → **Senders, Domains** → **Domains** → **Add a domain**
2. Enter: `roomfinderai.com`
3. Add the DNS records Brevo gives you (TXT, DKIM, etc.) at your domain registrar
4. Wait for verification (can take up to 48h)
5. Later: change sender to `noreply@roomfinderai.com` in code + Brevo

**Skip 1c for now** if you want to launch fast — Gmail sender already works.

---

## Task 2 — Google Maps API (referrer lockdown)

**Dashboard:** https://console.cloud.google.com

### 2a. Find your project & key

1. **APIs & Services** → **Credentials**
2. Open the API key used by RoomFinderAI (production key ends in `...wYYM` if unchanged)

### 2b. Restrict the key

1. Click the key → **Application restrictions** → **HTTP referrers (web sites)**
2. Add these referrers:

```
https://www.roomfinderai.com/*
https://roomfinderai.com/*
http://localhost:3000/*
http://127.0.0.1:3000/*
```

3. **API restrictions** → **Restrict key** → enable only:
   - **Maps JavaScript API**
   - **Geocoding API**
   - **Places API** (if used)

4. **Save**

### 2c. Enable billing (required for Maps)

1. **Billing** → link a billing account to the project
2. Google gives $200/month free Maps credit — normal traffic stays free

### 2d. Railway variable (friend sets tomorrow)

```
GOOGLE_API_KEY=<your restricted key>
```

**Test:** Open https://www.roomfinderai.com/listings.html — map should load after redeploy.

---

## Task 3 — Google OAuth (login with Google)

**Dashboard:** https://console.cloud.google.com → **APIs & Services** → **Credentials**

### 3a. Open OAuth 2.0 Client

Client ID on production (if unchanged):
```
476202400446-kkchao7sigg4csvm7j17bmt81gqnliqq.apps.googleusercontent.com
```

Click that **OAuth 2.0 Client ID** (type: Web application).

### 3b. Authorized JavaScript origins

Add all of these:

```
https://www.roomfinderai.com
https://roomfinderai.com
http://localhost:3000
```

### 3c. Authorized redirect URIs

Add:

```
https://www.roomfinderai.com/api/auth/google/callback
http://localhost:3000/api/auth/google/callback
```

> **Note:** The login page primarily uses Google's popup flow (`postmessage`). Origins in 3b are the critical part. Callback URI is for redirect flow fallback.

### 3d. OAuth consent screen

1. **APIs & Services** → **OAuth consent screen**
2. **User type:** External (or Internal if Workspace)
3. **App name:** RoomFinderAI
4. **User support email:** your email
5. **Authorized domains:** `roomfinderai.com`
6. **Scopes:** `email`, `profile`, `openid`
7. If in **Testing** mode: add test users OR **Publish app** for public login

### 3e. Railway variables (friend sets tomorrow)

```
GOOGLE_OAUTH_CLIENT_ID=476202400446-....apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=<from Google Console>
```

**Test:** https://www.roomfinderai.com/login.html → **Continue with Google**

---

## Task 4 — Supabase Auth URLs

**Dashboard:** https://supabase.com/dashboard → your project → **Authentication** → **URL Configuration**

### Set these values:

| Field | Value |
|-------|-------|
| **Site URL** | `https://www.roomfinderai.com` |
| **Redirect URLs** | Add each line below |

Redirect URLs to add:
```
https://www.roomfinderai.com/**
https://www.roomfinderai.com/login.html
https://www.roomfinderai.com/verification-modal.html
http://localhost:3000/**
```

**Why:** Email confirmation and password reset links must redirect back to your live site.

**Test:** Register a new account → check email → click confirm link.

---

## Task 5 — Stripe (test mode — skip webhooks for now)

**Dashboard:** https://dashboard.stripe.com

### 5a. Current state

- Production already uses **test** publishable key (`pk_test_...`)
- Backend uses `stripe.charges.create` — **no webhook endpoint exists yet**
- **Skip Stripe webhooks** until a `/api/stripe/webhook` route is added to the backend

### 5b. What to do now

1. **Developers** → **API keys** — confirm test keys are active
2. Ensure Railway has (friend sets tomorrow):
   ```
   STRIPE_SECRET_KEY=sk_test_...
   STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```
3. **Test payment:** https://www.roomfinderai.com/payment.html  
   Use Stripe test card: `4242 4242 4242 4242`, any future expiry, any CVC

### 5c. Live keys (later — not for launch)

Only when ready for real money:
1. Stripe → toggle **View test data** OFF
2. Copy **live** `sk_live_...` and `pk_live_...`
3. Update Railway variables
4. Complete Stripe business verification

---

## Task 6 — Cloudflare Turnstile (bot protection on forgot-password)

**Dashboard:** https://dash.cloudflare.com → **Turnstile**

Production site key (if unchanged): `0x4AAAAAABjjAXWppygcnbuz`

1. Open your Turnstile widget
2. **Domains** → add:
   ```
   www.roomfinderai.com
   roomfinderai.com
   localhost
   ```
3. Railway variable:
   ```
   TURNSTILE_SITE_KEY=0x4AAAAAABjjAXWppygcnbuz
   ```

**Test:** https://www.roomfinderai.com/forgot-password.html — captcha should appear.

---

## Task 7 — Railway env vars summary (friend / tomorrow)

Copy this list for Railway → **Variables**:

```bash
# Required
NODE_ENV=production
ENABLE_DEMO_MODE=false
SUPABASE_URL=https://fkktwhjybuflxqzopaex.supabase.co
SUPABASE_ANON_KEY=<from Supabase>
SUPABASE_SERVICE_ROLE_KEY=<from Supabase>
GROQ_API_KEY=<from console.groq.com>
ADMIN_KEY=<openssl rand -base64 32>

# Phase 5 services
BREVO_API_KEY=<xkeysib-...>
GOOGLE_API_KEY=<restricted Maps key>
GOOGLE_OAUTH_CLIENT_ID=<from Google Console>
GOOGLE_OAUTH_CLIENT_SECRET=<from Google Console>
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
TURNSTILE_SITE_KEY=0x4AAAAAABjjAXWppygcnbuz
JWT_SECRET=<openssl rand -base64 32>
SESSION_SECRET=<openssl rand -base64 32>
AI_PROVIDER=auto
ENABLE_ANONYMOUS_BROWSING=true
```

---

## Phase 5 completion checklist

| # | Task | Done? |
|---|------|-------|
| 1 | Brevo sender `humblewoslayer@gmail.com` verified | ☐ |
| 2 | Google Maps key — referrers restricted | ☐ |
| 3 | Google Maps — Geocoding + Maps JS APIs enabled | ☐ |
| 4 | Google OAuth — JS origins added | ☐ |
| 5 | Google OAuth — redirect URIs added | ☐ |
| 6 | Google OAuth — consent screen published or test users added | ☐ |
| 7 | Supabase — Site URL + redirect URLs set | ☐ |
| 8 | Stripe test keys confirmed (webhooks skipped) | ☐ |
| 9 | Turnstile domains added | ☐ |
| 10 | All keys added to Railway + redeploy from `main` | ☐ |

---

## Test everything (after Railway redeploy)

```bash
curl https://www.roomfinderai.com/health
curl https://www.roomfinderai.com/api/brevo-status
```

Browser:
- [ ] Register + confirm email
- [ ] Forgot password + Turnstile
- [ ] Login with Google
- [ ] Listings map loads
- [ ] Payment page with test card `4242...`
