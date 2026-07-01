# RoomFinder Android App

A native Android application for finding and listing rental properties, built to complement the RoomFinderAI website.

## Features

### Core Features
- **Browse Listings**: View available rental properties in a clean grid layout
- **Search & Filter**: Search by location, price range, and number of bedrooms
- **Property Details**: View detailed information about each property
- **Favorites**: Save and manage favorite properties locally
- **Post Listings**: Create new property listings with photos

### User Experience
- **Optional Login**: Browse and use most features without requiring login
- **Material Design 3**: Modern, clean interface following Google's design guidelines
- **Offline Support**: Favorites stored locally for offline access
- **Image Loading**: Optimized image loading with Glide library

### Navigation
- **Bottom Navigation**: Easy access to 5 main sections:
  - Home (Browse listings)
  - Search (Advanced search with filters)
  - Post (Create new listings)
  - Favorites (Saved properties)
  - Profile (Login/account management)

## Technical Stack

- **Language**: Java
- **UI Framework**: Android Views with ViewBinding
- **Architecture**: Fragment-based with bottom navigation
- **Networking**: Retrofit + OkHttp
- **Image Loading**: Glide
- **Local Storage**: SharedPreferences
- **Design**: Material Design 3 components

## API Integration

The app is designed to work with the RoomFinderAI backend API:

- `GET /api/listings` - Fetch all listings
- `GET /api/listings/search` - Search listings with filters
- `POST /api/listings` - Create new listing
- `POST /api/auth/login` - User authentication
- `POST /api/auth/register` - User registration

## Build Instructions

1. Install **JDK 17** (Gradle 8.13 fails on Java 25). Example:
   ```bash
   export JAVA_HOME=$(/usr/libexec/java_home -v 17)
   ```
2. Copy `local.properties.template` to `local.properties` and set `sdk.dir` to your Android SDK path.
   - macOS default: `sdk.dir=/Users/<you>/Library/Android/sdk`
3. Open the project in Android Studio (or build from CLI):
   ```bash
   cd RoomFinderAndroid
   ./gradlew assembleDebug
   ./gradlew installDebug   # requires emulator or device
   ```

API base URL is `https://www.roomfinderai.com/` in `ApiClient.java` and `AuthService.java`.

## Project Structure

```
app/src/main/java/com/roomfinder/android/
├── MainActivity.java
├── activities/
│   └── LoginActivity.java
├── fragments/
│   ├── HomeFragment.java
│   ├── SearchFragment.java
│   ├── PostFragment.java
│   ├── FavoritesFragment.java
│   └── ProfileFragment.java
├── adapters/
│   └── ListingsAdapter.java
├── models/
│   ├── Listing.java
│   └── ApiResponse.java
└── network/
    ├── ApiService.java
    └── ApiClient.java
```

## Features Not Yet Implemented

- Chat system integration
- Property detail activity
- Image upload for new listings
- Push notifications
- Advanced user management

## Configuration

API keys are loaded from `local.properties` or environment variables at build time (see `local.properties.template`).

Base URL: `https://www.roomfinderai.com/` in `ApiClient.java`.

## Minimum Requirements

- Android 7.0 (API level 24)
- Target Android 14 (API level 34)
- Internet permission for API calls