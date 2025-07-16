import Foundation
import Capacitor
import WebKit

/**
 * WebBridge - Communicates between native iOS UI and your existing web functions
 * This preserves all your working functionality while providing native UI
 */
@objc class WebBridge: NSObject {
    static let shared = WebBridge()
    private var webView: WKWebView?
    private var bridge: CAPBridgeProtocol?
    
    private override init() {
        super.init()
    }
    
    func configure(with bridge: CAPBridgeProtocol) {
        self.bridge = bridge
        self.webView = bridge.webView
    }
    
    // MARK: - Call Web Functions
    
    /**
     * Execute JavaScript function and get result
     */
    func callWebFunction(_ function: String, with parameters: [String: Any]? = nil) async throws -> Any? {
        guard let webView = webView else {
            throw WebBridgeError.webViewNotConfigured
        }
        
        let jsonParams = parameters != nil ? try JSONSerialization.data(withJSONObject: parameters!) : nil
        let paramsString = jsonParams != nil ? String(data: jsonParams!, encoding: .utf8) ?? "{}" : "{}"
        
        let js = """
        (async () => {
            try {
                const result = await \(function)(\(paramsString));
                return JSON.stringify({ success: true, data: result });
            } catch (error) {
                return JSON.stringify({ success: false, error: error.message });
            }
        })();
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let resultString = result as? String,
                          let data = resultString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if json["success"] as? Bool == true {
                        continuation.resume(returning: json["data"])
                    } else {
                        continuation.resume(throwing: WebBridgeError.webFunctionError(json["error"] as? String ?? "Unknown error"))
                    }
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    // MARK: - Property Listings Functions
    
    func fetchListings(filters: [String: Any]? = nil) async throws -> [[String: Any]] {
        let result = try await callWebFunction("iosListingsAPI.fetchListings", with: filters)
        return (result as? [String: Any])?["data"] as? [[String: Any]] ?? []
    }
    
    func searchListings(query: String, filters: [String: Any]? = nil) async throws -> [[String: Any]] {
        var params = filters ?? [:]
        params["searchQuery"] = query
        let result = try await callWebFunction("iosListingsAPI.searchListings", with: ["searchQuery": query, "filters": filters ?? [:]])
        return (result as? [String: Any])?["data"] as? [[String: Any]] ?? []
    }
    
    func getListing(id: String) async throws -> [String: Any]? {
        let result = try await callWebFunction("iosListingsAPI.getListing", with: ["id": id])
        return (result as? [String: Any])?["data"] as? [String: Any]
    }
    
    // MARK: - Authentication Functions
    
    func signIn(email: String, password: String) async throws -> [String: Any]? {
        let result = try await callWebFunction("iosAuthManager.signIn", with: ["email": email, "password": password])
        return result as? [String: Any]
    }
    
    func signUp(email: String, password: String, userData: [String: Any]? = nil) async throws -> [String: Any]? {
        let result = try await callWebFunction("iosAuthManager.signUp", with: ["email": email, "password": password, "userData": userData ?? [:]])
        return result as? [String: Any]
    }
    
    func signOut() async throws {
        _ = try await callWebFunction("iosAuthManager.signOut")
    }
    
    func getCurrentUser() async throws -> [String: Any]? {
        let result = try await callWebFunction("iosAuthManager.getCurrentUser")
        return result as? [String: Any]
    }
    
    // MARK: - Chat Functions
    
    func getConversations() async throws -> [[String: Any]] {
        let result = try await callWebFunction("iosChatSystem.getConversations")
        return (result as? [String: Any])?["data"] as? [[String: Any]] ?? []
    }
    
    func sendMessage(conversationId: String, content: String) async throws -> [String: Any]? {
        let result = try await callWebFunction("iosChatSystem.sendMessage", with: ["conversationId": conversationId, "content": content])
        return (result as? [String: Any])?["data"] as? [String: Any]
    }
    
    // MARK: - AI Functions
    
    func searchPropertiesWithAI(query: String) async throws -> [String: Any]? {
        let result = try await callWebFunction("iosAIApi.searchProperties", with: ["query": query])
        return (result as? [String: Any])?["data"] as? [String: Any]
    }
    
    func getAINegotiationAdvice(listingId: String, message: String) async throws -> [String: Any]? {
        let result = try await callWebFunction("iosAIApi.negotiateRental", with: ["listingId": listingId, "userMessage": message])
        return (result as? [String: Any])?["data"] as? [String: Any]
    }
    
    // MARK: - Payment Functions
    
    func getSubscriptionStatus() async throws -> [String: Any]? {
        let result = try await callWebFunction("iosPaymentAPI.getSubscriptionStatus")
        return (result as? [String: Any])?["data"] as? [String: Any]
    }
    
    func processPayment(paymentData: [String: Any]) async throws -> [String: Any]? {
        let result = try await callWebFunction("iosPaymentAPI.processPayment", with: paymentData)
        return (result as? [String: Any])?["data"] as? [String: Any]
    }
}

// MARK: - Error Types

enum WebBridgeError: LocalizedError {
    case webViewNotConfigured
    case webFunctionError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .webViewNotConfigured:
            return "WebView is not configured"
        case .webFunctionError(let message):
            return "Web function error: \(message)"
        case .invalidResponse:
            return "Invalid response from web function"
        }
    }
}