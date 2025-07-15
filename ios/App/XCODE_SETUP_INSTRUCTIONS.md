# Complete Xcode Setup Instructions for RoomFinderAI iOS App

## 🎯 Overview
This guide will help you open Xcode with all the updated files required to run the iOS application with proper API and data functionality.

## 📋 Prerequisites
- Xcode 14.0 or later
- iOS 14.0 or later
- CocoaPods installed
- Valid Apple Developer account (for device testing)

## 🔧 Setup Steps

### Step 1: Close Any Open Xcode Sessions
```bash
# Force quit Xcode if it's running
killall Xcode
```

### Step 2: Navigate to Project Directory
```bash
cd /Users/arsalanamirali/Downloads/RoomFinderAI/ios/App
```

### Step 3: Install/Update CocoaPods Dependencies
```bash
# Update CocoaPods
pod install --repo-update

# If you encounter issues, try:
pod deintegrate
pod install
```

### Step 4: Open Xcode Project
```bash
# Open the workspace (not the .xcodeproj file)
open App.xcworkspace
```

## 📁 Project Structure Overview

### Core Network Services (Services folder)
- `NetworkDiagnosticService.swift` - Network diagnostics and monitoring
- `NetworkInterceptorService.swift` - Request interception and routing
- `CentralizedAPIService.swift` - Unified API management
- `NetworkDebugService.swift` - Debugging and troubleshooting tools
- `APIKeyManager.swift` - Secure API key management
- `AppInitializationService.swift` - App startup configuration
- `EnvironmentManager.swift` - Environment variable management
- `MobileAPIService.swift` - Mobile-specific API handling
- `SupabaseService.swift` - Supabase database integration
- `KeychainService.swift` - Secure storage service

### Main App Files (App folder)
- `AppDelegate.swift` - App lifecycle management
- `MainTabBarController.swift` - Main navigation controller
- `HomeViewController.swift` - Home screen
- `SearchViewController.swift` - Property search functionality
- `MapViewController.swift` - Map view with property pins
- `PropertyDetailViewController.swift` - Property details
- `AuthViewController.swift` - Authentication screens
- `ProfileViewController.swift` - User profile management
- `APIService.swift` - Legacy API service (being replaced)
- `LocalAPIKeys.swift` - Local API key storage
- `CapacitorBridge.swift` - Capacitor integration
- `QuickAPITest.swift` - API testing utilities
- `APITestViewController.swift` - API testing UI

### Configuration Files
- `Info.plist` - App configuration and permissions
- `capacitor.config.json` - Capacitor configuration
- `Podfile` - CocoaPods dependencies

## 🔑 API Configuration

### Step 1: Configure API Keys
1. Open `LocalAPIKeys.swift`
2. Replace placeholder values with your actual API keys:

```swift
struct LocalAPIKeys {
    // Supabase
    static let supabaseURL = "https://zmxyysauqtfkvntgtjsm.supabase.co"
    static let supabaseAnonKey = "your-actual-supabase-anon-key"
    
    // OpenAI
    static let openAIAPIKey = "your-actual-openai-api-key"
    static let openAIOrganization = "your-openai-organization-id"
    
    // Stripe
    static let stripePublishableKey = "pk_test_your-actual-stripe-key"
    static let stripeSecretKey = "sk_test_your-actual-stripe-secret"
    
    // PayPal
    static let paypalClientID = "your-actual-paypal-client-id"
    static let paypalClientSecret = "your-actual-paypal-secret"
    
    // Backend
    static let backendURL = "https://roomfinder-ai-negotiator-production.up.railway.app"
}
```

### Step 2: Verify Info.plist Configuration
Ensure these permissions are in your `Info.plist`:
- `NSAppTransportSecurity` - Network security settings
- `NSLocationWhenInUseUsageDescription` - Location access
- `NSCameraUsageDescription` - Camera access
- `NSPhotoLibraryUsageDescription` - Photo library access

## 🚀 Building and Testing

### Step 1: Select Target and Device
1. In Xcode, select your target device (iPhone/iPad or Simulator)
2. Choose "App" as the scheme

### Step 2: Build the Project
```bash
# Or use Xcode: Product → Build (⌘+B)
```

### Step 3: Run Network Diagnostics
Add this to your `AppDelegate.swift` in `didFinishLaunchingWithOptions`:

```swift
#if DEBUG
// Run network diagnostics in debug mode
let debugService = NetworkDebugService.shared
let report = debugService.runFullDiagnostics()
print("📊 Network Diagnostic Report:\n\(report)")

// Test all connections
debugService.testAllConnections()
#endif
```

### Step 4: Test API Functionality
1. Run the app
2. Navigate to different screens to test API calls
3. Check Xcode console for network logs
4. Use the debug features to troubleshoot any issues

## 🐛 Troubleshooting

### Common Issues and Solutions

#### Issue 1: Build Errors
```bash
# Clean build folder
Product → Clean Build Folder (⌘+Shift+K)

# Reset simulator
iOS Simulator → Device → Erase All Content and Settings
```

#### Issue 2: CocoaPods Issues
```bash
# Update CocoaPods
sudo gem install cocoapods

# Reinstall pods
pod deintegrate
pod install
```

#### Issue 3: Network Connectivity Issues
1. Check the network diagnostic report in console
2. Verify API keys are correctly configured
3. Test individual API endpoints using `QuickAPITest.swift`
4. Check Info.plist for proper domain allowlist

#### Issue 4: Missing Files
```bash
# Re-run the project setup script
python3 update_xcode_project.py
```

## 🔍 Debug Features

### Network Diagnostics
```swift
// Get full diagnostic report
let report = NetworkDebugService.shared.runFullDiagnostics()

// Test specific URL
NetworkDebugService.shared.quickTest(url: "https://api.example.com")

// Export debug report
if let reportURL = NetworkDebugService.shared.exportDebugReport() {
    // Share or analyze the report
}
```

### API Testing
```swift
// Test centralized API service
CentralizedAPIService.shared.testConnectivity()

// Test specific service
CentralizedAPIService.shared.supabaseRequest(
    endpoint: "properties",
    responseType: [Property].self
) { result in
    switch result {
    case .success(let properties):
        print("✅ Supabase connected: \(properties.count) properties")
    case .failure(let error):
        print("❌ Supabase error: \(error)")
    }
}
```

## 📱 Running on Device

### Step 1: Configure Team and Bundle ID
1. Select your project in Xcode
2. Go to "Signing & Capabilities"
3. Select your development team
4. Verify bundle identifier is unique

### Step 2: Connect Device
1. Connect iPhone/iPad via USB
2. Trust the computer when prompted
3. Select your device in Xcode
4. Build and run

### Step 3: Trust Developer Certificate
1. On device: Settings → General → VPN & Device Management
2. Trust your developer certificate
3. Launch the app

## 🌐 Network Configuration

### Capacitor HTTP Plugin
The app uses `@capacitor-community/http` for native HTTP requests:
- Automatically handles CORS issues
- Bypasses WKWebView limitations
- Provides native networking capabilities

### API Request Flow
1. **JavaScript/TypeScript** → Makes API call
2. **NetworkInterceptorService** → Intercepts and logs request
3. **CentralizedAPIService** → Routes to appropriate service
4. **Capacitor HTTP** → Executes native HTTP request
5. **Response** → Returns through same path

## 📊 Monitoring and Debugging

### Xcode Console
Filter logs by:
- `🔍` - Debug information
- `📊` - Diagnostic reports
- `🌐` - Network requests
- `❌` - Errors
- `✅` - Success messages

### Safari Web Inspector
1. Enable in iOS Settings → Safari → Advanced → Web Inspector
2. Connect device to Mac
3. Open Safari → Develop → [Device] → [App]
4. Monitor network requests in real-time

## 📈 Performance Optimization

### Network Caching
- API responses are cached appropriately
- Image loading is optimized with caching
- Request deduplication prevents redundant calls

### Memory Management
- Proper lifecycle management for services
- Weak references to prevent retain cycles
- Efficient data structures for large datasets

## 🔒 Security Considerations

### API Keys
- Never commit API keys to version control
- Use environment variables for sensitive data
- Implement proper key rotation strategies

### Network Security
- All requests use HTTPS
- Certificate pinning for critical APIs
- Proper error handling for security failures

## 🎯 Next Steps

1. **Configure API Keys** - Add your actual API keys
2. **Test Functionality** - Verify all features work
3. **Customize UI** - Modify interface as needed
4. **Add Features** - Implement additional functionality
5. **Deploy** - Prepare for App Store submission

## 📞 Support

If you encounter issues:
1. Check the diagnostic reports
2. Review network logs
3. Test individual API endpoints
4. Verify configuration settings
5. Consult the troubleshooting guide

The app is now fully configured with comprehensive networking capabilities, proper error handling, and debugging tools to ensure reliable API connectivity on iOS devices.