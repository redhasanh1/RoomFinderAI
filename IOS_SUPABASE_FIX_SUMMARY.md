# iOS Supabase Listings Query Fix

## Problem Analysis
The iOS app was showing "Connected" but "Loaded 0 listings" despite the web version working correctly. After analyzing both implementations, the issue was identified as a configuration difference between web and iOS Supabase clients.

## Root Cause
- **Web version**: Explicitly configured for anonymous access with `persistSession: false`, `autoRefreshToken: false`
- **iOS version**: Used default Supabase configuration which may interfere with RLS policies
- **RLS Policies**: Database has Row Level Security enabled with policies that depend on user context

## Changes Made

### 1. SupabaseService.swift - Anonymous Configuration
Updated the Supabase client initialization to match the web version:

```swift
// Configure client for anonymous access (matching web implementation)
var config = SupabaseClientOptions()
config.auth = AuthOptions(
    persistSession: false,        // Disable session persistence like web
    autoRefreshToken: false,      // Disable token refresh like web
    detectSessionInUrl: false     // Disable URL session detection like web
)
config.global.headers = [
    "X-Client-Info": "RoomFinderAI-iOS-Native"
]
```

### 2. Enhanced Error Handling and Diagnostics
- Added comprehensive error logging in `fetchListingsWithPagination`
- Added RLS-specific error detection
- Added fallback count queries to diagnose empty results

### 3. Anonymous Access Fallback
Created `setupAnonymousAccess()` method that calls the RLS function:
```swift
func setupAnonymousAccess() async throws {
    let _: String? = try await client
        .rpc("set_current_user_email", params: ["email": ""])
        .execute()
        .value
}
```

### 4. Enhanced Fetch Method
Added `fetchListingsWithAnonymousAccess()` that:
1. First tries regular fetch
2. If it fails, sets up anonymous access and retries

### 5. Comprehensive Diagnostic Test
Added `runDiagnosticTest()` method to verify:
- Basic connection
- Anonymous access setup
- Listing fetch with detailed logging
- Database count verification

## Testing Instructions

### 1. Basic Test
Run the iOS app and check the console logs. You should see:
```
🔧 Initializing Supabase client for anonymous access...
✅ Supabase client initialized successfully for anonymous access
🔓 Anonymous mode enabled - no authentication required
```

### 2. Diagnostic Test
Add this to your view or call it from the ListingsViewModel:
```swift
listingsViewModel.runSupabaseDiagnostics()
```

### 3. Expected Results
If working correctly, you should see:
- Connection test: PASSED
- Anonymous access setup: PASSED or acceptable failure
- Fetch listings: PASSED with listing count > 0
- Count verification: PASSED with total count

## Web vs iOS Comparison

| Aspect | Web Version | iOS Version (Fixed) |
|--------|-------------|-------------------|
| Client Config | Anonymous with disabled auth | ✅ Same |
| Query Structure | `from('listings').select('*')` | ✅ Same |
| RLS Handling | None needed | ✅ Automatic fallback |
| Error Handling | Basic | ✅ Enhanced |

## Fallback Strategy
If the primary fix doesn't work:
1. The enhanced method automatically tries anonymous access setup
2. Detailed error logs help identify specific RLS policy issues
3. Diagnostic test provides comprehensive debugging information

## Files Modified
1. `/RoomFinderAI/Services/SupabaseService.swift` - Main configuration and query fixes
2. `/RoomFinderAI/Services/ListingsViewModel.swift` - Updated to use enhanced methods
3. Added comprehensive logging and diagnostic capabilities

## Next Steps
1. Test the iOS app with these changes
2. Run the diagnostic test if issues persist
3. Check console logs for specific error messages
4. If needed, temporarily disable RLS on listings table for debugging

The changes ensure the iOS app queries Supabase exactly like the working web version while providing better error handling and debugging capabilities.