import Foundation

// MARK: - Local API Keys Configuration
// ⚠️ IMPORTANT: Add your actual API keys here for iOS app functionality

struct LocalAPIKeys {
    
    // MARK: - Required API Keys
    // Replace empty strings with your actual API keys
    
    static let configuration: [String: String] = [
        
        // Backend Configuration
        "BACKEND_URL": "https://roomfinder-ai-negotiator-production.up.railway.app",
        
        // Supabase Configuration (Public keys - safe to include)
        "SUPABASE_URL": "https://zmxyysauqtfkvntgtjsm.supabase.co",
        "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM",
        
        // OpenAI Configuration
        // 🔑 Add your OpenAI API key here:
        "OPENAI_API_KEY": "sk-placeholder-add-your-key-here", // Replace with your actual OpenAI key
        
        // Google Services
        // 🔑 Add your Google API key here:
        "GOOGLE_API_KEY": "placeholder-add-your-google-key", // Replace with your actual Google Maps key
        
        // Stripe Configuration (Publishable key only - safe to include)
        // 🔑 Add your Stripe publishable key here:
        "STRIPE_PUBLISHABLE_KEY": "pk_test_placeholder-add-your-stripe-key", // Replace with your actual Stripe key
        
        // Other Services
        "SENTRY_DSN": "", // Optional: for error tracking
        "ANALYTICS_KEY": "", // Optional: for app analytics
        
        // Feature Flags
        "ENABLE_OPENAI": "true",
        "ENABLE_PUSH_NOTIFICATIONS": "false",
        "ENABLE_ANALYTICS": "false"
    ]
    
    // MARK: - Helper Methods
    
    static func getKey(_ keyName: String) -> String? {
        return configuration[keyName]
    }
    
    static func hasKey(_ keyName: String) -> Bool {
        guard let value = configuration[keyName] else { return false }
        return !value.isEmpty
    }
    
    static func getRequiredKeys() -> [String] {
        return [
            "BACKEND_URL",
            "SUPABASE_URL", 
            "SUPABASE_ANON_KEY"
        ]
    }
    
    static func getOptionalKeys() -> [String] {
        return [
            "OPENAI_API_KEY",
            "GOOGLE_API_KEY",
            "STRIPE_PUBLISHABLE_KEY",
            "SENTRY_DSN"
        ]
    }
    
    static func validateConfiguration() -> [String: Bool] {
        var validation: [String: Bool] = [:]
        
        // Check required keys
        for key in getRequiredKeys() {
            validation[key] = hasKey(key)
        }
        
        // Check optional keys
        for key in getOptionalKeys() {
            validation[key] = hasKey(key)
        }
        
        return validation
    }
    
    static func getConfigurationSummary() -> String {
        let validation = validateConfiguration()
        var summary = "📋 API Configuration Status:\n\n"
        
        summary += "✅ Required Keys:\n"
        for key in getRequiredKeys() {
            let status = validation[key] == true ? "✅" : "❌"
            summary += "  \(status) \(key)\n"
        }
        
        summary += "\n🔧 Optional Keys:\n"
        for key in getOptionalKeys() {
            let status = validation[key] == true ? "✅" : "⚪"
            summary += "  \(status) \(key)\n"
        }
        
        return summary
    }
}

// MARK: - Easy Configuration Access
extension LocalAPIKeys {
    
    // Quick access properties
    static var backendURL: String {
        return getKey("BACKEND_URL") ?? ""
    }
    
    static var supabaseURL: String {
        return getKey("SUPABASE_URL") ?? ""
    }
    
    static var supabaseAnonKey: String {
        return getKey("SUPABASE_ANON_KEY") ?? ""
    }
    
    static var openAIKey: String? {
        let key = getKey("OPENAI_API_KEY")
        return key?.isEmpty == false ? key : nil
    }
    
    static var googleAPIKey: String? {
        let key = getKey("GOOGLE_API_KEY")
        return key?.isEmpty == false ? key : nil
    }
    
    static var stripePublishableKey: String? {
        let key = getKey("STRIPE_PUBLISHABLE_KEY")
        return key?.isEmpty == false ? key : nil
    }
    
    // Feature flags
    static var isOpenAIEnabled: Bool {
        return getKey("ENABLE_OPENAI") == "true" && openAIKey != nil
    }
    
    static var isPushNotificationsEnabled: Bool {
        return getKey("ENABLE_PUSH_NOTIFICATIONS") == "true"
    }
    
    static var isAnalyticsEnabled: Bool {
        return getKey("ENABLE_ANALYTICS") == "true"
    }
}

// MARK: - Development Helper
#if DEBUG
extension LocalAPIKeys {
    
    static func printConfiguration() {
        print("🔧 LocalAPIKeys Configuration:")
        print("================================")
        
        for (key, value) in configuration {
            if key.contains("KEY") || key.contains("SECRET") {
                // Hide sensitive values in logs
                let maskedValue = value.isEmpty ? "❌ MISSING" : "✅ SET (\(value.prefix(8))...)"
                print("\(key): \(maskedValue)")
            } else {
                print("\(key): \(value)")
            }
        }
        
        print("================================")
        print(getConfigurationSummary())
    }
    
    static func testAllKeys() {
        print("🧪 Testing API Key Configuration:")
        print("=================================")
        
        let validation = validateConfiguration()
        var allValid = true
        
        for (key, isValid) in validation {
            let status = isValid ? "✅ VALID" : "❌ MISSING"
            print("\(key): \(status)")
            
            if getRequiredKeys().contains(key) && !isValid {
                allValid = false
            }
        }
        
        print("=================================")
        print(allValid ? "✅ All required keys are configured" : "❌ Some required keys are missing")
    }
}
#endif