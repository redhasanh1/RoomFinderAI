import Foundation
import Network

// MARK: - Network Manager
class NetworkManager {
    static let shared = NetworkManager()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var isConnected = true
    private var retryQueue: [PendingRequest] = []
    
    // Network status change notification
    static let networkStatusChangedNotification = Notification.Name("NetworkStatusChanged")
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let wasConnected = self?.isConnected ?? true
            self?.isConnected = path.status == .satisfied
            
            // Notify about network status change
            if wasConnected != self?.isConnected {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NetworkManager.networkStatusChangedNotification,
                        object: nil,
                        userInfo: ["isConnected": self?.isConnected ?? false]
                    )
                }
                
                // Process retry queue if back online
                if self?.isConnected == true {
                    self?.processRetryQueue()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    var isNetworkAvailable: Bool {
        return isConnected
    }
    
    // MARK: - Request with Retry
    
    func performRequest<T: Codable>(
        _ request: URLRequest,
        retryCount: Int = APIConfig.maxRetries,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Check network availability
        guard isNetworkAvailable else {
            // Queue request for later
            let pendingRequest = PendingRequest(
                request: request,
                type: T.self,
                completion: completion
            )
            retryQueue.append(pendingRequest)
            
            DispatchQueue.main.async {
                completion(.failure(NetworkError.offline))
            }
            return
        }
        
        performRequestWithRetry(request, retryCount: retryCount, completion: completion)
    }
    
    private func performRequestWithRetry<T: Codable>(
        _ request: URLRequest,
        retryCount: Int,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Handle network error
            if let error = error {
                if retryCount > 0 && self?.isRetryableError(error) == true {
                    // Exponential backoff
                    let delay = Double(APIConfig.maxRetries - retryCount + 1) * 2.0
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self?.performRequestWithRetry(
                            request,
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
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.unauthorized))
                    }
                    return
                case 429:
                    // Rate limited - retry with backoff
                    if retryCount > 0 {
                        let delay = 5.0 // Wait 5 seconds for rate limit
                        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                            self?.performRequestWithRetry(
                                request,
                                retryCount: retryCount - 1,
                                completion: completion
                            )
                        }
                        return
                    }
                    fallthrough
                default:
                    DispatchQueue.main.async {
                        completion(.failure(NetworkError.httpError(httpResponse.statusCode)))
                    }
                    return
                }
            }
            
            // Parse data
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.noData))
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
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Retry Queue Management
    
    private func processRetryQueue() {
        let requests = retryQueue
        retryQueue.removeAll()
        
        for pendingRequest in requests {
            // Re-attempt the request
            performRequestDynamic(pendingRequest)
        }
    }
    
    private func performRequestDynamic(_ pendingRequest: PendingRequest) {
        // This is a workaround to handle generic types in stored requests
        URLSession.shared.dataTask(with: pendingRequest.request) { data, response, error in
            if let error = error {
                pendingRequest.errorHandler?(error)
                return
            }
            
            guard let data = data else {
                pendingRequest.errorHandler?(NetworkError.noData)
                return
            }
            
            pendingRequest.dataHandler?(data)
        }.resume()
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors that should be retried
        let nsError = error as NSError
        let retryableCodes = [
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet
        ]
        return retryableCodes.contains(nsError.code)
    }
}

// MARK: - Pending Request
private class PendingRequest {
    let request: URLRequest
    let type: Any.Type
    var dataHandler: ((Data) -> Void)?
    var errorHandler: ((Error) -> Void)?
    
    init<T: Codable>(request: URLRequest, type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        self.request = request
        self.type = type
        
        self.dataHandler = { data in
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(T.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        self.errorHandler = { error in
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case offline
    case unauthorized
    case httpError(Int)
    case noData
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .offline:
            return "No internet connection. Your request will be processed when you're back online."
        case .unauthorized:
            return "Please log in to continue."
        case .httpError(let code):
            return "Server error: \(code)"
        case .noData:
            return "No data received from server."
        case .timeout:
            return "Request timed out. Please try again."
        }
    }
}

// MARK: - URLRequest Extension
extension URLRequest {
    mutating func setDefaultHeaders() {
        setValue("application/json", forHTTPHeaderField: "Content-Type")
        setValue("iOS", forHTTPHeaderField: "X-Platform")
        setValue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0", forHTTPHeaderField: "X-App-Version")
        
        // Add auth token if available
        if let token = APIService.shared.getAuthToken() {
            setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    static func create(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        timeout: TimeInterval = APIConfig.timeout
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.httpBody = body
        request.setDefaultHeaders()
        return request
    }
}