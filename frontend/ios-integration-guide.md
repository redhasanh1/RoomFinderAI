# iOS Networking Integration Guide for RoomFinderAI

## 🎯 Overview

This guide provides a complete solution for converting your RoomFinderAI website to work perfectly on iOS using Capacitor. All API calls have been replaced with iOS-compatible alternatives using `@capacitor/http` to ensure reliable networking on iOS devices.

## 📦 Required Dependencies

Add these to your `package.json`:

```json
{
  "dependencies": {
    "@capacitor/core": "^5.0.0",
    "@capacitor/http": "^5.0.0",
    "@capacitor/ios": "^5.0.0"
  }
}
```

Install dependencies:
```bash
npm install @capacitor/core @capacitor/http @capacitor/ios
```

## 🔧 iOS Network Modules Created

### 1. Universal Fetch Replacement (`ios-universal-fetch.js`)
- **Purpose**: Replaces all `fetch()` calls with iOS-compatible networking
- **Usage**: Import and use instead of native `fetch()`
- **Features**:
  - Automatic platform detection (iOS native vs web)
  - Capacitor HTTP for iOS, standard fetch for web
  - Response object compatibility
  - Error handling and logging
  - Axios-like interface for easy migration

### 2. Supabase Client Wrapper (`ios-supabase-client.js`)
- **Purpose**: iOS-compatible Supabase client
- **Usage**: Replace `@supabase/supabase-js` client
- **Features**:
  - Complete Supabase API compatibility
  - Database operations (select, insert, update, delete)
  - Authentication methods
  - Storage operations
  - Real-time subscriptions (polling fallback for iOS)

### 3. Authentication Manager (`ios-auth-manager.js`)
- **Purpose**: Complete authentication system
- **Usage**: Replace all auth-related code
- **Features**:
  - Sign up/sign in/sign out
  - Session management
  - Profile management
  - Password reset
  - User permissions

### 4. Listings API (`ios-listings-api.js`)
- **Purpose**: Property listings management
- **Usage**: Replace all listings-related API calls
- **Features**:
  - CRUD operations for listings
  - Search and filtering
  - Media upload/management
  - Favorites system
  - Location-based search

### 5. Chat System (`ios-chat-system.js`)
- **Purpose**: Real-time messaging system
- **Usage**: Replace chat-related code
- **Features**:
  - Conversations management
  - Message sending/receiving
  - File and image sharing
  - Real-time updates (polling)
  - Message history

### 6. AI API (`ios-ai-api.js`)
- **Purpose**: AI-powered features
- **Usage**: Replace OpenAI API calls
- **Features**:
  - Property search assistance
  - Rental negotiation
  - Chat responses
  - Property analysis
  - Listing enhancement
  - Market insights

### 7. Payment API (`ios-payment-api.js`)
- **Purpose**: Payment processing
- **Usage**: Replace payment-related code
- **Features**:
  - Stripe integration
  - PayPal support
  - Subscription management
  - Payment history
  - Refund processing

## 🚀 Implementation Steps

### Step 1: Copy iOS Modules
Copy all iOS module files to your frontend directory:
- `ios-universal-fetch.js`
- `ios-supabase-client.js`
- `ios-auth-manager.js`
- `ios-listings-api.js`
- `ios-chat-system.js`
- `ios-ai-api.js`
- `ios-payment-api.js`

### Step 2: Update Your Main Files

#### Replace in `auth.js`:
```javascript
// OLD
import { supabase } from './supabase-client.js';

// NEW
import iosAuthManager from './ios-auth-manager.js';
import { createClient } from './ios-supabase-client.js';
```

#### Replace in `listings.js`:
```javascript
// OLD
import { supabase } from './supabase-client.js';

// NEW
import iosListingsAPI from './ios-listings-api.js';
```

#### Replace in `chat-system.js`:
```javascript
// OLD
import { supabase } from './supabase-client.js';

// NEW
import iosChatSystem from './ios-chat-system.js';
```

#### Replace in `ai-chat.js`:
```javascript
// OLD
fetch('https://api.openai.com/v1/chat/completions', {...})

// NEW
import iosAIApi from './ios-ai-api.js';
const response = await iosAIApi.sendChatCompletion(messages);
```

#### Replace in `payment.html`:
```javascript
// OLD
fetch('/api/process-payment', {...})

// NEW
import iosPaymentAPI from './ios-payment-api.js';
const response = await iosPaymentAPI.processPayment(paymentData);
```

### Step 3: Update Configuration Files

#### Update `capacitor.config.json`:
```json
{
  "appId": "com.roomfinderai.app",
  "appName": "RoomFinderAI",
  "webDir": "dist",
  "server": {
    "androidScheme": "https",
    "allowNavigation": [
      "*.supabase.co",
      "api.openai.com",
      "*.stripe.com",
      "*.paypal.com",
      "roomfinder-ai-negotiator-production.up.railway.app"
    ]
  },
  "ios": {
    "contentInset": "automatic",
    "allowsLinkPreview": false,
    "limitsNavigationsToAppBoundDomains": false,
    "preferredContentMode": "mobile"
  }
}
```

#### Update `Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>supabase.co</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.0</string>
        </dict>
        <key>api.openai.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.0</string>
        </dict>
        <key>api.stripe.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.0</string>
        </dict>
        <key>roomfinder-ai-negotiator-production.up.railway.app</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.0</string>
        </dict>
    </dict>
</dict>
```

### Step 4: Global Replacement Strategy

Create a global import file (`ios-globals.js`):
```javascript
// Global iOS compatibility imports
import { fetch } from './ios-universal-fetch.js';
import { createClient } from './ios-supabase-client.js';
import iosAuthManager from './ios-auth-manager.js';
import iosListingsAPI from './ios-listings-api.js';
import iosChatSystem from './ios-chat-system.js';
import iosAIApi from './ios-ai-api.js';
import iosPaymentAPI from './ios-payment-api.js';

// Replace global fetch
if (typeof window !== 'undefined') {
    window.fetch = fetch;
    window.iosAuthManager = iosAuthManager;
    window.iosListingsAPI = iosListingsAPI;
    window.iosChatSystem = iosChatSystem;
    window.iosAIApi = iosAIApi;
    window.iosPaymentAPI = iosPaymentAPI;
}

// Create iOS-compatible supabase client
const supabase = createClient(
    'https://zmxyysauqtfkvntgtjsm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM'
);

// Export for global use
export {
    fetch,
    supabase,
    iosAuthManager,
    iosListingsAPI,
    iosChatSystem,
    iosAIApi,
    iosPaymentAPI
};
```

### Step 5: Update HTML Files

Add to the `<head>` of all HTML files:
```html
<!-- iOS Compatibility -->
<script type="module" src="ios-globals.js"></script>
<script type="module">
    import { fetch } from './ios-universal-fetch.js';
    // Replace global fetch for iOS compatibility
    window.fetch = fetch;
</script>
```

## 🧪 Testing Your iOS Integration

### 1. Test Authentication
```javascript
// Test login
const result = await iosAuthManager.signIn('test@example.com', 'password');
console.log('Login result:', result);

// Test profile
const profile = await iosAuthManager.getUserProfile('test@example.com');
console.log('Profile:', profile);
```

### 2. Test Listings
```javascript
// Test listings fetch
const listings = await iosListingsAPI.fetchListings();
console.log('Listings:', listings);

// Test create listing
const newListing = await iosListingsAPI.createListing({
    title: 'Test Property',
    price: 1000,
    location: 'Test City'
});
console.log('New listing:', newListing);
```

### 3. Test Chat
```javascript
// Test conversations
const conversations = await iosChatSystem.getConversations();
console.log('Conversations:', conversations);

// Test send message
const message = await iosChatSystem.sendMessage(conversationId, 'Hello!');
console.log('Message sent:', message);
```

### 4. Test AI API
```javascript
// Test AI search
const aiSearch = await iosAIApi.searchProperties('2 bedroom apartment near downtown');
console.log('AI search result:', aiSearch);

// Test chat completion
const aiResponse = await iosAIApi.sendChatCompletion([
    { role: 'user', content: 'What is the best neighborhood for students?' }
]);
console.log('AI response:', aiResponse);
```

### 5. Test Payments
```javascript
// Test payment config
const config = await iosPaymentAPI.getPaymentConfig();
console.log('Payment config:', config);

// Test subscription
const subscription = await iosPaymentAPI.getSubscriptionStatus();
console.log('Subscription:', subscription);
```

## 📱 iOS App Build Process

### 1. Build for iOS
```bash
# Build your web app
npm run build

# Copy to iOS
npx cap copy ios

# Open in Xcode
npx cap open ios
```

### 2. Update iOS Project
- Open `App.xcworkspace` in Xcode
- Ensure all iOS modules are included in the build
- Update `Info.plist` with networking permissions
- Test on iOS simulator and device

### 3. Debug iOS Issues
```bash
# Run with live reload
npx cap run ios --livereload

# Debug in Safari
# Enable Safari Developer Menu
# Connect iOS device
# Go to Develop > [Device] > [App]
```

## 🔍 Common Issues and Solutions

### Issue 1: CORS Errors
**Solution**: All API calls now use `@capacitor/http` which bypasses CORS restrictions on iOS.

### Issue 2: Network Timeouts
**Solution**: Timeout settings are configured in each module. Adjust as needed:
```javascript
const response = await fetch(url, {
    timeout: 30000, // 30 seconds
    ...options
});
```

### Issue 3: File Uploads
**Solution**: Use the built-in file upload methods:
```javascript
const result = await iosListingsAPI.uploadListingMedia(listingId, file);
```

### Issue 4: Real-time Updates
**Solution**: iOS uses polling instead of WebSocket for real-time features:
```javascript
const unsubscribe = iosChatSystem.startMessageListener(conversationId, (messages) => {
    // Handle new messages
});
```

## 🎯 Performance Optimization

### 1. Enable Caching
```javascript
// Cache responses for better performance
const response = await fetch(url, {
    cache: 'force-cache',
    ...options
});
```

### 2. Batch API Calls
```javascript
// Batch multiple calls
const [listings, profile, chats] = await Promise.all([
    iosListingsAPI.fetchListings(),
    iosAuthManager.getUserProfile(),
    iosChatSystem.getConversations()
]);
```

### 3. Lazy Loading
```javascript
// Load modules only when needed
const loadChatSystem = async () => {
    if (!window.iosChatSystem) {
        const { default: iosChatSystem } = await import('./ios-chat-system.js');
        window.iosChatSystem = iosChatSystem;
    }
    return window.iosChatSystem;
};
```

## ✅ Success Checklist

- [ ] All iOS modules copied to frontend
- [ ] Global imports configured
- [ ] HTML files updated
- [ ] Capacitor config updated
- [ ] Info.plist updated
- [ ] Authentication working
- [ ] Listings API working
- [ ] Chat system working
- [ ] AI API working
- [ ] Payment API working
- [ ] App builds in Xcode
- [ ] App runs on iOS simulator
- [ ] App runs on iOS device
- [ ] Network requests successful
- [ ] Real-time features working
- [ ] File uploads working

## 🎉 You're Ready!

Your RoomFinderAI website is now fully iOS-compatible! All network requests will work reliably on iOS devices using the Capacitor HTTP plugin, ensuring your users have a seamless experience across all platforms.

For additional support or customization, refer to the individual module documentation or contact the development team.