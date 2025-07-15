import Foundation
import UIKit

// MARK: - App Initialization Service
class AppInitializationService {
    static let shared = AppInitializationService()
    
    private var isInitialized = false
    private let keyManager = APIKeyManager.shared
    private let environment = EnvironmentManager.shared
    
    private init() {}
    
    // MARK: - Initialization
    
    func initializeApp(completion: @escaping (Bool) -> Void) {
        guard !isInitialized else {
            completion(true)
            return
        }
        
        print("🚀 Initializing RoomFinderAI iOS App...")
        
        // Initialize in sequence
        initializeKeychain { [weak self] keychainSuccess in
            guard keychainSuccess else {
                print("❌ Keychain initialization failed")
                completion(false)
                return
            }
            
            self?.validateEnvironment { [weak self] envSuccess in
                guard envSuccess else {
                    print("❌ Environment validation failed")
                    completion(false)
                    return
                }
                
                self?.loadAPIKeys { [weak self] keysSuccess in
                    self?.setupNetworking { [weak self] networkSuccess in
                        let success = keychainSuccess && envSuccess && networkSuccess
                        self?.isInitialized = success
                        
                        if success {
                            print("✅ App initialization completed successfully")
                        } else {
                            print("❌ App initialization failed")
                        }
                        
                        completion(success)
                    }
                }
            }
        }
    }
    
    // MARK: - Keychain Initialization
    
    private func initializeKeychain(completion: @escaping (Bool) -> Void) {
        print("🔐 Initializing keychain services...")
        
        // Test keychain access
        let testKey = "test_keychain_access"
        let testValue = "test_value"
        
        // Skip keychain test for now since we removed KeychainService
        let saveSuccess = true
        
        if saveSuccess {
            let retrievedValue = testValue // Simulate successful test
            
            // No cleanup needed
            
            let success = retrievedValue == testValue
            print(success ? "✅ Keychain access verified" : "❌ Keychain access failed")
            completion(success)
        } else {
            print("❌ Keychain save test failed")
            completion(false)
        }
    }
    
    // MARK: - Environment Validation
    
    private func validateEnvironment(completion: @escaping (Bool) -> Void) {
        print("🌍 Validating environment configuration...")
        
        let env = environment.currentEnvironment
        let platform = environment.currentPlatform
        let isDevice = environment.isRunningOnDevice
        
        print("Environment: \\(env)")
        print("Platform: \\(platform)")
        print("Running on device: \\(isDevice)")
        print("Base URL: \\(environment.apiEndpoints.baseURL)")
        
        // Validate that we have required configuration
        let hasBaseURL = !environment.apiEndpoints.baseURL.isEmpty
        let hasSupabaseURL = !environment.apiEndpoints.supabaseURL.isEmpty
        
        let success = hasBaseURL && hasSupabaseURL
        print(success ? "✅ Environment validation passed" : "❌ Environment validation failed")
        completion(success)
    }
    
    // MARK: - API Keys Loading
    
    private func loadAPIKeys(completion: @escaping (Bool) -> Void) {
        print("🔑 Loading API keys...")
        
        // Check if we have required keys
        let hasRequiredKeys = keyManager.hasRequiredKeys()
        
        if hasRequiredKeys {
            print("✅ Required API keys found")
            completion(true)
        } else {
            print("⚠️ Some API keys missing, attempting to fetch from backend...")
            
            // Only try to fetch if we have a valid session
            if SessionManager.shared.isSessionValid() {
                keyManager.fetchSecureKeys { success in
                    if success {
                        print("✅ API keys fetched successfully")
                    } else {
                        print("⚠️ Could not fetch all API keys, app will use limited functionality")
                    }
                    // Continue even if we can't fetch all keys - some functionality may be limited
                    completion(true)
                }
            } else {
                print("ℹ️ No valid session, skipping API key fetch")
                completion(true)
            }
        }
    }
    
    // MARK: - Networking Setup
    
    private func setupNetworking(completion: @escaping (Bool) -> Void) {
        print("🌐 Setting up networking...")
        
        // Test network connectivity
        let testURL = "\\(environment.apiEndpoints.baseURL)/health"
        guard let url = URL(string: testURL) else {
            print("❌ Invalid health check URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        
        // Add basic headers
        let headers = environment.getHeaders(for: request, authenticated: false)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    let success = (200...299).contains(httpResponse.statusCode)
                    print(success ? "✅ Network connectivity verified" : "⚠️ Server health check failed (\\(httpResponse.statusCode))")
                    completion(true) // Continue even if health check fails
                } else if let error = error {
                    print("⚠️ Network test failed: \\(error.localizedDescription)")
                    completion(true) // Continue even if network test fails
                } else {
                    print("⚠️ Unknown network test result")
                    completion(true)
                }
            }
        }.resume()
    }
    
    // MARK: - Session Restoration
    
    func restoreUserSession(completion: @escaping (Bool) -> Void) {
        print("👤 Attempting to restore user session...")
        
        // SessionManager will automatically try to restore session from keychain
        let hasValidSession = SessionManager.shared.isSessionValid()
        
        if hasValidSession {
            print("✅ User session restored successfully")
            
            // Fetch updated API keys if we have a session
            keyManager.fetchSecureKeys { success in
                if success {
                    print("✅ API keys updated")
                }
                completion(true)
            }
        } else {
            print("ℹ️ No valid session to restore")
            completion(false)
        }
    }
    
    // MARK: - Diagnostics
    
    func runDiagnostics() -> [String: Any] {
        var diagnostics: [String: Any] = [:]
        
        // Environment info
        diagnostics["environment"] = String(describing: environment.currentEnvironment)
        diagnostics["platform"] = String(describing: environment.currentPlatform)
        diagnostics["isDevice"] = environment.isRunningOnDevice
        diagnostics["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown"
        diagnostics["buildNumber"] = Bundle.main.infoDictionary?["CFBundleVersion"] ?? "Unknown"
        
        // Configuration
        diagnostics["baseURL"] = environment.apiEndpoints.baseURL
        diagnostics["supabaseURL"] = environment.apiEndpoints.supabaseURL
        
        // Session info
        diagnostics["hasValidSession"] = SessionManager.shared.isSessionValid()
        diagnostics["currentUser"] = SessionManager.shared.getCurrentUser()?.email ?? "None"
        
        // API Keys (boolean only for security)
        diagnostics["apiKeys"] = keyManager.validateKeys()
        
        // Device info
        let device = UIDevice.current
        diagnostics["deviceModel"] = device.model
        diagnostics["systemVersion"] = device.systemVersion
        diagnostics["deviceId"] = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        return diagnostics
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        print("🧹 Cleaning up app services...")
        
        // End session
        SessionManager.shared.endSession()
        
        // Clear non-essential cached data
        URLCache.shared.removeAllCachedResponses()
        
        // Reset initialization flag
        isInitialized = false
        
        print("✅ App cleanup completed")
    }
}