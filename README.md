# RoomFinderAI

AI-powered rental search, negotiation, and marketplace platform.

## Platforms

| Platform | Path | Status |
|----------|------|--------|
| **Web** | [`frontend/`](frontend/) + [`backend/`](backend/) | Primary — served by Express on Railway |
| **Android** | [`RoomFinderAndroid/`](RoomFinderAndroid/) | Primary native Android app |
| **iOS** | [`RoomFinderAI-IOS/`](RoomFinderAI-IOS/) | Native SwiftUI app |
| Legacy Android | [`archive/legacy-android/android/`](archive/legacy-android/android/) | Deprecated Capacitor-style app |

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

## Android / iOS

- Android: see [`RoomFinderAndroid/README.md`](RoomFinderAndroid/README.md)
- iOS: see [`RoomFinderAI-IOS/README.md`](RoomFinderAI-IOS/README.md) and [`RoomFinderAI-IOS/BUILD-AND-RUN.md`](RoomFinderAI-IOS/BUILD-AND-RUN.md)
