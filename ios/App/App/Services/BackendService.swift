import Foundation

// Backend Service - Bridge between Swift and JavaScript services
class BackendService {
    
    static let shared = BackendService()
    private var bridge: CAPBridgeProtocol?
    
    private init() {}
    
    // Set the Capacitor bridge
    func setBridge(_ bridge: CAPBridgeProtocol) {
        self.bridge = bridge
    }
    
    // MARK: - Supabase Auth Methods
    
    func signUp(email: String, password: String, metadata: [String: Any] = [:], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let params = [
            "email": email,
            "password": password,
            "metadata": metadata
        ] as [String : Any]
        
        executeJavaScript(
            function: "supabaseService.signUp",
            params: params,
            completion: completion
        )
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let params = [
            "email": email,
            "password": password
        ]
        
        executeJavaScript(
            function: "supabaseService.signIn",
            params: params,
            completion: completion
        )
    }
    
    func signOut(completion: @escaping (Result<Bool, Error>) -> Void) {
        executeJavaScript(
            function: "supabaseService.signOut",
            params: [:],
            completion: { result in
                switch result {
                case .success(_):
                    completion(.success(true))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    func getCurrentUser(completion: @escaping (Result<[String: Any]?, Error>) -> Void) {
        executeJavaScript(
            function: "supabaseService.getCurrentUser",
            params: [:],
            completion: completion
        )
    }
    
    // MARK: - Property Methods
    
    func getProperties(filters: [String: Any] = [:], completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        executeJavaScript(
            function: "apiService.getProperties",
            params: filters,
            completion: { result in
                switch result {
                case .success(let data):
                    if let properties = data["data"] as? [[String: Any]] {
                        completion(.success(properties))
                    } else {
                        completion(.failure(BackendError.invalidResponse))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    func searchProperties(query: String, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let params = ["query": query]
        
        executeJavaScript(
            function: "apiService.searchProperties",
            params: params,
            completion: { result in
                switch result {
                case .success(let data):
                    if let properties = data["data"] as? [[String: Any]] {
                        completion(.success(properties))
                    } else {
                        completion(.failure(BackendError.invalidResponse))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    // MARK: - AI Negotiation Methods
    
    func startNegotiation(propertyId: String, initialOffer: Double, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let params = [
            "propertyId": propertyId,
            "initialOffer": initialOffer
        ] as [String : Any]
        
        executeJavaScript(
            function: "apiService.startNegotiation",
            params: params,
            completion: completion
        )
    }
    
    func sendNegotiationMessage(sessionId: String, message: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let params = [
            "sessionId": sessionId,
            "message": message
        ]
        
        executeJavaScript(
            function: "apiService.sendNegotiationMessage",
            params: params,
            completion: completion
        )
    }
    
    // MARK: - Favorites Methods
    
    func toggleFavorite(propertyId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let params = ["propertyId": propertyId]
        
        executeJavaScript(
            function: "supabaseService.toggleFavorite",
            params: params,
            completion: { result in
                switch result {
                case .success(let data):
                    if let action = data["action"] as? String {
                        completion(.success(action))
                    } else {
                        completion(.failure(BackendError.invalidResponse))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    // MARK: - Network Status
    
    func checkNetworkConnectivity(completion: @escaping (Bool) -> Void) {
        executeJavaScript(
            function: "networkUtils.checkNetworkConnectivity",
            params: [:],
            completion: { result in
                switch result {
                case .success(let data):
                    if let isOnline = data as? Bool {
                        completion(isOnline)
                    } else {
                        completion(true) // Default to online
                    }
                case .failure(_):
                    completion(true) // Default to online on error
                }
            }
        )
    }
    
    // MARK: - Analytics
    
    func trackEvent(_ event: String, data: [String: Any] = [:]) {
        let params = [
            "event": event,
            "data": data
        ] as [String : Any]
        
        // Fire and forget - don't wait for completion
        executeJavaScript(
            function: "apiService.trackEvent",
            params: params,
            completion: { _ in }
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func executeJavaScript(function: String, params: [String: Any], completion: @escaping (Result<Any, Error>) -> Void) {
        guard let bridge = bridge else {
            completion(.failure(BackendError.bridgeNotInitialized))
            return
        }
        
        let paramsJSON: String
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params)
            paramsJSON = String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            completion(.failure(error))
            return
        }
        
        let js = """
        (async () => {
            try {
                const result = await \(function)(\(paramsJSON));
                return JSON.stringify(result);
            } catch (error) {
                throw new Error(JSON.stringify({
                    success: false,
                    error: error.message || 'Unknown error'
                }));
            }
        })()
        """
        
        bridge.evalWithPlugin(js, pluginId: "Console") { result in
            if let resultString = result as? String,
               let data = resultString.data(using: .utf8) {
                do {
                    let json = try JSONSerialization.jsonObject(with: data)
                    if let dict = json as? [String: Any],
                       let success = dict["success"] as? Bool,
                       !success,
                       let errorMessage = dict["error"] as? String {
                        completion(.failure(BackendError.apiError(errorMessage)))
                    } else {
                        completion(.success(json))
                    }
                } catch {
                    completion(.failure(error))
                }
            } else if let error = result as? Error {
                completion(.failure(error))
            } else {
                completion(.failure(BackendError.invalidResponse))
            }
        }
    }
}

// MARK: - Backend Errors

enum BackendError: LocalizedError {
    case bridgeNotInitialized
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .bridgeNotInitialized:
            return "Backend service not initialized"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return message
        }
    }
}