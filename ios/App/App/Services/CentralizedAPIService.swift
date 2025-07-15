import Foundation
import WebKit

// MARK: - Centralized API Service
class CentralizedAPIService: NSObject {
    static let shared = CentralizedAPIService()
    
    private let interceptorService = NetworkInterceptorService.shared
    private let diagnosticService = NetworkDiagnosticService.shared
    private let sessionManager = SessionManager.shared
    
    private var isInitialized = false
    private var webView: WKWebView?
    
    override init() {
        super.init()
        setupService()
    }
    
    // MARK: - Service Setup
    private func setupService() {
        guard !isInitialized else { return }
        
        print("🚀 Initializing Centralized API Service")
        
        // Setup network monitoring
        setupNetworkMonitoring()
        
        // Setup WebView for JavaScript bridge
        setupWebViewBridge()
        
        // Run initial diagnostics
        runInitialDiagnostics()
        
        isInitialized = true
        print("✅ Centralized API Service initialized successfully")
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        // Network monitoring is handled by NetworkDiagnosticService
        print("📡 Network monitoring setup complete")
    }
    
    // MARK: - WebView Bridge Setup
    private func setupWebViewBridge() {
        let config = WKWebViewConfiguration()
        
        // Add message handler for network interception
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "networkInterceptor")
        
        // Inject network interception script
        let interceptorScript = WKUserScript(
            source: GlobalFetchInterceptor.shared.injectInterceptionScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(interceptorScript)
        
        config.userContentController = userContentController
        
        // Create WebView with configuration
        webView = WKWebView(frame: .zero, configuration: config)
        
        print("🌐 WebView bridge setup complete")
    }
    
    // MARK: - Initial Diagnostics
    private func runInitialDiagnostics() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let report = self?.diagnosticService.runFullDiagnostics()
            
            DispatchQueue.main.async {
                if let report = report {
                    print("📊 Initial Network Diagnostics:")
                    print(report.description)
                }
            }
        }
    }
    
    // MARK: - Public API Methods
    
    // Universal GET request
    func get<T: Codable>(
        _ url: String,
        headers: [String: String]? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        performRequest(url: url, method: "GET", headers: headers, body: nil, responseType: responseType, completion: completion)
    }
    
    // Universal POST request
    func post<T: Codable>(
        _ url: String,
        body: Data? = nil,
        headers: [String: String]? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        performRequest(url: url, method: "POST", headers: headers, body: body, responseType: responseType, completion: completion)
    }
    
    // Universal PUT request
    func put<T: Codable>(
        _ url: String,
        body: Data? = nil,
        headers: [String: String]? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        performRequest(url: url, method: "PUT", headers: headers, body: body, responseType: responseType, completion: completion)
    }
    
    // Universal DELETE request
    func delete<T: Codable>(
        _ url: String,
        headers: [String: String]? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        performRequest(url: url, method: "DELETE", headers: headers, body: nil, responseType: responseType, completion: completion)
    }
    
    // MARK: - Core Request Method
    private func performRequest<T: Codable>(
        url: String,
        method: String,
        headers: [String: String]?,
        body: Data?,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Create URL request
        guard let requestURL = URL(string: url) else {
            completion(.failure(CentralizedAPIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.httpBody = body
        
        // Set default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("RoomFinderAI/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add authentication token if available
        if let token = sessionManager.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Process request through interceptors
        interceptorService.intercept(request: request) { [weak self] result in
            switch result {
            case .success(let tuple):
                self?.handleResponse(data: tuple.0, response: tuple.1, responseType: responseType, completion: completion)
            case .failure(let error):
                self?.handleError(error: error, completion: completion)
            }
        }
    }
    
    // MARK: - Response Handling
    private func handleResponse<T: Codable>(
        data: Data?,
        response: URLResponse?,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                completion(.failure(CentralizedAPIError.httpError(httpResponse.statusCode)))
                return
            }
        }
        
        // Handle empty response for Void types
        if responseType == VoidResponse.self {
            completion(.success(VoidResponse() as! T))
            return
        }
        
        // Parse JSON response
        guard let data = data else {
            completion(.failure(CentralizedAPIError.noData))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(responseType, from: data)
            completion(.success(result))
        } catch {
            completion(.failure(CentralizedAPIError.decodingError(error)))
        }
    }
    
    // MARK: - Error Handling
    private func handleError<T: Codable>(
        error: Error,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        print("❌ API Error: \(error.localizedDescription)")
        
        // Check if we should retry
        // Retry logic would be implemented here if needed
        
        completion(.failure(error))
    }
    
    // MARK: - Specialized API Methods
    
    // Supabase API calls
    func supabaseRequest<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let url = "https://zmxyysauqtfkvntgtjsm.supabase.co/rest/v1/\(endpoint)"
        var headers = [
            "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM"
        ]
        
        // Add auth header if user is logged in
        if let token = sessionManager.getAccessToken() {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        performRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            responseType: responseType,
            completion: completion
        )
    }
    
    // OpenAI API calls
    func openaiRequest<T: Codable>(
        endpoint: String,
        method: String = "POST",
        body: Data? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let url = "https://api.openai.com/v1/\(endpoint)"
        let headers = [
            "Authorization": "Bearer \(getOpenAIAPIKey())",
            "OpenAI-Organization": getOpenAIOrganization()
        ]
        
        performRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            responseType: responseType,
            completion: completion
        )
    }
    
    // Payment API calls
    func paymentRequest<T: Codable>(
        provider: PaymentProvider,
        endpoint: String,
        method: String = "POST",
        body: Data? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let url: String
        var headers: [String: String] = [:]
        
        switch provider {
        case .stripe:
            url = "https://api.stripe.com/v1/\(endpoint)"
            headers["Authorization"] = "Bearer \(getStripeSecretKey())"
        case .paypal:
            url = "https://api.paypal.com/v1/\(endpoint)"
            headers["Authorization"] = "Bearer \(getPayPalAccessToken())"
        }
        
        performRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            responseType: responseType,
            completion: completion
        )
    }
    
    // Backend API calls
    func backendRequest<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let url = "https://roomfinder-ai-negotiator-production.up.railway.app/api/\(endpoint)"
        
        performRequest(
            url: url,
            method: method,
            headers: nil,
            body: body,
            responseType: responseType,
            completion: completion
        )
    }
    
    // MARK: - Utility Methods
    private func getOpenAIAPIKey() -> String {
        // In production, this would be loaded from secure storage
        return "your-openai-api-key"
    }
    
    private func getOpenAIOrganization() -> String {
        // In production, this would be loaded from secure storage
        return "your-openai-organization"
    }
    
    private func getStripeSecretKey() -> String {
        // In production, this would be loaded from secure storage
        return "sk_test_your-stripe-secret-key"
    }
    
    private func getPayPalAccessToken() -> String {
        // In production, this would be loaded from secure storage
        return "your-paypal-access-token"
    }
    
    // MARK: - Debugging and Diagnostics
    func runDiagnostics() -> String {
        return diagnosticService.generateDiagnosticReport()
    }
    
    func testConnectivity() {
        print("🔍 Testing connectivity to all services...")
        
        // Test Supabase
        supabaseRequest(endpoint: "properties?limit=1", responseType: [Property].self) { result in
            switch result {
            case .success:
                print("✅ Supabase: Connected")
            case .failure(let error):
                print("❌ Supabase: \(error.localizedDescription)")
            }
        }
        
        // Test OpenAI
        let testBody = """
        {
            "model": "gpt-3.5-turbo",
            "messages": [{"role": "user", "content": "Hello"}],
            "max_tokens": 5
        }
        """.data(using: .utf8)
        
        openaiRequest(endpoint: "chat/completions", body: testBody, responseType: OpenAIResponse.self) { result in
            switch result {
            case .success:
                print("✅ OpenAI: Connected")
            case .failure(let error):
                print("❌ OpenAI: \(error.localizedDescription)")
            }
        }
        
        // Test Backend
        backendRequest(endpoint: "health", responseType: HealthResponse.self) { result in
            switch result {
            case .success:
                print("✅ Backend: Connected")
            case .failure(let error):
                print("❌ Backend: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - WKScriptMessageHandler
extension CentralizedAPIService: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "networkInterceptor" else { return }
        
        print("📨 Received network interception message: \(message.body)")
        
        // Handle intercepted network calls from JavaScript
        if let messageBody = message.body as? [String: Any] {
            handleInterceptedNetworkCall(messageBody)
        }
    }
    
    private func handleInterceptedNetworkCall(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "fetch":
            handleInterceptedFetch(message)
        case "xhr":
            handleInterceptedXHR(message)
        default:
            print("⚠️ Unknown interception type: \(type)")
        }
    }
    
    private func handleInterceptedFetch(_ message: [String: Any]) {
        guard let input = message["input"] as? String else { return }
        
        print("🔄 Intercepted fetch call to: \(input)")
        
        // Here you would:
        // 1. Parse the fetch parameters
        // 2. Create a native request
        // 3. Process it through the interceptor service
        // 4. Send the response back to JavaScript
    }
    
    private func handleInterceptedXHR(_ message: [String: Any]) {
        guard let method = message["method"] as? String,
              let url = message["url"] as? String else { return }
        
        print("🔄 Intercepted XHR call: \(method) \(url)")
        
        // Similar handling as fetch
    }
}

// MARK: - Supporting Types
enum PaymentProvider {
    case stripe
    case paypal
}

enum CentralizedAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case httpError(Int)
    case decodingError(Error)
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}

// Response types
struct VoidResponse: Codable {}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}

struct HealthResponse: Codable {
    let status: String
    let timestamp: String
}