# RoomFinderAI Platform Status

**Last updated:** July 1, 2026

## Current availability

| Platform | Status | Where to use |
|----------|--------|--------------|
| **Web** | **Active** | [https://www.roomfinderai.com](https://www.roomfinderai.com) |
| **Android** | **Closed (temporary)** | Not on Google Play. Source retained in repo but not maintained for public use. |
| **iOS** | **Closed (temporary)** | Not on the App Store or TestFlight. Source retained in repo but not maintained for public use. |

> **Use the website for all RoomFinderAI features right now.** Native mobile apps are paused while we stabilize backend integrations, storage, auth, and AI negotiation across platforms.

---

## Why mobile apps are closed

The Android (`RoomFinderAndroid/`) and iOS (`RoomFinderAI-IOS/`) codebases are **temporarily locked** while we:

1. Align all clients with the production API at `https://www.roomfinderai.com`
2. Finish Supabase auth, storage, and realtime parity on web first
3. Resolve open production issues (email verification, service-role storage, AI rate limits)
4. Reduce support load from incomplete mobile builds

This is a **temporary product decision**, not a cancellation of mobile development.

---

## What works today (web only)

On [roomfinderai.com](https://www.roomfinderai.com) you can use:

- Browse and search listings
- AI negotiator
- RoomPal roommate matching
- Account sign-up / login (Supabase)
- Favorites, profile, and legal tools

Check live service health: `GET /health` and `GET /api/platform-status`

---

## Mobile app directories (locked)

| Path | Purpose |
|------|---------|
| [`RoomFinderAndroid/`](../RoomFinderAndroid/) | Native Android (Java) — **do not distribute** |
| [`RoomFinderAI-IOS/`](../RoomFinderAI-IOS/) | Native iOS (SwiftUI) — **do not distribute** |
| [`archive/legacy-android/`](../archive/legacy-android/android/) | Deprecated Capacitor Android — archived |

Each mobile folder contains a `PLATFORMS_LOCKED.md` file with the same notice for contributors.

---

## For users

- **Do not install** old APK files from `builds/` or third-party sources.
- **Do not expect** App Store or Play Store listings — they are not live.
- **Use the website** on mobile browsers; the web app is responsive.
- For help: [Support](https://www.roomfinderai.com/support.html) · [Platform status page](https://www.roomfinderai.com/platform-status.html)

---

## For developers & contributors

### Single source of truth

Platform flags live in [`backend/platform-status.js`](../backend/platform-status.js).

```js
platforms.web.status      // 'active'
platforms.android.status  // 'closed'
platforms.ios.status      // 'closed'
```

### API

- `GET /api/platform-status` — JSON for clients and monitoring
- `GET /health` — includes `platforms` summary

### Web UI

- Site-wide banner: `frontend/js/platform-status-banner.js` (injected on HTML pages)
- Dedicated page: `frontend/platform-status.html`
- Styles: `frontend/css/platform-status.css`

### Re-opening mobile apps (checklist)

When ready to resume Android/iOS:

1. Set `status: 'active'` in `backend/platform-status.js` for the relevant platform(s)
2. Update this document and both mobile `PLATFORMS_LOCKED.md` files
3. Update root `README.md` platform table
4. Remove or tone down the web banner in `platform-status-banner.js`
5. Verify builds, signing, store listings, and E2E tests before public release
6. Announce on the website, GitHub README, and support channels

---

## Communication channels

| Channel | Message |
|---------|---------|
| GitHub README | Platform table shows web = active, mobile = closed |
| Website banner | Top-of-page notice on all HTML pages |
| `/platform-status.html` | Full public status page |
| Mobile READMEs | Locked notice at top of each app README |

---

## Questions

Contact the team via the website support page or your usual RoomFinderAI contributor channel.

**Summary:** Web is live. Android and iOS are intentionally closed for now. Check this doc before building or distributing mobile apps.
