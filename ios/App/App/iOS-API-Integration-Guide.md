# iOS API Integration Guide

## Overview

Your RoomFinderAI iOS app has been configured with a comprehensive API integration system that handles:

- Environment detection (web vs mobile)
- Secure API key storage using iOS Keychain
- Mobile-optimized HTTP requests with retry logic
- Proper CORS handling for Capacitor
- OpenAI, Supabase, and backend API integration

## Files Added/Modified

### New Service Files

1. **`Services/EnvironmentManager.swift`** - Handles environment detection and mobile-specific configurations
2. **`Services/APIKeyManager.swift`** - Secure storage and management of API keys
3. **`Services/MobileAPIService.swift`** - Mobile-optimized API service with retry logic
4. **`Services/AppInitializationService.swift`** - App startup initialization and diagnostics
5. **`APITestViewController.swift`** - Test interface for API integration

### Modified Files

1. **`APIService.swift`** - Updated to use mobile-optimized services
2. **`SupabaseService.swift`** - Enhanced with mobile headers and timeouts
3. **`AppDelegate.swift`** - Added app initialization flow
4. **`Info.plist`** - Added network security and URL scheme configurations
5. **`capacitor.config.json`** - Enhanced with server and plugin configurations

### Backend Configuration

6. **`Backend-API-Config.md`** - Complete backend setup guide

## Quick Start

### 1. Build and Run

```bash
cd ios/App
pod install
open App.xcworkspace
```

Build and run the project in Xcode.

### 2. Test API Integration

1. Open the app
2. Navigate to the API Test section (add this to your main navigation)
3. Run the built-in tests to verify all connections

### 3. Check Logs

Monitor Xcode console for initialization logs:
- ✅ Success indicators
- ❌ Error indicators with details

## API Usage Examples

### Making Authenticated Requests

```swift
MobileAPIService.shared.performRequest<PropertyResponse>(
    endpoint: "/api/properties",
    method: .GET,
    authenticated: true
) { result in
    switch result {
    case .success(let properties):
        // Handle success
    case .failure(let error):
        // Handle error
    }
}
```

### OpenAI Integration

```swift
let messages = [
    ["role": "user", "content": "Help me find an apartment"]
]

MobileAPIService.shared.sendOpenAIRequest(messages: messages) { result in
    switch result {
    case .success(let response):
        let aiResponse = response.choices.first?.message.content
        // Use AI response
    case .failure(let error):
        // Handle error
    }
}
```

### Uploading Files

```swift
MobileAPIService.shared.uploadFile(
    endpoint: "/api/upload",
    fileData: imageData,
    fileName: "property.jpg",
    mimeType: "image/jpeg"
) { result in
    switch result {
    case .success(let response):
        // Handle upload success
    case .failure(let error):
        // Handle error
    }
}
```

## Configuration

### Environment Settings

The app automatically detects the environment:
- **Development**: Debug builds
- **Production**: Release builds

Base URLs are configured in `EnvironmentManager.swift`.

### API Keys

API keys are stored securely in iOS Keychain:
- Supabase anon key (public, included in app)
- OpenAI key (fetched from backend when authenticated)
- Google API key (fetched from backend)
- Other service keys

### Network Configuration

- Automatic retry logic for failed requests
- Network connectivity monitoring
- Proper timeout handling
- Mobile-specific headers

## Backend Requirements

Your backend needs these additions (see `Backend-API-Config.md`):

1. **CORS Headers** - Allow mobile client requests
2. **API Key Endpoint** - `/api/config/keys` (authenticated)
3. **Health Check** - `/health` endpoint
4. **Mobile Headers** - Support for iOS-specific headers

## Security Features

- API keys stored in iOS Keychain (encrypted)
- Request signing with device ID
- Token refresh handling
- Network request validation
- Secure session management

## Troubleshooting

### Common Issues

1. **Network Requests Failing**
   - Check CORS configuration on backend
   - Verify API endpoints are accessible
   - Check device network connectivity

2. **API Keys Not Available**
   - Ensure user is authenticated
   - Check backend `/api/config/keys` endpoint
   - Verify keychain access permissions

3. **App Initialization Failures**
   - Check Xcode console for detailed error logs
   - Run built-in diagnostics
   - Verify backend connectivity

### Debug Tools

Use the built-in test interface:
```swift
let testVC = APITestViewController()
present(testVC, animated: true)
```

### Diagnostics

Get system diagnostics:
```swift
let diagnostics = AppInitializationService.shared.runDiagnostics()
print(diagnostics)
```

## Best Practices

1. **Always check authentication status before API calls**
2. **Handle network errors gracefully with user feedback**
3. **Use the mobile-optimized service for better performance**
4. **Monitor API key availability and refresh when needed**
5. **Implement proper loading states for API calls**

## Next Steps

1. **Integrate with your existing view controllers**
2. **Add the API test interface to your main navigation**
3. **Implement proper error handling in your UI**
4. **Set up backend CORS and API key endpoints**
5. **Test on real devices for network conditions**

## Support

- Check console logs for detailed error information
- Use the diagnostic tools to identify configuration issues
- Verify backend configuration matches the requirements
- Test individual API endpoints using the built-in test interface