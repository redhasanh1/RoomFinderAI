import Foundation
import Network

// MARK: - Mobile API Service
class MobileAPIService {
    static let shared = MobileAPIService()
    
    private let environment = EnvironmentManager.shared
    private let keyManager = APIKeyManager.shared
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.roomfinder.networkmonitor")
    
    private var isNetworkAvailable = true
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
            
            if path.status == .satisfied {
                print("✅ Network connection available")
            } else {
                print("❌ No network connection")
            }
        }
        
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Generic Request Method with Mobile Optimizations
    
    func performRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        authenticated: Bool = true,
        retryCount: Int = 3,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Check network availability
        guard isNetworkAvailable else {
            completion(.failure(APIError.custom("No network connection")))
            return
        }
        
        let urlString = "\(environment.apiEndpoints.baseURL)\(endpoint)"
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: environment.apiEndpoints.defaultTimeout)
        request.httpMethod = method.rawValue
        
        // Add mobile-specific headers
        let headers = environment.getHeaders(for: request, authenticated: authenticated)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        // Add CORS headers for Capacitor
        environment.configureCORSHeaders(for: &request)
        
        // Add security headers
        environment.addSecurityHeaders(to: &request)
        
        // Add body if present
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        // Perform request with retry logic
        performRequestWithRetry(request: request, retryCount: retryCount, completion: completion)
    }
    
    private func performRequestWithRetry<T: Codable>(
        request: URLRequest,
        retryCount: Int,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Handle network error with retry
            if let error = error {
                if retryCount > 0 && self?.shouldRetryRequest(error: error) == true {
                    // Exponential backoff
                    let delay = Double(4 - retryCount) * 2.0
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self?.performRequestWithRetry(
                            request: request,
                            retryCount: retryCount - 1,
                            completion: completion
                        )
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
                return
            }
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    // Success
                    break
                case 401:
                    // Unauthorized - try to refresh token
                    self?.handleUnauthorized { refreshed in
                        if refreshed {
                            // Retry original request with new token
                            var newRequest = request
                            if let token = SessionManager.shared.getAccessToken() {
                                newRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            }
                            self?.performRequestWithRetry(
                                request: newRequest,
                                retryCount: retryCount - 1,
                                completion: completion
                            )
                        } else {
                            DispatchQueue.main.async {
                                completion(.failure(APIError.unauthorized))
                            }
                        }
                    }
                    return
                case 500...599:
                    // Server error - retry if possible
                    if retryCount > 0 {
                        let delay = Double(4 - retryCount) * 2.0
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                            self?.performRequestWithRetry(
                                request: request,
                                retryCount: retryCount - 1,
                                completion: completion
                            )
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        completion(.failure(APIError.serverError(httpResponse.statusCode)))
                    }
                    return
                default:
                    DispatchQueue.main.async {
                        completion(.failure(APIError.serverError(httpResponse.statusCode)))
                    }
                    return
                }
            }
            
            // Parse response
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(APIError.noData))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(T.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                // Log parsing error for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ Failed to parse JSON: \(jsonString)")
                }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Upload Methods
    
    func uploadFile(
        endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        parameters: [String: String]? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard isNetworkAvailable else {
            completion(.failure(APIError.custom("No network connection")))
            return
        }
        
        let urlString = "\(environment.apiEndpoints.baseURL)\(endpoint)"
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: environment.apiEndpoints.uploadTimeout)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        if let token = SessionManager.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add mobile headers
        environment.getHeaders(for: request, authenticated: true).forEach { 
            request.setValue($1, forHTTPHeaderField: $0) 
        }
        
        // Create multipart body
        var body = Data()
        
        // Add parameters
        if let parameters = parameters {
            for (key, value) in parameters {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(APIError.noData))
                }
                return
            }
            
            do {
                let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    private func shouldRetryRequest(error: Error) -> Bool {
        let nsError = error as NSError
        
        // Retry on timeout or network errors
        return nsError.code == NSURLErrorTimedOut ||
               nsError.code == NSURLErrorNetworkConnectionLost ||
               nsError.code == NSURLErrorNotConnectedToInternet
    }
    
    private func handleUnauthorized(completion: @escaping (Bool) -> Void) {
        SessionManager.shared.refreshSession { success in
            completion(success)
        }
    }
    
    // MARK: - OpenAI API Integration
    
    func sendOpenAIRequest(
        messages: [[String: String]],
        model: String = "gpt-3.5-turbo",
        completion: @escaping (Result<OpenAIResponse, Error>) -> Void
    ) {
        guard let apiKey = keyManager.getOpenAIKey() else {
            // Try to fetch from backend if not available
            keyManager.fetchSecureKeys { [weak self] success in
                if success, let apiKey = self?.keyManager.getOpenAIKey() {
                    self?.performOpenAIRequest(messages: messages, model: model, apiKey: apiKey, completion: completion)
                } else {
                    completion(.failure(APIError.custom("OpenAI API key not available")))
                }
            }
            return
        }
        
        performOpenAIRequest(messages: messages, model: model, apiKey: apiKey, completion: completion)
    }
    
    private func performOpenAIRequest(
        messages: [[String: String]],
        model: String,
        apiKey: String,
        completion: @escaping (Result<OpenAIResponse, Error>) -> Void
    ) {
        let url = URL(string: "\(environment.apiEndpoints.openAIBaseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(APIError.noData))
                }
                return
            }
            
            do {
                let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

// MARK: - OpenAI Response Models
struct OpenAIResponse: Codable {
    let id: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}