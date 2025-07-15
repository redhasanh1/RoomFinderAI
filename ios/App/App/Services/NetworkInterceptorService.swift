import Foundation
import WebKit

// MARK: - Network Interceptor Service
class NetworkInterceptorService {
    static let shared = NetworkInterceptorService()
    
    private var interceptors: [NetworkInterceptor] = []
    private let diagnosticService = NetworkDiagnosticService.shared
    
    private init() {
        setupDefaultInterceptors()
    }
    
    // MARK: - Setup Default Interceptors
    private func setupDefaultInterceptors() {
        // Add logging interceptor
        addInterceptor(LoggingInterceptor())
        
        // Add diagnostics interceptor
        addInterceptor(DiagnosticsInterceptor())
        
        // Add retry interceptor
        addInterceptor(RetryInterceptor())
        
        // Add Capacitor HTTP redirector
        addInterceptor(CapacitorHTTPInterceptor())
    }
    
    // MARK: - Interceptor Management
    func addInterceptor(_ interceptor: NetworkInterceptor) {
        interceptors.append(interceptor)
    }
    
    func removeInterceptor(_ interceptor: NetworkInterceptor) {
        interceptors.removeAll { $0 === interceptor }
    }
    
    // MARK: - Request Interception
    func intercept(request: URLRequest, completion: @escaping (Result<(Data?, URLResponse?), Error>) -> Void) {
        processRequest(request, interceptorIndex: 0, completion: completion)
    }
    
    private func processRequest(_ request: URLRequest, interceptorIndex: Int, completion: @escaping (Result<(Data?, URLResponse?), Error>) -> Void) {
        guard interceptorIndex < interceptors.count else {
            // All interceptors processed, execute the actual request
            executeRequest(request, completion: completion)
            return
        }
        
        let interceptor = interceptors[interceptorIndex]
        
        interceptor.intercept(request: request) { [weak self] result in
            switch result {
            case .success(let modifiedRequest):
                // Continue with the next interceptor
                self?.processRequest(modifiedRequest, interceptorIndex: interceptorIndex + 1, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func executeRequest(_ request: URLRequest, completion: @escaping (Result<(Data?, URLResponse?), Error>) -> Void) {
        // Log the final request
        diagnosticService.logNetworkRequest(
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields,
            body: request.httpBody
        )
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Log the response
            if let httpResponse = response as? HTTPURLResponse {
                self?.diagnosticService.logNetworkResponse(
                    url: request.url?.absoluteString ?? "",
                    statusCode: httpResponse.statusCode,
                    headers: httpResponse.allHeaderFields as? [String: String],
                    data: data,
                    error: error
                )
            }
            
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success((data, response)))
            }
        }.resume()
    }
}

// MARK: - Network Interceptor Protocol
protocol NetworkInterceptor: AnyObject {
    func intercept(request: URLRequest, completion: @escaping (Result<URLRequest, Error>) -> Void)
}

// MARK: - Logging Interceptor
class LoggingInterceptor: NetworkInterceptor {
    func intercept(request: URLRequest, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        print("🔍 [LoggingInterceptor] Intercepting request to: \(request.url?.absoluteString ?? "unknown")")
        print("   Method: \(request.httpMethod ?? "GET")")
        print("   Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        if let body = request.httpBody {
            print("   Body: \(body.count) bytes")
        }
        
        completion(.success(request))
    }
}

// MARK: - Diagnostics Interceptor
class DiagnosticsInterceptor: NetworkInterceptor {
    func intercept(request: URLRequest, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        guard let url = request.url else {
            completion(.failure(NetworkInterceptorError.invalidURL))
            return
        }
        
        // Check if the host is reachable
        let host = url.host ?? ""
        let isReachable = NetworkDiagnosticService.shared.runFullDiagnostics().reachabilityTests
            .first { $0.host == host }?.isReachable ?? false
        
        if !isReachable {
            print("⚠️ [DiagnosticsInterceptor] Host \(host) may not be reachable")
        }
        
        completion(.success(request))
    }
}

// MARK: - Retry Interceptor
class RetryInterceptor: NetworkInterceptor {
    private let maxRetries = 3
    private var retryCount: [String: Int] = [:]
    
    func intercept(request: URLRequest, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let requestKey = "\(request.url?.absoluteString ?? "")_\(request.httpMethod ?? "GET")"
        
        // Reset retry count for new requests
        if retryCount[requestKey] == nil {
            retryCount[requestKey] = 0
        }
        
        // Add retry headers
        var mutableRequest = request
        mutableRequest.setValue("\(retryCount[requestKey] ?? 0)", forHTTPHeaderField: "X-Retry-Count")
        
        completion(.success(mutableRequest))
    }
    
    func shouldRetry(for error: Error, request: URLRequest) -> Bool {
        let requestKey = "\(request.url?.absoluteString ?? "")_\(request.httpMethod ?? "GET")"
        let currentRetryCount = retryCount[requestKey] ?? 0
        
        guard currentRetryCount < maxRetries else {
            return false
        }
        
        // Retry on specific errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                retryCount[requestKey] = currentRetryCount + 1
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

// MARK: - Capacitor HTTP Interceptor
class CapacitorHTTPInterceptor: NetworkInterceptor {
    func intercept(request: URLRequest, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        // Check if we're on iOS and should use Capacitor HTTP
        #if targetEnvironment(simulator) || os(iOS)
        if shouldUseCapacitorHTTP(for: request) {
            print("🔄 [CapacitorHTTPInterceptor] Redirecting to Capacitor HTTP")
            
            // Transform the request to use Capacitor HTTP
            handleCapacitorHTTPRequest(request) { result in
                switch result {
                case .success(let response):
                    // Convert Capacitor HTTP response back to URLRequest format
                    completion(.success(request))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.success(request))
        }
        #else
        completion(.success(request))
        #endif
    }
    
    private func shouldUseCapacitorHTTP(for request: URLRequest) -> Bool {
        // Use Capacitor HTTP for external API calls
        guard let url = request.url else { return false }
        
        let externalHosts = [
            "supabase.co",
            "api.openai.com",
            "api.stripe.com",
            "railway.app",
            "paypal.com"
        ]
        
        return externalHosts.contains { url.host?.contains($0) ?? false }
    }
    
    private func handleCapacitorHTTPRequest(_ request: URLRequest, completion: @escaping (Result<CapacitorHTTPResponse, Error>) -> Void) {
        // This would integrate with the Capacitor HTTP plugin
        // For now, we'll simulate the call
        
        guard let url = request.url else {
            completion(.failure(NetworkInterceptorError.invalidURL))
            return
        }
        
        // Create Capacitor HTTP request
        let capacitorRequest = CapacitorHTTPRequest(
            url: url.absoluteString,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields ?? [:],
            data: request.httpBody
        )
        
        // Execute via Capacitor HTTP (this would be the actual Capacitor call)
        executeCapacitorHTTPRequest(capacitorRequest, completion: completion)
    }
    
    private func executeCapacitorHTTPRequest(_ request: CapacitorHTTPRequest, completion: @escaping (Result<CapacitorHTTPResponse, Error>) -> Void) {
        // This is where you would call the actual Capacitor HTTP plugin
        // For now, we'll simulate a successful response
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            let response = CapacitorHTTPResponse(
                status: 200,
                headers: [:],
                data: Data(),
                url: request.url
            )
            completion(.success(response))
        }
    }
}

// MARK: - Capacitor HTTP Models
struct CapacitorHTTPRequest {
    let url: String
    let method: String
    let headers: [String: String]
    let data: Data?
}

struct CapacitorHTTPResponse {
    let status: Int
    let headers: [String: String]
    let data: Data
    let url: String
}

// MARK: - Network Interceptor Errors
enum NetworkInterceptorError: Error, LocalizedError {
    case invalidURL
    case capacitorHTTPNotAvailable
    case interceptorFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .capacitorHTTPNotAvailable:
            return "Capacitor HTTP plugin not available"
        case .interceptorFailed(let message):
            return "Interceptor failed: \(message)"
        }
    }
}

// MARK: - Global Fetch Interceptor
class GlobalFetchInterceptor {
    static let shared = GlobalFetchInterceptor()
    
    private init() {}
    
    func setupGlobalInterception() {
        // This would be called during app initialization
        // to set up global interception of all network calls
        print("🌐 Setting up global network interception")
        
        // For WKWebView, we would need to:
        // 1. Inject JavaScript to override fetch and XMLHttpRequest
        // 2. Handle the intercepted calls via message handlers
        // 3. Route them through our interceptor service
    }
    
    func injectInterceptionScript() -> String {
        return """
        (function() {
            // Store original fetch and XMLHttpRequest
            const originalFetch = window.fetch;
            const originalXMLHttpRequest = window.XMLHttpRequest;
            
            // Override fetch
            window.fetch = function(input, init) {
                console.log('🔍 Intercepted fetch call:', input, init);
                
                // Send message to native code
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.networkInterceptor) {
                    window.webkit.messageHandlers.networkInterceptor.postMessage({
                        type: 'fetch',
                        input: input,
                        init: init
                    });
                }
                
                // Continue with original fetch
                return originalFetch.apply(this, arguments);
            };
            
            // Override XMLHttpRequest
            window.XMLHttpRequest = function() {
                const xhr = new originalXMLHttpRequest();
                const originalOpen = xhr.open;
                const originalSend = xhr.send;
                
                xhr.open = function(method, url, async, user, password) {
                    console.log('🔍 Intercepted XMLHttpRequest:', method, url);
                    
                    // Send message to native code
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.networkInterceptor) {
                        window.webkit.messageHandlers.networkInterceptor.postMessage({
                            type: 'xhr',
                            method: method,
                            url: url
                        });
                    }
                    
                    return originalOpen.apply(this, arguments);
                };
                
                xhr.send = function(data) {
                    console.log('🔍 XMLHttpRequest send:', data);
                    return originalSend.apply(this, arguments);
                };
                
                return xhr;
            };
            
            console.log('✅ Network interception setup complete');
        })();
        """
    }
}