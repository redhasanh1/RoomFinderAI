# RoomFinderAI

AI-powered rental search, negotiation, and marketplace platform.

> **Platform notice (July 2026):** Only the **web app** is live at [roomfinderai.com](https://www.roomfinderai.com). **Android and iOS native apps are temporarily closed** — not on Google Play or the App Store. See [`docs/PLATFORM_STATUS.md`](docs/PLATFORM_STATUS.md).

## Platforms

| Platform | Path | Status |
|----------|------|--------|
| **Web** | [`frontend/`](frontend/) + [`backend/`](backend/) | **Active** — primary platform on Railway |
| **Android** | [`RoomFinderAndroid/`](RoomFinderAndroid/) | **Closed (temporary)** — source retained, not distributed |
| **iOS** | [`RoomFinderAI-IOS/`](RoomFinderAI-IOS/) | **Closed (temporary)** — source retained, not distributed |
| Legacy Android | [`archive/legacy-android/android/`](archive/legacy-android/android/) | Archived — deprecated Capacitor app |

Public status page: **[/platform-status.html](https://www.roomfinderai.com/platform-status.html)** · API: `GET /api/platform-status`

## Quick start (web)

```bash
cp .env.example .env    # fill in Supabase + API keys
npm install
npm run validate
npm start               # http://localhost:3000
```

See [`docs/guides/SETUP_GUIDE.md`](docs/guides/SETUP_GUIDE.md) for full setup.

## Project layout

```
RoomFinderAI/
├── backend/              # Express API server (production entry: backend/server.js)
├── frontend/             # Web UI (HTML/CSS/JS)
├── RoomFinderAndroid/    # Native Android app
├── RoomFinderAI-IOS/     # Native iOS app
├── database/
│   ├── migrations/     # Supabase schema migrations
│   └── sql/              # One-off SQL scripts
├── scripts/
│   ├── maintenance/      # Debug & test scripts
│   ├── migrations/       # Data migration scripts
│   └── tools/            # Config encrypt/decrypt, utilities
├── docs/
│   └── guides/           # Setup, implementation, and ops docs
├── archive/              # Unrelated files, legacy code, old root assets
├── ai-learning/          # AI learning module
├── cloudflare-worker/    # Edge worker
├── tests/                # Integration tests
└── 3D House Models/      # Static 3D assets served by web
```

## Deploy

Production runs on **Railway** via Nixpacks (`railway.json` → `node backend/server.js`).

Health check: `GET /health`

## Android / iOS (temporarily closed)

Native mobile apps are **not available** to users at this time. Use the website instead.

- Status & reopening plan: [`docs/PLATFORM_STATUS.md`](docs/PLATFORM_STATUS.md)
- Android (locked): [`RoomFinderAndroid/PLATFORMS_LOCKED.md`](RoomFinderAndroid/PLATFORMS_LOCKED.md)
- iOS (locked): [`RoomFinderAI-IOS/PLATFORMS_LOCKED.md`](RoomFinderAI-IOS/PLATFORMS_LOCKED.md)
