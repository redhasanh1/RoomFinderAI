import Foundation
import UIKit

// MARK: - Environment Manager
class EnvironmentManager {
    static let shared = EnvironmentManager()
    
    private init() {}
    
    // MARK: - Environment Detection
    enum Environment {
        case development
        case staging
        case production
    }
    
    enum Platform {
        case web
        case ios
        case android
    }
    
    var currentEnvironment: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    var currentPlatform: Platform {
        return .ios
    }
    
    var isRunningOnDevice: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
    
    // MARK: - API Configuration
    struct APIEndpoints {
        let baseURL: String
        let supabaseURL: String
        let openAIBaseURL: String
        
        // Add timeout configurations
        let defaultTimeout: TimeInterval
        let uploadTimeout: TimeInterval
    }
    
    var apiEndpoints: APIEndpoints {
        switch currentEnvironment {
        case .development:
            return APIEndpoints(
                baseURL: "https://roomfinder-ai-negotiator-production.up.railway.app",
                supabaseURL: "https://zmxyysauqtfkvntgtjsm.supabase.co",
                openAIBaseURL: "https://api.openai.com/v1",
                defaultTimeout: 30,
                uploadTimeout: 120
            )
        case .staging:
            return APIEndpoints(
                baseURL: "https://roomfinder-ai-negotiator-staging.up.railway.app",
                supabaseURL: "https://zmxyysauqtfkvntgtjsm.supabase.co",
                openAIBaseURL: "https://api.openai.com/v1",
                defaultTimeout: 30,
                uploadTimeout: 120
            )
        case .production:
            return APIEndpoints(
                baseURL: "https://roomfinder-ai-negotiator-production.up.railway.app",
                supabaseURL: "https://zmxyysauqtfkvntgtjsm.supabase.co",
                openAIBaseURL: "https://api.openai.com/v1",
                defaultTimeout: 30,
                uploadTimeout: 120
            )
        }
    }
    
    // MARK: - Headers Configuration
    func getHeaders(for request: URLRequest, authenticated: Bool = false) -> [String: String] {
        var headers: [String: String] = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-Platform": "iOS",
            "X-App-Version": getAppVersion(),
            "X-Device-Id": getDeviceId(),
            "X-OS-Version": getOSVersion()
        ]
        
        // Add user agent for better tracking
        headers["User-Agent"] = getUserAgent()
        
        // Add authentication if needed
        if authenticated, let token = SessionManager.shared.getAccessToken() {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        // Add Capacitor-specific headers
        headers["X-Capacitor-Platform"] = "ios"
        
        return headers
    }
    
    // MARK: - Device Information
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version).\(build)"
    }
    
    private func getDeviceId() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
    
    private func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    private func getUserAgent() -> String {
        let device = UIDevice.current
        let osVersion = device.systemVersion
        let model = device.model
        let appVersion = getAppVersion()
        
        return "RoomFinderAI/\(appVersion) (iOS \(osVersion); \(model))"
    }
    
    // MARK: - CORS Configuration
    func configureCORSHeaders(for request: inout URLRequest) {
        // These headers help with CORS in WKWebView
        request.setValue(apiEndpoints.baseURL, forHTTPHeaderField: "Origin")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
    }
    
    // MARK: - Security Headers
    func addSecurityHeaders(to request: inout URLRequest) {
        // Add security headers for API requests
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        
        // Add request ID for tracking
        let requestId = UUID().uuidString
        request.setValue(requestId, forHTTPHeaderField: "X-Request-Id")
    }
}