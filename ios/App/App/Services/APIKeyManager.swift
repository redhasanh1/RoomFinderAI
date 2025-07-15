import Foundation

// MARK: - API Key Manager
class APIKeyManager {
    static let shared = APIKeyManager()
    
    private let keychain = KeychainService.shared
    
    // Key identifiers
    private struct KeyIdentifiers {
        static let openAIKey = "openai_api_key"
        static let supabaseAnonKey = "supabase_anon_key"
        static let supabaseServiceKey = "supabase_service_key"
        static let googleAPIKey = "google_api_key"
        static let stripePublishableKey = "stripe_publishable_key"
        static let sentryDSN = "sentry_dsn"
    }
    
    private init() {
        // Initialize with default public keys if needed
        initializeDefaultKeys()
    }
    
    // MARK: - Public Keys (Safe to store in app)
    private func initializeDefaultKeys() {
        // These are public keys that are safe to include in the app
        // They should have restricted permissions on the backend
        
        // Supabase anon key (public, restricted permissions)
        if getSupabaseAnonKey() == nil {
            _ = setSupabaseAnonKey("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM")
        }
    }
    
    // MARK: - API Key Getters
    
    func getOpenAIKey() -> String? {
        return keychain.load(String.self, forKey: KeyIdentifiers.openAIKey)
    }
    
    func getSupabaseAnonKey() -> String? {
        return keychain.load(String.self, forKey: KeyIdentifiers.supabaseAnonKey)
    }
    
    func getSupabaseServiceKey() -> String? {
        return keychain.load(String.self, forKey: KeyIdentifiers.supabaseServiceKey)
    }
    
    func getGoogleAPIKey() -> String? {
        return keychain.load(String.self, forKey: KeyIdentifiers.googleAPIKey)
    }
    
    func getStripePublishableKey() -> String? {
        return keychain.load(String.self, forKey: KeyIdentifiers.stripePublishableKey)
    }
    
    func getSentryDSN() -> String? {
        return keychain.load(String.self, forKey: KeyIdentifiers.sentryDSN)
    }
    
    // MARK: - API Key Setters (Should only be used during secure configuration)
    
    @discardableResult
    func setOpenAIKey(_ key: String) -> Bool {
        return keychain.save(key, forKey: KeyIdentifiers.openAIKey)
    }
    
    @discardableResult
    func setSupabaseAnonKey(_ key: String) -> Bool {
        return keychain.save(key, forKey: KeyIdentifiers.supabaseAnonKey)
    }
    
    @discardableResult
    func setSupabaseServiceKey(_ key: String) -> Bool {
        return keychain.save(key, forKey: KeyIdentifiers.supabaseServiceKey)
    }
    
    @discardableResult
    func setGoogleAPIKey(_ key: String) -> Bool {
        return keychain.save(key, forKey: KeyIdentifiers.googleAPIKey)
    }
    
    @discardableResult
    func setStripePublishableKey(_ key: String) -> Bool {
        return keychain.save(key, forKey: KeyIdentifiers.stripePublishableKey)
    }
    
    @discardableResult
    func setSentryDSN(_ dsn: String) -> Bool {
        return keychain.save(dsn, forKey: KeyIdentifiers.sentryDSN)
    }
    
    // MARK: - Secure Key Exchange
    
    /// Fetch API keys from backend (requires authentication)
    func fetchSecureKeys(completion: @escaping (Bool) -> Void) {
        guard SessionManager.shared.isSessionValid() else {
            print("❌ Cannot fetch secure keys without valid session")
            completion(false)
            return
        }
        
        let urlString = "\(EnvironmentManager.shared.apiEndpoints.baseURL)/api/config/keys"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add authentication headers
        let headers = EnvironmentManager.shared.getHeaders(for: request, authenticated: true)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            do {
                let keys = try JSONDecoder().decode(SecureKeys.self, from: data)
                
                // Store keys securely
                var success = true
                
                if let openAIKey = keys.openAIKey {
                    success = success && self.setOpenAIKey(openAIKey)
                }
                
                if let googleKey = keys.googleAPIKey {
                    success = success && self.setGoogleAPIKey(googleKey)
                }
                
                if let stripeKey = keys.stripePublishableKey {
                    success = success && self.setStripePublishableKey(stripeKey)
                }
                
                DispatchQueue.main.async {
                    completion(success)
                }
            } catch {
                print("❌ Failed to decode secure keys: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Key Validation
    
    func hasRequiredKeys() -> Bool {
        // Check if we have the minimum required keys
        return getSupabaseAnonKey() != nil
    }
    
    func validateKeys() -> [String: Bool] {
        return [
            "OpenAI": getOpenAIKey() != nil,
            "Supabase Anon": getSupabaseAnonKey() != nil,
            "Supabase Service": getSupabaseServiceKey() != nil,
            "Google": getGoogleAPIKey() != nil,
            "Stripe": getStripePublishableKey() != nil,
            "Sentry": getSentryDSN() != nil
        ]
    }
    
    // MARK: - Cleanup
    
    func clearAllKeys() {
        _ = keychain.deleteItem(forKey: KeyIdentifiers.openAIKey)
        _ = keychain.deleteItem(forKey: KeyIdentifiers.supabaseServiceKey)
        _ = keychain.deleteItem(forKey: KeyIdentifiers.googleAPIKey)
        _ = keychain.deleteItem(forKey: KeyIdentifiers.stripePublishableKey)
        _ = keychain.deleteItem(forKey: KeyIdentifiers.sentryDSN)
        // Keep anon key as it's public
    }
}

// MARK: - Secure Keys Response
private struct SecureKeys: Codable {
    let openAIKey: String?
    let googleAPIKey: String?
    let stripePublishableKey: String?
    let sentryDSN: String?
    
    enum CodingKeys: String, CodingKey {
        case openAIKey = "openai_key"
        case googleAPIKey = "google_api_key"
        case stripePublishableKey = "stripe_publishable_key"
        case sentryDSN = "sentry_dsn"
    }
}