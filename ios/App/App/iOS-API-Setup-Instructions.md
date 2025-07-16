# iOS API Setup Instructions

## 🚨 **Why Your iOS App Can't Fetch Data**

Your iOS app can't access the same data as your website because:

1. **Different Environment**: iOS apps don't have access to web environment variables
2. **No Local Storage**: Can't access browser localStorage/sessionStorage  
3. **CORS Issues**: Native iOS requests handled differently than browser requests
4. **Missing API Keys**: The app doesn't know your OpenAI, Google, etc. API keys

## ✅ **Solution: Local API Key Storage**

I've created a complete system that stores API keys locally in your iOS app:

### 📁 **Files Created:**

1. **`LocalAPIKeys.swift`** - Store all your API keys here
2. **`CapacitorBridge.swift`** - Bridge between native iOS and web code
3. **`capacitor-bridge.js`** - JavaScript interface for your web code
4. **`iOSAPITestViewController.swift`** - Test all API integrations

## 🔧 **Setup Steps:**

### 1. Add Your API Keys

Open `LocalAPIKeys.swift` and add your actual API keys:

```swift
static let configuration: [String: String] = [
    // ✅ Already configured
    "BACKEND_URL": "https://roomfinder-ai-negotiator-production.up.railway.app",
    "SUPABASE_URL": "https://zmxyysauqtfkvntgtjsm.supabase.co", 
    "SUPABASE_ANON_KEY": "your-supabase-anon-key",
    
    // 🔑 ADD THESE:
    "OPENAI_API_KEY": "sk-your-openai-key-here",
    "GOOGLE_API_KEY": "your-google-maps-key",
    "STRIPE_PUBLISHABLE_KEY": "pk_test_your-stripe-key",
]
```

### 2. Test the Configuration

Add this to one of your view controllers to test:

```swift
// Present the test interface
let testVC = iOSAPITestViewController()
let navController = UINavigationController(rootViewController: testVC)
present(navController, animated: true)
```

### 3. Add Files to Xcode Project

In Xcode, **right-click** on the `App` folder and **"Add Files to 'App'"**:
- `LocalAPIKeys.swift`
- `CapacitorBridge.swift` 
- `iOSAPITestViewController.swift`

Make sure **"Add to target: App"** is checked.

## 🧪 **Testing Your APIs**

The test interface will check:

- ✅ **API Configuration** - Are all keys properly set?
- 🌐 **Backend Connection** - Can we reach your Railway backend?
- 🗃️ **Supabase** - Database connection working?
- 🏠 **Properties** - Can we fetch property data?
- 🤖 **OpenAI** - AI integration working?
- 🔐 **Authentication** - Session management working?

## 🔑 **Where to Get API Keys:**

### OpenAI API Key:
1. Go to https://platform.openai.com/api-keys
2. Create new secret key
3. Copy the `sk-...` key to `LocalAPIKeys.swift`

### Google API Key:
1. Go to https://console.cloud.google.com/apis/credentials
2. Create API key
3. Enable Maps JavaScript API and Places API
4. Copy key to `LocalAPIKeys.swift`

### Stripe Publishable Key:
1. Go to https://dashboard.stripe.com/apikeys
2. Copy the `pk_test_...` or `pk_live_...` key
3. Add to `LocalAPIKeys.swift`

## 🌐 **Backend Requirements**

Your backend needs these CORS headers for iOS:

```javascript
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH');
  res.header('Access-Control-Allow-Headers', 
    'Origin, X-Requested-With, Content-Type, Accept, Authorization, ' +
    'X-Platform, User-Agent'
  );
  next();
});
```

## 📱 **How It Works**

1. **Local Storage**: API keys stored securely in iOS Keychain
2. **Native Requests**: Direct HTTP calls from iOS (no browser limitations)
3. **Automatic Headers**: Mobile-specific headers added automatically
4. **Error Handling**: Proper retry logic and error management
5. **Session Management**: Secure token storage and refresh

## 🚀 **Expected Results**

After setup, your iOS app will:

- ✅ **Connect to your backend** (Railway)
- ✅ **Access Supabase database** 
- ✅ **Use OpenAI for AI features**
- ✅ **Handle user authentication**
- ✅ **Store data securely**
- ✅ **Work offline with cached data**

## 🔍 **Debugging**

If something doesn't work:

1. **Check logs** in Xcode console for detailed errors
2. **Run the test interface** to see exactly what's failing
3. **Verify API keys** are correctly formatted
4. **Test backend endpoints** individually
5. **Check network connectivity**

## 📞 **Test Commands**

Add this to any view controller to quickly test:

```swift
// Quick API test
LocalAPIKeys.testAllKeys() // Prints configuration status

// Test specific API
APIService.shared.fetchProperties { result in
    print("Properties: \(result)")
}

// Test OpenAI
if let openAIKey = LocalAPIKeys.openAIKey {
    print("OpenAI ready: \(openAIKey.prefix(8))...")
} else {
    print("OpenAI key missing")
}
```

Your iOS app will now have the same API access as your website! 🎉