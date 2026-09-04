# RoomFinderAI — Android App

Native Android app for [RoomFinderAI](https://www.roomfinderai.com), matching the website design system (purple gradient theme, glassmorphism cards, intuitive bottom navigation).

## Features

| Tab | What it does |
|-----|--------------|
| **Home** | Featured listings, search, filters, quick tools (AI Negotiator, RoomPal, Browse) |
| **Search** | Full search with map-style filters |
| **Post** | Create a new rental listing with photos |
| **Favorites** | Saved properties |
| **Profile** | Account, my listings, AI chat, legal tools |

## Requirements

- Android Studio Ladybug (2024.2+) or newer
- JDK 11+
- Android SDK 34
- A device or emulator running Android 7.0 (API 24)+

## Setup

1. Open the `RoomFinderAndroid` folder in Android Studio.
2. Copy `local.properties.template` → `local.properties` and set your Android SDK path.
3. Copy `keystore.properties.template` → `keystore.properties` only if you need release signing.
4. Add API keys to `local.properties` (same keys as the web backend):

```properties
sdk.dir=C\:\\Users\\YourName\\AppData\\Local\\Android\\Sdk
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
OPENAI_API_KEY=your-openai-key
GOOGLE_API_KEY=your-google-key
```

The app talks to production at `https://www.roomfinderai.com/api` by default.

## Build & Run

```bash
cd RoomFinderAndroid
./gradlew assembleDebug
```

Install on a connected device:

```bash
./gradlew installDebug
```

Or use **Run ▶** in Android Studio with an emulator selected.

## Design

- **Colors:** `#667eea` → `#764ba2` primary gradient (same as website)
- **Typography:** Material 3 with Inter-style sans-serif
- **Navigation:** Bottom tabs — Home · Search · Post · Favorites · Profile
- **Launch:** Branded splash screen → main app

## Project structure

```
RoomFinderAndroid/
├── app/src/main/java/com/roomfinder/android/
│   ├── MainActivity.java          # Bottom nav shell
│   ├── activities/                # Login, listing detail, chat, etc.
│   ├── fragments/                 # Home, Search, Post, Favorites, Profile
│   ├── network/                   # Retrofit API + Supabase
│   └── services/                  # AI negotiator, chat, legal tools
└── app/src/main/res/              # Layouts, drawables, themes
```

## Notes

- Debug builds use application ID `com.roomfinderai.android.debug`
- Release builds require a configured keystore (see `RELEASE_INSTRUCTIONS.md`)
- Chat with landlords and AI Negotiator are available from listing cards and Profile
