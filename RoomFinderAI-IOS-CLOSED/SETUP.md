# iOS Listings Setup Guide

## Manual Xcode Steps Required

Since I cannot directly modify the Xcode project structure, here are the manual steps to complete the integration:

### 1. Add New Files to Xcode Project

1. Open `RoomFinderAI.xcodeproj` in Xcode
2. Right-click on the project navigator and select "Add Files to RoomFinderAI"
3. Navigate to and add these new files:

**Data Layer:**
- `Source/RoomFinderAI/Data/SupabaseClientProvider.swift`
- `Source/RoomFinderAI/Data/ListingsService.swift`
- `Source/RoomFinderAI/Data/ListingsFilter.swift`
- `Source/RoomFinderAI/Data/ListingsRealtime.swift`
- `Source/RoomFinderAI/Data/AuthService.swift`

**Presentation Layer:**
- `Source/RoomFinderAI/Presentation/ListingsViewModel.swift`
- `Source/RoomFinderAI/Presentation/NewListingsView.swift`

### 2. Add Supabase Package Dependencies

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter URL: `https://github.com/supabase/supabase-swift.git`
3. Select version `2.30.2` or later
4. Add to your main app target

**Note:** The Package.resolved file shows Supabase Swift is already installed, so this step may be complete.

### 3. Update App Integration

Replace your current listings view usage with the new implementation:

**In ContentView.swift or DashboardView.swift:**
```swift
// Replace the old ListingsView with:
NewListingsView()
```

**In your main App file:**
```swift
import SwiftUI

@main
struct RoomFinderAIApp: App {
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
```

### 4. Verify Configuration

1. Confirm `Info.plist` contains the Supabase keys (should be updated automatically):
   - `SUPABASE_URL`: https://zmxyysauqtfkvntgtjsm.supabase.co
   - `SUPABASE_ANON_KEY`: [the long JWT token]

2. Check that `SupabaseConfig.swift` has been updated to read from Info.plist

### 5. Build and Test

1. Clean build folder: **Product → Clean Build Folder**
2. Build the project: **⌘+B**
3. Fix any import or dependency issues
4. Run on simulator or device
5. Verify listings load and real-time updates work

## Expected Behavior

After setup, your iOS app should:

1. **Load listings** exactly matching the website for the same filters
2. **Support pagination** with infinite scroll
3. **Handle real-time updates** - new/updated/deleted listings appear automatically
4. **Match web filters** - city, price range, house type, bedrooms
5. **Show same data** - titles, prices, descriptions, images from Supabase
6. **Handle authentication** if users sign in (optional for viewing listings)

## Troubleshooting

### Build Errors
- Ensure all new Swift files are added to the Xcode target
- Check import statements and dependency resolution
- Verify Supabase Swift package is properly installed

### Runtime Issues
- Check Info.plist has correct Supabase URL and key
- Verify network permissions and connection
- Look for debug prints in Xcode console

### No Listings Showing
- Confirm Supabase database has listings data
- Test the same query on the website
- Check RLS policies allow anonymous access

## Next Steps

Once the manual Xcode setup is complete:

1. Test side-by-side with the website to confirm identical behavior
2. Add any additional UI customizations needed
3. Consider implementing offline caching for better UX
4. Add analytics or crash reporting for production use

For detailed technical documentation, see `Docs/ios-listings.md`.