# RoomFinder AI iOS Backend Integration

This document outlines the complete backend integration system for the RoomFinder AI iOS app, enabling seamless communication with both Supabase and Railway-hosted APIs.

## 🏗️ Architecture Overview

The app uses a hybrid approach:
1. **Native iOS (Swift)** - Main app UI and logic
2. **Capacitor Bridge** - For JavaScript integration
3. **Railway Backend** - Primary API server
4. **Supabase** - Direct database access and real-time features

## 📁 Project Structure

### iOS Native Files
```
ios/App/App/
├── APIService.swift           # Main API service for Railway backend
├── SupabaseService.swift      # Supabase integration service
├── Services/
│   ├── BackendService.swift   # Capacitor bridge for JS services
│   └── NetworkManager.swift   # Network monitoring & retry logic
└── Info.plist                 # Updated with network permissions
```

### JavaScript/Web Files
```
ios/App/App/public/js/services/
├── env.js                     # Environment configuration
├── supabaseClient.js          # Supabase client setup
├── supabaseService.js         # Supabase operations
├── apiService.js              # Railway API operations
├── networkUtils.js            # Offline support & retries
├── index.js                   # Main export
└── demo-integration.js        # Usage examples
```

## 🔧 Configuration

### 1. Environment Variables

The app is configured with:
- **Supabase URL**: `https://zmxyysauqtfkvntgtjsm.supabase.co`
- **Railway API**: `https://roomfinder-ai-negotiator-production.up.railway.app`

### 2. Network Permissions

`Info.plist` has been updated with:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>supabase.co</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
        <key>railway.app</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## 🚀 Usage Examples

### Swift (Native iOS)

#### Fetch Properties
```swift
// Using Railway API
APIService.shared.fetchProperties { result in
    switch result {
    case .success(let properties):
        print("Loaded \(properties.count) properties")
    case .failure(let error):
        print("Error: \(error)")
    }
}

// Using Supabase directly
Task {
    let listings = try await SupabaseService.shared.fetchListings()
    let properties = listings.map { $0.toProperty() }
}
```

#### Authentication
```swift
// Sign up
APIService.shared.register(
    email: "user@example.com",
    password: "password123",
    firstName: "John",
    lastName: "Doe"
) { result in
    // Handle result
}

// Sign in
APIService.shared.login(
    email: "user@example.com",
    password: "password123"
) { result in
    // Handle result
}
```

#### AI Negotiation
```swift
// Start negotiation (Railway API)
let negotiationData = [
    "property_id": "prop_123",
    "initial_offer": 2500
]

var request = URLRequest.create(
    url: URL(string: "\(APIConfig.baseURL)/api/ai/negotiate")!,
    method: "POST",
    body: try? JSONSerialization.data(withJSONObject: negotiationData)
)

NetworkManager.shared.performRequest(request) { (result: Result<[String: Any], Error>) in
    // Handle negotiation response
}
```

### JavaScript (Web/Capacitor)

#### Initialize Services
```javascript
import { initializeServices } from './services/index.js';

// Initialize on app start
const status = await initializeServices();
console.log('App status:', status);
```

#### Fetch Properties
```javascript
import { supabaseService, apiService } from './services/index.js';

// From Supabase
const { success, data } = await supabaseService.getProperties({
    city: 'San Francisco',
    minPrice: 1000,
    maxPrice: 3000
});

// From Railway
const result = await apiService.getProperties({
    city: 'San Francisco',
    bedrooms: 2
});
```

## 🌐 Offline Support

### iOS Native
The `NetworkManager` automatically:
- Monitors network connectivity
- Queues requests when offline
- Retries failed requests with exponential backoff
- Processes queued requests when back online

```swift
// Listen for network changes
NotificationCenter.default.addObserver(
    self,
    selector: #selector(networkStatusChanged),
    name: NetworkManager.networkStatusChangedNotification,
    object: nil
)

// Check network status
if NetworkManager.shared.isNetworkAvailable {
    // Make request
} else {
    // Show offline message
}
```

### JavaScript
The `networkUtils.js` provides:
- Automatic request queuing
- Network status detection
- Retry logic with backoff

```javascript
// Check network status
const isOnline = await networkUtils.checkNetworkConnectivity();

// Requests are automatically queued when offline
const result = await apiService.createProperty(propertyData);
if (!result.success && result.error === 'Request queued for when you\'re back online') {
    // Handle offline state
}
```

## 🔒 Security

1. **API Keys**: Only public Supabase anon keys are used in the app
2. **Authentication**: JWT tokens stored securely in Keychain/UserDefaults
3. **HTTPS Only**: All API communication uses HTTPS
4. **CORS**: Railway backend configured to accept requests from mobile apps

## 📊 Analytics & Tracking

```swift
// iOS Native
APIService.shared.trackEvent("property_viewed", data: ["property_id": "123"])

// JavaScript
await apiService.trackEvent('property_viewed', {
    property_id: 'prop_123',
    source: 'search_results'
});
```

## 🔄 Real-time Updates

### Supabase Realtime (JavaScript)
```javascript
// Subscribe to chat messages
const subscription = supabaseService.subscribeToChat(chatId, (message) => {
    console.log('New message:', message);
});

// Unsubscribe
supabaseService.unsubscribeFromChat(subscription);
```

## 🐛 Error Handling

### iOS Native
```swift
enum APIError: LocalizedError {
    case offline
    case unauthorized
    case serverError(Int)
    // ...
}

// User-friendly error messages
switch error {
case NetworkError.offline:
    showAlert("No internet connection")
case NetworkError.unauthorized:
    showLoginScreen()
default:
    showAlert(error.localizedDescription)
}
```

### JavaScript
```javascript
const result = await apiService.getProperties();
if (!result.success) {
    const userMessage = networkUtils.formatError(result.error);
    alert(userMessage);
}
```

## 📱 Platform-Specific Features

The integration automatically detects the platform:
```javascript
import { isCapacitor, isIOS } from './services/env.js';

if (isIOS) {
    // Use iOS-specific features
    // e.g., biometric auth, push notifications
}
```

## 🧪 Testing

### Test Network Integration
```swift
// iOS
func testAPIConnection() {
    APIService.shared.healthCheck { result in
        print("API Status:", result)
    }
}

// JavaScript
const health = await apiService.healthCheck();
console.log('Backend health:', health);
```

### Test Supabase Connection
```javascript
const { data: { session } } = await supabase.auth.getSession();
console.log('Supabase auth:', session ? 'Connected' : 'Not connected');
```

## 📝 Important Notes

1. **CORS Configuration**: Ensure Railway backend has proper CORS headers for mobile origins
2. **Rate Limiting**: The app implements automatic retry with backoff for rate-limited requests
3. **Token Refresh**: Auth tokens are automatically refreshed by Supabase client
4. **Image Caching**: `ImageService` provides automatic image caching for better performance
5. **Secure Storage**: For sensitive data, consider using Keychain (iOS) instead of UserDefaults

## 🔗 Related Documentation

- [Supabase iOS SDK](https://github.com/supabase/supabase-swift)
- [Capacitor Documentation](https://capacitorjs.com/docs)
- [Railway Deployment Guide](https://docs.railway.app)
- [iOS App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)