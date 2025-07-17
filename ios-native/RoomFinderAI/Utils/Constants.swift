import Foundation

struct Constants {
    static let supabaseURL = "YOUR_SUPABASE_URL"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
    
    static let openAIAPIKey = "YOUR_OPENAI_API_KEY"
    static let stripePublishableKey = "YOUR_STRIPE_PUBLISHABLE_KEY"
    
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