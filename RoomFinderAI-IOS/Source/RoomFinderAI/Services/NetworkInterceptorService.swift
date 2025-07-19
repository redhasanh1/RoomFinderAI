import Foundation
import Combine

// MARK: - Network Interceptor Service
class NetworkInterceptorService: NSObject, ObservableObject {
    static let shared = NetworkInterceptorService()
    
    // MARK: - Published Properties
    @Published var activeRequests: [String: InterceptedRequest] = [:]
    @Published var requestStatistics: RequestStatistics = RequestStatistics()
    
    // MARK: - Private Properties
    private var interceptors: [NetworkInterceptor] = []
    private var requestID: Int = 0
    private let queue = DispatchQueue(label: "NetworkInterceptorService", qos: .utility)
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupDefaultInterceptors()
    }
    
    // MARK: - Setup
    private func setupDefaultInterceptors() {
        // Add default interceptors
        addInterceptor(AuthenticationInterceptor())
        addInterceptor(HeaderInterceptor())
        addInterceptor(LoggingInterceptor())
        addInterceptor(ErrorHandlingInterceptor())
        addInterceptor(RetryInterceptor())
        addInterceptor(CacheInterceptor())
        addInterceptor(RateLimitInterceptor())
        addInterceptor(RequestTimeoutInterceptor())
        addInterceptor(MetricsInterceptor())
    }
    
    // MARK: - Public Methods
    func addInterceptor(_ interceptor: NetworkInterceptor) {
        interceptors.append(interceptor)
        interceptors.sort { $0.priority < $1.priority }
    }
    
    func removeInterceptor<T: NetworkInterceptor>(ofType type: T.Type) {
        interceptors.removeAll { $0 is T }
    }
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        let requestID = generateRequestID()
        
        // Create intercepted request for tracking
        let interceptedRequest = InterceptedRequest(
            id: requestID,
            originalRequest: request,
            modifiedRequest: modifiedRequest,
            timestamp: Date(),
            status: .pending
        )
        
        await MainActor.run {
            activeRequests[requestID] = interceptedRequest
        }
        
        // Apply request interceptors
        for interceptor in interceptors {
            do {
                modifiedRequest = try await interceptor.intercept(request: modifiedRequest)
            } catch {
                LoggingService.shared.error(
                    "Request interceptor failed: \(error.localizedDescription)",
                    category: .network,
                    metadata: ["interceptor": String(describing: type(of: interceptor))]
                )
                throw error
            }
        }
        
        // Update intercepted request
        await MainActor.run {
            if var trackedRequest = activeRequests[requestID] {
                trackedRequest.modifiedRequest = modifiedRequest
                trackedRequest.status = .intercepted
                activeRequests[requestID] = trackedRequest
            }
        }
        
        return modifiedRequest
    }
    
    func intercept(response: URLResponse?, data: Data?, error: Error?, for request: URLRequest) async -> InterceptedResponse {
        let requestID = findRequestID(for: request)
        
        var interceptedResponse = InterceptedResponse(
            response: response,
            data: data,
            error: error,
            timestamp: Date()
        )
        
        // Apply response interceptors
        for interceptor in interceptors {
            interceptedResponse = await interceptor.intercept(response: interceptedResponse, for: request)
        }
        
        // Update request status
        await MainActor.run {
            if let requestID = requestID, var trackedRequest = activeRequests[requestID] {
                trackedRequest.status = .completed
                trackedRequest.response = interceptedResponse
                trackedRequest.duration = Date().timeIntervalSince(trackedRequest.timestamp)
                activeRequests[requestID] = trackedRequest
                
                // Update statistics
                requestStatistics.updateRequest(trackedRequest)
                
                // Remove from active requests after a delay
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    activeRequests.removeValue(forKey: requestID)
                }
            }
        }
        
        return interceptedResponse
    }
    
    func clearActiveRequests() {
        activeRequests.removeAll()
    }
    
    func getInterceptors() -> [NetworkInterceptor] {
        return interceptors
    }
    
    // MARK: - Private Methods
    private func generateRequestID() -> String {
        queue.sync {
            requestID += 1
            return "req_\(requestID)"
        }
    }
    
    private func findRequestID(for request: URLRequest) -> String? {
        return activeRequests.first { $0.value.originalRequest.url == request.url }?.key
    }
}

// MARK: - Network Interceptor Protocol
protocol NetworkInterceptor {
    var priority: Int { get }
    
    func intercept(request: URLRequest) async throws -> URLRequest
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse
}

// MARK: - Authentication Interceptor
class AuthenticationInterceptor: NetworkInterceptor {
    let priority: Int = 100
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        
        // Add authentication headers
        if let token = await getAuthToken() {
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return modifiedRequest
    }
    
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse {
        var modifiedResponse = response
        
        // Handle authentication errors
        if let httpResponse = response.response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                // Token expired or invalid
                await handleAuthenticationError()
                modifiedResponse.error = AuthError.tokenExpired
            }
        }
        
        return modifiedResponse
    }
    
    private func getAuthToken() async -> String? {
        // Get token from secure storage or auth service
        return "mock_token_123"
    }
    
    private func handleAuthenticationError() async {
        // Refresh token or redirect to login
        LoggingService.shared.warning("Authentication error detected", category: .auth)
    }
}

// MARK: - Header Interceptor
class HeaderInterceptor: NetworkInterceptor {
    let priority: Int = 200
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        
        // Add common headers
        modifiedRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        modifiedRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        modifiedRequest.setValue("RoomFinderAI/1.0", forHTTPHeaderField: "User-Agent")
        modifiedRequest.setValue("iOS", forHTTPHeaderField: "X-Platform")
        modifiedRequest.setValue(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0", forHTTPHeaderField: "X-App-Version")
        
        // Add correlation ID for tracking
        let correlationID = UUID().uuidString
        modifiedRequest.setValue(correlationID, forHTTPHeaderField: "X-Correlation-ID")
        
        return modifiedRequest
    }
    
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse {
        return response
    }
}

// MARK: - Logging Interceptor
class LoggingInterceptor: NetworkInterceptor {
    let priority: Int = 300
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        // Log request
        LoggingService.shared.logNetworkRequest(
            url: request.url?.absoluteString ?? "unknown",
            method: request.httpMethod ?? "GET",
            statusCode: nil,
            duration: 0
        )
        
        return request
    }
    
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse {
        // Log response
        let statusCode = (response.response as? HTTPURLResponse)?.statusCode
        let duration = response.timestamp.timeIntervalSince(Date())
        
        LoggingService.shared.logNetworkRequest(
            url: request.url?.absoluteString ?? "unknown",
            method: request.httpMethod ?? "GET",
            statusCode: statusCode,
            duration: abs(duration),
            error: response.error
        )
        
        return response
    }
}

// MARK: - Error Handling Interceptor
class ErrorHandlingInterceptor: NetworkInterceptor {
    let priority: Int = 400
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        return request
    }
    
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse {
        var modifiedResponse = response
        
        // Handle different types of errors
        if let error = response.error {
            let mappedError = mapError(error)
            modifiedResponse.error = mappedError
            
            // Log error
            ErrorHandler.shared.handle(
                mappedError,
                context: ErrorContext(
                    additionalInfo: [
                        "url": request.url?.absoluteString ?? "unknown",
                        "method": request.httpMethod ?? "GET"
                    ]
                )
            )
        }
        
        // Handle HTTP errors
        if let httpResponse = response.response as? HTTPURLResponse {
            if httpResponse.statusCode >= 400 {
                let httpError = mapHTTPError(statusCode: httpResponse.statusCode)
                modifiedResponse.error = httpError
            }
        }
        
        return modifiedResponse
    }
    
    private func mapError(_ error: Error) -> Error {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return NetworkError.noInternetConnection
            case .timedOut:
                return NetworkError.timeoutError
            case .cannotFindHost:
                return NetworkError.hostNotFound
            default:
                return NetworkError.requestFailed(urlError.localizedDescription)
            }
        }
        
        return error
    }
    
    private func mapHTTPError(statusCode: Int) -> Error {
        switch statusCode {
        case 400:
            return NetworkError.badRequest
        case 401:
            return AuthError.invalidCredentials
        case 403:
            return AuthError.insufficientPermissions
        case 404:
            return NetworkError.notFound
        case 429:
            return NetworkError.rateLimitExceeded
        case 500...599:
            return NetworkError.serverError
        default:
            return NetworkError.requestFailed("HTTP \(statusCode)")
        }
    }
}

// MARK: - Retry Interceptor
class RetryInterceptor: NetworkInterceptor {
    let priority: Int = 500
    private let retryService = RetryService.shared
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        return request
    }
    
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse {
        // Check if response should be retried
        if shouldRetry(response: response) {
            // Mark for retry (actual retry logic would be handled by the calling service)
            LoggingService.shared.info(
                "Request marked for retry",
                category: .network,
                metadata: ["url": request.url?.absoluteString ?? "unknown"]
            )
        }
        
        return response
    }
    
    private func shouldRetry(response: InterceptedResponse) -> Bool {
        if let error = response.error {
            // Retry on network errors
            if error is NetworkError {
                return true
            }
            
            // Retry on URL errors
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                    return true
                default:
                    return false
                }
            }
        }
        
        // Retry on server errors
        if let httpResponse = response.response as? HTTPURLResponse {
            return httpResponse.statusCode >= 500
        }
        
        return false
    }
}

// MARK: - Cache Interceptor
class CacheInterceptor: NetworkInterceptor {
    let priority: Int = 600
    private let cacheService = CacheManager.shared
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        
        // Add cache headers
        if request.httpMethod == "GET" {
            modifiedRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            modifiedRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        }
        
        return modifiedRequest
    }
    
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse {
        // Cache successful responses
        if let httpResponse = response.response as? HTTPURLResponse,
           httpResponse.statusCode == 200,
           let data = response.data,
           let url = request.url {
            
            let cacheKey = "network_cache_\(url.absoluteString.hashValue)"
            // Use the listing cache for now as a general cache - this could be improved
            ListingCache.shared.set(key: cacheKey, value: data, maxAge: 300) // 5 minutes
        }
        
        return response
    }
}

// MARK: - Rate Limit Interceptor
class RateLimitInterceptor: NetworkInterceptor {
    let priority: Int = 700
    private var requestCounts: [String: Int] = [:]
    private var windowStart: Date = Date()
    private let windowDuration: TimeInterval = 60 // 1 minute
    private let maxRequestsPerWindow = 100
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        guard let host = request.url?.host else {
            return request
        }
        
        // Check rate limits
        if isRateLimited(for: host) {
            throw NetworkError.rateLimitExceeded
        }
        
        // Update request count
        updateRequestCount(for: host)
        
        return request
    }
    
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse {
        // Check for rate limit headers
        if let httpResponse = response.response as? HTTPURLResponse {
            if let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
               let remainingInt = Int(remaining), remainingInt <= 0 {
                
                LoggingService.shared.warning(
                    "Rate limit exceeded for host: \(request.url?.host ?? "unknown")",
                    category: .network
                )
            }
        }
        
        return response
    }
    
    private func isRateLimited(for host: String) -> Bool {
        resetWindowIfNeeded()
        
        let currentCount = requestCounts[host] ?? 0
        return currentCount >= maxRequestsPerWindow
    }
    
    private func updateRequestCount(for host: String) {
        resetWindowIfNeeded()
        
        let currentCount = requestCounts[host] ?? 0
        requestCounts[host] = currentCount + 1
    }
    
    private func resetWindowIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(windowStart) >= windowDuration {
            requestCounts.removeAll()
            windowStart = now
        }
    }
}

// MARK: - Request Timeout Interceptor
class RequestTimeoutInterceptor: NetworkInterceptor {
    let priority: Int = 800
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        
        // Set appropriate timeout based on request type
        if request.httpMethod == "POST" || request.httpMethod == "PUT" {
            modifiedRequest.timeoutInterval = 60.0 // 1 minute for write operations
        } else {
            modifiedRequest.timeoutInterval = 30.0 // 30 seconds for read operations
        }
        
        return modifiedRequest
    }
    
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse {
        return response
    }
}

// MARK: - Metrics Interceptor
class MetricsInterceptor: NetworkInterceptor {
    let priority: Int = 900
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        // Track request metrics
        NetworkInterceptorService.shared.requestStatistics.totalRequests += 1
        
        return request
    }
    
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse {
        // Track response metrics
        if response.error != nil {
            NetworkInterceptorService.shared.requestStatistics.totalErrors += 1
        } else {
            NetworkInterceptorService.shared.requestStatistics.totalSuccesses += 1
        }
        
        return response
    }
}

// MARK: - Supporting Types
struct InterceptedRequest {
    let id: String
    let originalRequest: URLRequest
    var modifiedRequest: URLRequest
    let timestamp: Date
    var status: RequestStatus
    var response: InterceptedResponse?
    var duration: TimeInterval?
    
    enum RequestStatus {
        case pending
        case intercepted
        case completed
        case failed
    }
}

struct InterceptedResponse {
    let response: URLResponse?
    let data: Data?
    var error: Error?
    let timestamp: Date
}

struct RequestStatistics {
    var totalRequests: Int = 0
    var totalSuccesses: Int = 0
    var totalErrors: Int = 0
    var averageResponseTime: TimeInterval = 0
    var requestsByHost: [String: Int] = [:]
    var errorsByType: [String: Int] = [:]
    
    mutating func updateRequest(_ request: InterceptedRequest) {
        if let host = request.originalRequest.url?.host {
            requestsByHost[host] = (requestsByHost[host] ?? 0) + 1
        }
        
        if let duration = request.duration {
            averageResponseTime = (averageResponseTime + duration) / 2
        }
        
        if let error = request.response?.error {
            let errorType = String(describing: type(of: error))
            errorsByType[errorType] = (errorsByType[errorType] ?? 0) + 1
        }
    }
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalSuccesses) / Double(totalRequests)
    }
    
    var errorRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalErrors) / Double(totalRequests)
    }
}