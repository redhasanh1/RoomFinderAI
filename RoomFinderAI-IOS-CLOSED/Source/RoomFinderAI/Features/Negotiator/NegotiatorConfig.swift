import Foundation

// MARK: - AI Negotiator Configuration
enum NegotiatorConfig {
    // OpenAI Configuration - Direct from Secrets
    static let openAIKey: String = Secrets.openAIKey
    static let openAIOrg: String? = Secrets.openAIOrgID
    static let openAIModel: String = Secrets.openAIModel
    static let openAIBaseURL: String = "https://api.openai.com/v1"
    
    // OpenAI Request Settings
    static let maxTokens: Int = 1000
    static let temperature: Float = 0.7
    static let requestTimeout: TimeInterval = 30.0
    
    // Market Data Settings
    static let marketDataCacheTimeout: TimeInterval = 300 // 5 minutes
    static let maxListingsForStats: Int = 50
    static let minListingsForValidStats: Int = 3
    
    // Message Settings
    static let maxMessageLength: Int = 500
    static let typingIndicatorDelay: TimeInterval = 1.0
    static let autoResponseDelay: TimeInterval = 2.0
    
    // Retry Settings
    static let maxRetries: Int = 3
    static let baseRetryDelay: TimeInterval = 1.0
    static let maxRetryDelay: TimeInterval = 10.0
    
    // AI User Settings
    static let aiUserEmail = "ai-negotiator@roomfinder.com" // Match web version
    static let aiUserName = "AI Negotiation Assistant"
    
    // Validation
    static func validateConfiguration() -> Bool {
        guard !openAIKey.isEmpty && openAIKey.hasPrefix("sk-") else {
            print("ERROR: OpenAI API Key not configured")
            return false
        }
        return true
    }
    
    // Debug helper to verify credentials are loaded
    static func debugCredentials() {
        print("🚀 OpenAI Configuration:")
        print("  - API Key: \(openAIKey.prefix(20))... (length: \(openAIKey.count))")
        print("  - Org ID: \(openAIOrg ?? "nil")")
        print("  - Model: \(openAIModel)")
    }
}

// MARK: - OpenAI Request Configuration
struct OpenAIRequestConfig {
    let apiKey: String
    let organizationID: String?
    let model: String
    let maxTokens: Int
    let temperature: Float
    let timeout: TimeInterval
    
    static let `default` = OpenAIRequestConfig(
        apiKey: NegotiatorConfig.openAIKey,
        organizationID: NegotiatorConfig.openAIOrg,
        model: NegotiatorConfig.openAIModel,
        maxTokens: NegotiatorConfig.maxTokens,
        temperature: NegotiatorConfig.temperature,
        timeout: NegotiatorConfig.requestTimeout
    )
}

// MARK: - Environment Helper
extension NegotiatorConfig {
    // Helper to read from Info.plist or environment
    private static func getValue(for key: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[key] {
            return value
        }
        
        if let value = Bundle.main.infoDictionary?[key] as? String {
            return value
        }
        
        return nil
    }
    
    // Production-ready config loading
    static func loadProductionConfig() -> OpenAIRequestConfig? {
        guard let apiKey = getValue(for: "OPENAI_API_KEY"),
              !apiKey.isEmpty else {
            print("ERROR: OPENAI_API_KEY not found in environment or Info.plist")
            return nil
        }
        
        let organizationID = getValue(for: "OPENAI_ORG_ID")
        let model = getValue(for: "OPENAI_MODEL") ?? "gpt-4o-mini"
        
        return OpenAIRequestConfig(
            apiKey: apiKey,
            organizationID: organizationID,
            model: model,
            maxTokens: NegotiatorConfig.maxTokens,
            temperature: NegotiatorConfig.temperature,
            timeout: NegotiatorConfig.requestTimeout
        )
    }
}