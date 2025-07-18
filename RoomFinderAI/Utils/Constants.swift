import Foundation

struct Constants {
    static let supabaseURL = "https://zmxyysauqtfkvntgtjsm.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM"
    
    // TODO: Add your OpenAI API key here
    // Get it from: https://platform.openai.com/api-keys
    static let openAIAPIKey = "sk-proj-YOUR_OPENAI_API_KEY_HERE"
    
    // TODO: Add your Stripe publishable key here
    // Get it from: https://dashboard.stripe.com/apikeys
    static let stripePublishableKey = "pk_test_YOUR_STRIPE_PUBLISHABLE_KEY_HERE"
    
    // TODO: Add your Stripe secret key for server-side operations
    static let stripeSecretKey = "sk_test_YOUR_STRIPE_SECRET_KEY_HERE"
    
    struct API {
        static let baseURL = "https://your-backend-url.com/api"
        static let timeoutInterval: TimeInterval = 30.0
    }
    
    struct KeychainKeys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let userSession = "user_session"
    }
    
    struct UserDefaults {
        static let hasSeenOnboarding = "has_seen_onboarding"
        static let userPreferences = "user_preferences"
        static let darkModeEnabled = "dark_mode_enabled"
    }
    
    struct Notifications {
        static let newMessage = "new_message"
        static let listingUpdate = "listing_update"
        static let authStateChanged = "auth_state_changed"
    }
}