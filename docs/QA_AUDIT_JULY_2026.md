# QA Audit — July 2026

Full pass on web UI + backend before Railway final deploy.

## Fixed in this pass

### Frontend
- Script load order: Supabase CDN before auth on `forgot-password`, `pricing`, `payment`, `verification-modal`
- `pricing`/`payment` use `universal-auth-manager.js` (fixes `UniversalAuth.init`)
- Mobile nav: `site-nav.js` uses `.expanded` for accordion sections
- `support.html` mobile menu + dropdown handlers completed
- Deep links: `profile.html#my-listings`, `listings.html#add-listing`, `listings.html#messages`
- Path fixes: `/student-housing` → `student-housing.html`, `/login` → `login.html`, payment success redirect
- `signup.html` links → `login.html`; `sitemap.xml` / `robots.txt` updated for roomfinderai.com
- Removed duplicate `notification-manager.js` on `ai-negotiator.html`
- `student-housing.html` nav: added Sublease

### Backend
- `/debug-test`, `/api/brevo-status`, `/listings-new` blocked in production
- Rate limits on `/api/verify-email` and `/api/verify-reset-code`
- Service-status: accurate `maps` and `idVerification` flags
- Stub routes for SW: push-subscription, property-visits, notification analytics (no 404 spam)
- `ADMIN_KEY` synced from config file to `process.env`
- Email sender configurable via `BREVO_SENDER_EMAIL`, `CONTACT_EMAIL` env vars

## Known limitations (post-launch backlog)

| Area | Notes |
|------|-------|
| Auth IDOR | Some routes trust client `email` without JWT — needs `requireAuth` middleware pass |
| Google OAuth | `tokeninfo` used; should verify `aud` with google-auth-library |
| Apple OAuth | JWT signature not verified |
| Turnstile | Client-only on forgot-password; server should verify `TURNSTILE_SECRET_KEY` |
| Stripe | Test mode, no webhooks, legacy Charges API |
| Push notifications | Stub 501 until VAPID keys + DB storage |
| Google Maps key | Exposed via `/api/config` — use referrer-restricted browser key only |

## Smoke test after Railway deploy

```bash
bash scripts/production-smoke-test.sh
```

See also: [`LIVE_INTEGRATIONS_AUDIT.md`](LIVE_INTEGRATIONS_AUDIT.md) — deployment, Supabase, and all third-party live status.
