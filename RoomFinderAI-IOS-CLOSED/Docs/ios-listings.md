# iOS Listings Implementation Guide

## Overview

This guide documents the iOS implementation that replicates the exact behavior of the web RoomFinderAI listings functionality. The iOS app now uses the same Supabase database, API queries, filters, pagination, auth, and real-time updates as the website.

## Environment Setup

### 1. Supabase Configuration

Add the following keys to your `Info.plist` file to configure Supabase:

```xml
<key>SUPABASE_URL</key>
<string>https://zmxyysauqtfkvntgtjsm.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string>eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM</string>
```

### 2. Xcode Configuration

1. Open your Xcode project
2. Select your app target
3. Go to the "Info" tab
4. Add the Supabase configuration as Custom iOS Target Properties

Alternatively, create a `Config.plist` file in your project and load the values programmatically.

## Architecture Overview

### Data Layer

```
Data/
├── SupabaseClientProvider.swift    # Singleton Supabase client
├── ListingsService.swift           # Core API service with retry logic
├── ListingsFilter.swift           # Filter model matching web filters
├── ListingsRealtime.swift         # Real-time subscription handling
└── AuthService.swift              # Authentication with Keychain storage
```

### Presentation Layer

```
Presentation/
├── ListingsViewModel.swift         # Main view model with real-time updates
└── NewListingsView.swift          # SwiftUI view with infinite scroll
```

## API Parity with Web

### Web Query Structure (from listings-api.js)
```javascript
let query = supabase
    .from('listings')
    .select('*')
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

// Filters
if (filters.city) query = query.ilike('city', `%${filters.city}%`);
if (filters.maxPrice) query = query.lte('price', filters.maxPrice);
if (filters.minPrice) query = query.gte('price', filters.minPrice);
if (filters.house_type) query = query.eq('house_type', filters.house_type);
if (filters.bedrooms) query = query.eq('bedrooms', filters.bedrooms);
```

### iOS Implementation (ListingsService.swift)
```swift
var query = client.database
    .from("listings")
    .select("*")
    .order("created_at", ascending: false)
    .range(from: from, to: to)

// Exact same filters
if let city = filters.city, !city.isEmpty {
    query = query.ilike("city", "%\(city)%")
}
if let maxPrice = filters.maxPrice {
    query = query.lte("price", maxPrice)
}
if let minPrice = filters.minPrice {
    query = query.gte("price", minPrice)
}
if let houseType = filters.houseType, !houseType.isEmpty {
    query = query.eq("house_type", houseType)
}
if let bedrooms = filters.bedrooms {
    query = query.eq("bedrooms", bedrooms)
}
```

## Filter Mapping

| Web Filter | iOS Implementation | Query |
|------------|-------------------|-------|
| `filters.city` | `filters.city` | `ilike('city', '%value%')` |
| `filters.maxPrice` | `filters.maxPrice` | `lte('price', value)` |
| `filters.minPrice` | `filters.minPrice` | `gte('price', value)` |
| `filters.house_type` | `filters.houseType` | `eq('house_type', value)` |
| `filters.bedrooms` | `filters.bedrooms` | `eq('bedrooms', value)` |
| `filters.search` | `filters.search` | `ilike('title', '%value%')` |

## Real-time Implementation

### Web Realtime (from listings-api.js)
```javascript
const subscription = supabase
    .channel('public:listings')
    .on('postgres_changes', { 
        event: 'INSERT', 
        schema: 'public', 
        table: 'listings' 
    }, (payload) => {
        callback('INSERT', payload.new);
    })
    .subscribe();
```

### iOS Realtime (ListingsRealtime.swift)
```swift
channel = client.realtime.channel("public:listings")
    .on(.postgresChanges(.insert, schema: "public", table: "listings")) { payload in
        let listing = try payload.decodeRecord(as: Listing.self)
        onChange(.insert(listing))
    }
    .subscribe()
```

## Authentication Flow

### Web Auth (from auth-manager.js)
- Uses Supabase Auth with RLS policies
- Sets `current_setting('app.current_user_email')` for RLS
- Persists session in localStorage

### iOS Auth (AuthService.swift)
- Uses Supabase Auth Swift SDK
- Stores session securely in Keychain
- Same RLS policy compliance
- Calls `set_current_user_email` RPC function

## Database Schema

### Listings Table Structure
```sql
CREATE TABLE listings (
    id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    price INTEGER NOT NULL,
    city VARCHAR(100) NOT NULL,
    street VARCHAR(255) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    house_type VARCHAR(50) NOT NULL,
    bedrooms INTEGER NOT NULL,
    utilities VARCHAR(50) DEFAULT 'Not included',
    description TEXT,
    media JSONB DEFAULT '[]'::jsonb,
    user_email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### RLS Policies
- `Anyone can view listings` - SELECT for all users
- `Users can create their own listings` - INSERT with email check
- `Users can update their own listings` - UPDATE with email check

## Pagination

### Web Implementation
- Page size: 20 items
- Uses `.range(offset, offset + limit - 1)`
- Infinite scroll with "Load More" button

### iOS Implementation
- Same page size: 20 items
- Same range query: `.range(from: from, to: to)`
- SwiftUI LazyVStack with `.onAppear` for infinite scroll
- Pull-to-refresh support

## Error Handling & Retries

### Retry Strategy
- Maximum 2 retries with exponential backoff
- Delays: 1s, 2s, 4s
- User-friendly error messages
- Automatic retry on network timeout

### Error Types
- `networkTimeout` - Connection issues
- `serverError` - Supabase errors
- `decodingError` - JSON parsing issues
- `unknownError` - Unexpected errors

## Usage Instructions

### 1. Replace Existing ListingsView
```swift
// In your main app or dashboard view
NewListingsView()
    .environmentObject(authService)
```

### 2. Initialize Services
```swift
@StateObject private var authService = AuthService()

var body: some View {
    ContentView()
        .environmentObject(authService)
}
```

### 3. Handle Authentication
```swift
// Sign in
try await authService.signIn(email: email, password: password)

// Sign out
try await authService.signOut()
```

## Real-time Features

### Connection Status
- Real-time subscription status monitoring
- Automatic reconnection on failures
- Visual indicators for connection state

### Update Handling
- Debounced updates (150ms) to prevent UI thrash
- Smart filtering of real-time events
- Automatic list synchronization

### Event Types
- `INSERT` - New listings added at top of list
- `UPDATE` - Existing listings updated in place
- `DELETE` - Listings removed from list

## Testing & Verification

### 1. Verify Same Results
Compare web and iOS results for identical filters:
```bash
# Web: Apply filters for "Toronto", max price $2000, 2 bedrooms
# iOS: Apply same filters and verify identical results
```

### 2. Real-time Testing
1. Create/update/delete listing from web interface
2. Verify changes appear in iOS within 2-3 seconds
3. Test with multiple devices simultaneously

### 3. Authentication Testing
1. Sign in on web, verify same user access in iOS
2. Create listing on iOS, verify visibility on web
3. Test RLS policies are enforced correctly

## Performance Considerations

### Optimizations
- Image lazy loading with AsyncImage
- Efficient list updates using SwiftUI's id-based diffing
- Pagination to limit memory usage
- Debounced real-time updates

### Memory Management
- Automatic cleanup of real-time subscriptions
- Weak references in closures to prevent retain cycles
- Efficient JSON decoding with Codable

## Troubleshooting

### Common Issues

1. **No listings showing**
   - Check SUPABASE_URL and SUPABASE_ANON_KEY in Info.plist
   - Verify network connectivity
   - Check Supabase dashboard for RLS policies

2. **Real-time not working**
   - Ensure Realtime is enabled in Supabase project
   - Check network allows WebSocket connections
   - Verify subscription channel name matches web

3. **Authentication failures**
   - Check user exists in Supabase Auth
   - Verify RLS policies allow user access
   - Ensure `set_current_user_email` RPC exists

### Debug Logging
Enable debug logging by adding this to your app:
```swift
// Add debug prints in ListingsService
print("Query parameters: \(filters)")
print("Results count: \(response.count)")
```

## Deployment

### Production Considerations
1. Move secrets to secure configuration
2. Enable network security (SSL pinning)
3. Add crash reporting for service errors
4. Monitor real-time connection health
5. Implement offline caching for better UX

### App Store Submission
- Ensure no hardcoded secrets in source code
- Add network usage description in Info.plist
- Test on various iOS versions and devices
- Verify compliance with App Store guidelines

This implementation provides complete feature parity between the web and iOS versions of RoomFinderAI listings, ensuring users have a consistent experience across platforms.