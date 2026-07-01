# RoomFinderAI — Every Connection (Master Reference)

**Production:** https://www.roomfinderai.com · **Last checked:** July 1, 2026

One table per integration: what it does, how it connects, live status, and what you must do.

**Legend:** 🟢 Working · 🟡 Partial / config needed · 🔴 Blocked · ⚪ Optional

---

## 1. Authentication & users

| Connection | How it works | API / UI | Env vars | Live | Your action |
|------------|--------------|----------|----------|------|-------------|
| **Supabase Auth** | Sign up, login, sessions, JWT | `login.html`, `supabase-auth-only.js` | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | 🟢 `supabase: true` | Service role on Railway |
| **Email + password login** | Backend validates + Supabase | `POST /api/login` | Supabase + optional `profiles` table | 🟢 Route live | — |
| **Email verification** | 6-digit code via Brevo | `POST /api/send-verification`, `/api/verify-email` | `BREVO_API_KEY` | 🟢 | Verify Brevo sender |
| **Google Sign-In** | ID token + OAuth code flow | `POST /api/auth/google`, `/api/auth/google/oauth-code` | `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET` | 🟡 Client ID on prod; **new secret on Railway** | Paste new OAuth secrets tomorrow |
| **Apple Sign-In** | Identity token (demo verify) | `POST /api/auth/apple` | `APPLE_CLIENT_ID` | 🟡 Optional | Low priority |
| **Forgot password** | Reset code via Brevo | `forgot-password.html` → `/api/send-reset-code` | `BREVO_API_KEY` | 🟢 | — |
| **Cloudflare Turnstile** | Bot check on reset | `GET /api/turnstile-key` | `TURNSTILE_SITE_KEY` | 🟡 Site key live | Whitelist domains in Cloudflare |
| **Profile update** | Name, image | `POST /api/update-profile`, `/api/update-profile-image` | Supabase storage | 🟢 | — |
| **ID verification** | Selfie + ID upload, manual review | `/api/verify/upload-id`, `/api/verify/face-match` | Azure keys optional | 🟡 Manual review path | Azure keys on Railway if using auto |

**Supabase dashboard (you did):**
- Site URL: `https://www.roomfinderai.com`
- Redirect URLs: `https://www.roomfinderai.com/**`

---

## 2. Database & storage (Supabase)

| Connection | Tables / buckets | SQL file | Live | Your action |
|------------|------------------|----------|------|-------------|
| **Listings** | `listings` | core schema | 🟢 `/api/listings` 200 | — |
| **Favorites** | `favorites` | core schema | 🟢 API live | — |
| **Profiles** | `profiles` | core schema | 🟢 | — |
| **RoomPal** | `roommate_profiles` + related | `roommate_profiles_schema_v2.sql` | 🟢 You ran SQL | Confirm in Table Editor |
| **Sublease** | `sublease_requests`, `sublease_matches` | `simple_sublease_schema.sql` | 🟢 You ran SQL | API works; **UI 404 until Railway redeploy** |
| **Listing photos** | Storage bucket `listing-media` | `setup-supabase-storage.sql` | 🟢 You ran SQL | Test upload after redeploy |
| **Profile images** | `profile-images` | storage SQL | 🟢 | — |
| **Chat files** | `chat-attachments` | storage SQL | 🟢 | — |
| **Verification docs** | `verification-docs` | storage SQL | 🟢 | — |
| **Disputes** | localStorage + email only | `create_disputes_schema.sql` optional | 🟡 Not in DB yet | Optional later |

---

## 3. Maps & location

| Connection | How it works | API / UI | Env vars | Live | Your action |
|------------|--------------|----------|----------|------|-------------|
| **Google Maps (browser)** | Map on listings page | `listings.html` loads key from `/api/config` | `GOOGLE_API_KEY` | 🟢 Key exposed to client | **Websites** referrer restriction (you did) |
| **Geocoding (batch)** | Address → lat/lng for listings | `POST /api/geocode/batch` | `GOOGLE_API_KEY` | 🟡 Server calls may fallback to Nominatim | Same key or separate server key later |
| **Reverse geocode** | Photo wizard location | `POST /api/reverse-geocode` | `GOOGLE_API_KEY` | 🟢 Route live | — |
| **Nominatim fallback** | Free geocode if Google fails | Inside geocode routes | None | 🟢 | — |
| **Student housing map** | Uses `/api/listings` data | `student-housing.html` | Same as listings | 🟢 Page 200 | — |

---

## 4. Payments (Stripe)

| Connection | How it works | API / UI | Env vars | Live | Your action |
|------------|--------------|----------|----------|------|-------------|
| **Stripe.js checkout** | Card token → charge | `payment.html` → `POST /api/process-payment` | `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY` | 🟡 **Test mode** (`pk_test_...`) | Live keys when ready for real money |
| **Payment methods CRUD** | Saved cards in DB | `/api/payment-methods/*` | Stripe + Supabase | 🟢 Routes exist | Test with 4242... |
| **Subscriptions** | Plan status by email | `GET /api/subscription/:email` | Stripe + Supabase | 🟡 Test mode | — |
| **Cancel subscription** | DB update only | `POST /api/subscription/cancel` | — | 🟡 No Stripe webhook | Add webhooks later |
| **Bank info** | Stored in Supabase | `/api/bank-info/*` | — | 🟡 | Post-launch security hardening |

**Stripe dashboard:** Test mode OK for launch. Webhooks **not implemented** — skip for v1.

**Test card:** `4242 4242 4242 4242` · any future expiry · any CVC

---

## 5. Email (Brevo)

| Connection | How it works | API | Env vars | Live | Your action |
|------------|--------------|-----|----------|------|-------------|
| **Signup verification** | 6-digit code email | `/api/send-verification` | `BREVO_API_KEY` | 🟢 `brevo: true` | — |
| **Password reset** | Reset code email | `/api/send-reset-code` | `BREVO_API_KEY` | 🟢 | — |
| **Contact form** | Homepage + disputes notify | `POST /api/contact` | `BREVO_API_KEY`, `CONTACT_EMAIL` | 🟢 | — |
| **Message landlord** | Email relay in chat | `POST /api/message-landlord` | `BREVO_API_KEY` | 🟢 | — |
| **Negotiation emails** | AI negotiator notifications | Internal Brevo send | `BREVO_API_KEY` | 🟢 | — |

**Sender:** `humblewoslayer@gmail.com` (verified in Brevo)  
**Optional env:** `BREVO_SENDER_EMAIL`, `BREVO_SENDER_NAME`, `CONTACT_EMAIL`

---

## 6. AI (Groq + OpenAI)

| Connection | How it works | API / UI | Env vars | Live | Your action |
|------------|--------------|----------|----------|------|-------------|
| **AI chat / legal docs** | `callAI` with fallback | `POST /api/chat` | `GROQ_API_KEY` and/or `OPENAI_API_KEY`, `AI_PROVIDER=auto` | 🟡 OpenAI live; Groq likely missing | Add `GROQ_API_KEY` on Railway |
| **AI negotiator** | Multi-phase negotiation | `POST /api/ai-negotiate`, `/api/negotiate/*` | Same | 🟢 | Groq recommended (free) |
| **Lease review** | Legal center tab | `POST /api/negotiate/lease-review` | Same | 🟢 | — |
| **Landlord simulator** | Practice mode | `POST /api/landlord-simulator` | Same | 🟢 | — |
| **Photo analysis** | Cloudflare worker optional | `POST /api/analyze-property-photo` | `CLOUDFLARE_WORKER_URL` | ⚪ Optional | Set if using worker |
| **Market predictions** | Kijiji/Marketplace stubs | `/api/predict/*` | — | ⚪ Demo | — |

---

## 7. Market data (RentCast)

| Connection | How it works | API | Env vars | Live | Your action |
|------------|--------------|-----|----------|------|-------------|
| **RentCast API** | Valuation, comparables | `/api/rentcast/*` | `RENTCAST_KEY` | 🟢 `/api/rentcast/status` 200 | Optional — 40 calls/month limit in code |
| **Market intelligence** | Aggregated insights | `GET /api/market-intelligence` | RentCast or demo | 🟢 | — |

---

## 8. Azure (optional ID verification)

| Connection | How it works | API | Env vars | Live | Your action |
|------------|--------------|-----|----------|------|-------------|
| **Document Intelligence** | ID OCR | `/api/verify/upload-id` | `AZURE_DOCUMENT_INTELLIGENCE_*` | 🟢 Health true | — |
| **Face API** | Face match | `/api/verify/face-match` | `AZURE_FACE_*` | 🟢 Health true | — |

**Note:** App uses **manual admin review** for verification in practice.

---

## 9. Push notifications & service worker

| Connection | How it works | API | Env vars | Live | Your action |
|------------|--------------|-----|----------|------|-------------|
| **VAPID / push** | Browser push | `GET /api/vapid-key`, `POST /api/push-subscription` | `VAPID_*` | 🔴 Dummy key; 501 after redeploy | Future feature |
| **Property visits sync** | SW offline sync | `POST /api/property-visits` | — | 🟡 204 stub after redeploy | — |
| **Notification analytics** | SW dismiss events | `POST /api/analytics/notification-dismissed` | — | 🟡 204 stub | — |

---

## 10. Sublease marketplace

| Connection | How it works | API / UI | Depends on | Live | Your action |
|------------|--------------|----------|------------|------|-------------|
| **Browse requests** | Supabase query | `GET /api/sublease/search` | SQL + redeploy | 🟡 API in code; page **404** on prod | Railway redeploy |
| **Post request** | Create row | `POST /api/sublease/request` | SQL | 🟡 | Redeploy |
| **Express interest** | Match flow | `POST /api/sublease/express-interest` | SQL | 🟡 | Redeploy |
| **UI** | `sublease.html` | Static page | Railway | 🔴 404 on prod | Redeploy `main` |

---

## 11. RoomPal (roommate matching)

| Connection | How it works | API / UI | Depends on | Live | Your action |
|------------|--------------|----------|------------|------|-------------|
| **Profiles** | Supabase + `roommate-api.js` | `roommate-matching.html` | `roommate_profiles_schema_v2.sql` | 🟢 Page 200 | Test create profile |
| **Compatibility** | 47-factor JSON scores | Client + Supabase | SQL you ran | 🟢 | — |

---

## 12. Disputes

| Connection | How it works | Storage | Live | Your action |
|------------|--------------|---------|------|-------------|
| **File dispute** | Form + localStorage | `dispute-store.js` | 🔴 Page 404 on prod | Redeploy |
| **My disputes** | localStorage list | `my-disputes.html` | 🔴 Page 404 on prod | Redeploy |
| **Email notify** | `/api/contact` | Brevo | 🟢 | — |

---

## 13. Railway (deployment hub)

| Item | Status | Fix |
|------|--------|-----|
| Deploy branch | 🔴 Likely old commit | Set **`main`** |
| `NODE_ENV` | 🔴 `development` on live | Set **`production`** |
| Latest pages (sublease, disputes) | 🔴 404 | **Redeploy** |
| Security routes blocked | 🔴 `/debug-test` still open on live | Redeploy (fixed in code) |
| All env vars | 🟡 Partial | See checklist below |

### Railway variables — complete list

```bash
# Required
NODE_ENV=production
ENABLE_DEMO_MODE=false
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
ADMIN_KEY=
GROQ_API_KEY=

# Auth & email
BREVO_API_KEY=
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=
JWT_SECRET=
SESSION_SECRET=

# Maps & payments
GOOGLE_API_KEY=
STRIPE_SECRET_KEY=
STRIPE_PUBLISHABLE_KEY=

# Optional
OPENAI_API_KEY=
AI_PROVIDER=auto
TURNSTILE_SITE_KEY=
TURNSTILE_SECRET_KEY=
BREVO_SENDER_EMAIL=
CONTACT_EMAIL=
RENTCAST_KEY=
AZURE_DOCUMENT_INTELLIGENCE_KEY=
AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT=
AZURE_FACE_KEY=
AZURE_FACE_ENDPOINT=
APPLE_CLIENT_ID=
ENABLE_ANONYMOUS_BROWSING=true
```

---

## 14. Live smoke test results (July 1, 2026)

Run anytime: `bash scripts/production-smoke-test.sh`

| Category | Passed | Failed | Cause |
|----------|--------|--------|-------|
| Core pages | 12 | 3 | sublease, file-dispute, my-disputes — **not deployed** |
| Security | 0 | 2 | debug + brevo-status — **old deploy** |
| Health | 3 | 1 | `NODE_ENV` not production |
| **Total** | **15** | **6** | **All fixed by Railway redeploy** |

---

## 15. Go-live: what turns everything green

| Step | Who | Unlocks |
|------|-----|---------|
| 1. Railway branch → `main` + redeploy | Friend | New pages, security fixes, latest code |
| 2. `NODE_ENV=production` | Friend | Correct health, prod error handling |
| 3. `GROQ_API_KEY` | You → Railway | Free AI for all features |
| 4. Google OAuth secret (new client) | You → Railway | Google login |
| 5. Cloudflare Turnstile domains | You (when access) | Forgot-password captcha |
| 6. `bash scripts/production-smoke-test.sh` | You | Confirm 21/21 pass |

---

## Related docs

| Doc | Use |
|-----|-----|
| [`LIVE_INTEGRATIONS_AUDIT.md`](LIVE_INTEGRATIONS_AUDIT.md) | Deployment + third-party detail |
| [`PROJECT_COMPLETION_CHECKLIST.md`](PROJECT_COMPLETION_CHECKLIST.md) | Step-by-step launch |
| [`PHASE_5_SETUP_GUIDE.md`](PHASE_5_SETUP_GUIDE.md) | Dashboard configuration |
| [`QA_AUDIT_JULY_2026.md`](QA_AUDIT_JULY_2026.md) | Code fixes applied |
