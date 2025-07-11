import Foundation
import Network

// MARK: - Secure API Configuration
struct SecureAPIConfig {
    // Railway Backend Configuration
    static let baseURL = "https://roomfinder-ai-negotiator-production.up.railway.app"
    static let apiVersion = "v1"
    
    // Only public configuration allowed in iOS app
    static let supabaseURL = "https://zmxyysauqtfkvntgtjsm.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM"
    
    // API Endpoints
    struct Endpoints {
        // Authentication
        static let register = "/api/register"
        static let login = "/api/login"
        static let sendVerification = "/api/send-verification"
        static let verifyEmail = "/api/verify-email"
        static let sendResetCode = "/api/send-reset-code"
        static let verifyResetCode = "/api/verify-reset-code"
        static let resetPassword = "/api/reset-password"
        
        // Listings
        static let listings = "/api/listings"
        static let favorites = "/api/favorites"
        
        // AI & Negotiation
        static let aiNegotiate = "/api/ai-negotiate"
        static let aiNegotiator = "/api/ai-negotiator"
        
        // Payments & Subscriptions
        static let processPayment = "/api/process-payment"
        static let subscription = "/api/subscription"
        static let paymentMethods = "/api/payment-methods"
        
        // Sublease
        static let subleaseRequest = "/api/sublease/request"
        static let subleaseRequests = "/api/sublease/requests"
        static let subleaseMatches = "/api/sublease/matches"
        static let subleaseSearch = "/api/sublease/search"
        
        // Verification
        static let verifyUploadId = "/api/verify/upload-id"
        static let verifyFaceMatch = "/api/verify/face-match"
        static let verifyStatus = "/api/verify/status"
        
        // Analytics & Market Intelligence
        static let analytics = "/api/analytics"
        static let marketIntelligence = "/api/market-intelligence"
        
        // Configuration
        static let config = "/api/config"
    }
    
    // Network Configuration
    static let timeout: TimeInterval = 30
    static let maxRetries = 3
    static let retryDelay: TimeInterval = 2.0
}

// MARK: - Secure API Service
class SecureAPIService {
    static let shared = SecureAPIService()
    
    private let sessionManager = SessionManager.shared
    private let networkManager = NetworkManager.shared
    private let keychain = KeychainService.shared
    
    private init() {}
    
    // MARK: - Authentication Methods
    
    func register(email: String, password: String, firstName: String, lastName: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let parameters = [
            "email": email,
            "password": password,
            "first_name": firstName,
            "last_name": lastName
        ]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.register,
            method: .POST,
            parameters: parameters,
            authenticated: false,
            completion: completion
        )
    }
    
    func login(email: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let parameters = [
            "email": email,
            "password": password
        ]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.login,
            method: .POST,
            parameters: parameters,
            authenticated: false
        ) { (result: Result<AuthResponse, Error>) in
            switch result {
            case .success(let authResponse):
                // Start session if login successful
                if let user = authResponse.user, let token = authResponse.token {
                    self.sessionManager.startSession(
                        user: user,
                        accessToken: token,
                        refreshToken: nil, // Backend doesn't return refresh token yet
                        expiresIn: 24 * 3600 // 24 hours
                    )
                }
                completion(.success(authResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func sendVerificationEmail(email: String, completion: @escaping (Result<GenericResponse, Error>) -> Void) {
        let parameters = ["email": email]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.sendVerification,
            method: .POST,
            parameters: parameters,
            authenticated: false,
            completion: completion
        )
    }
    
    func verifyEmail(email: String, code: String, completion: @escaping (Result<GenericResponse, Error>) -> Void) {
        let parameters = [
            "email": email,
            "code": code
        ]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.verifyEmail,
            method: .POST,
            parameters: parameters,
            authenticated: false,
            completion: completion
        )
    }
    
    func sendPasswordResetCode(email: String, completion: @escaping (Result<GenericResponse, Error>) -> Void) {
        let parameters = ["email": email]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.sendResetCode,
            method: .POST,
            parameters: parameters,
            authenticated: false,
            completion: completion
        )
    }
    
    func verifyResetCode(email: String, code: String, completion: @escaping (Result<GenericResponse, Error>) -> Void) {
        let parameters = [
            "email": email,
            "code": code
        ]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.verifyResetCode,
            method: .POST,
            parameters: parameters,
            authenticated: false,
            completion: completion
        )
    }
    
    func resetPassword(email: String, code: String, newPassword: String, completion: @escaping (Result<GenericResponse, Error>) -> Void) {
        let parameters = [
            "email": email,
            "code": code,
            "new_password": newPassword
        ]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.resetPassword,
            method: .POST,
            parameters: parameters,
            authenticated: false,
            completion: completion
        )
    }
    
    func refreshAccessToken(refreshToken: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let parameters = ["refresh_token": refreshToken]
        
        performSecureRequest(
            endpoint: "/api/refresh-token",
            method: .POST,
            parameters: parameters,
            authenticated: false,
            completion: completion
        )
    }
    
    func logout(completion: @escaping (Result<GenericResponse, Error>) -> Void) {
        performSecureRequest(
            endpoint: "/api/logout",
            method: .POST,
            authenticated: true
        ) { (result: Result<GenericResponse, Error>) in
            // Always end session locally regardless of server response
            self.sessionManager.endSession()
            completion(result)
        }
    }
    
    // MARK: - Listings Methods
    
    func fetchListings(page: Int = 1, limit: Int = 20, completion: @escaping (Result<ListingsResponse, Error>) -> Void) {
        let parameters = [
            "page": page,
            "limit": limit
        ]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.listings,
            method: .GET,
            parameters: parameters,
            authenticated: false,
            completion: completion
        )
    }
    
    func createListing(listingData: [String: Any], completion: @escaping (Result<Property, Error>) -> Void) {
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.listings,
            method: .POST,
            parameters: listingData,
            authenticated: true,
            completion: completion
        )
    }
    
    func getListing(id: String, completion: @escaping (Result<Property, Error>) -> Void) {
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.listings)/\(id)",
            method: .GET,
            authenticated: false,
            completion: completion
        )
    }
    
    func updateListing(id: String, listingData: [String: Any], completion: @escaping (Result<Property, Error>) -> Void) {
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.listings)/\(id)",
            method: .PUT,
            parameters: listingData,
            authenticated: true,
            completion: completion
        )
    }
    
    func deleteListing(id: String, completion: @escaping (Result<GenericResponse, Error>) -> Void) {
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.listings)/\(id)",
            method: .DELETE,
            authenticated: true,
            completion: completion
        )
    }
    
    // MARK: - Favorites Methods
    
    func addToFavorites(listingId: String, completion: @escaping (Result<GenericResponse, Error>) -> Void) {
        let parameters = ["listing_id": listingId]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.favorites,
            method: .POST,
            parameters: parameters,
            authenticated: true,
            completion: completion
        )
    }
    
    func removeFromFavorites(listingId: String, completion: @escaping (Result<GenericResponse, Error>) -> Void) {
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.favorites)/\(listingId)",
            method: .DELETE,
            authenticated: true,
            completion: completion
        )
    }
    
    func getFavorites(completion: @escaping (Result<[Property], Error>) -> Void) {
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.favorites,
            method: .GET,
            authenticated: true,
            completion: completion
        )
    }
    
    func checkFavoriteStatus(listingId: String, completion: @escaping (Result<FavoriteStatusResponse, Error>) -> Void) {
        let parameters = ["listing_id": listingId]
        
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.favorites)/check",
            method: .POST,
            parameters: parameters,
            authenticated: true,
            completion: completion
        )
    }
    
    // MARK: - AI & Negotiation Methods
    
    func startAINegotiation(propertyId: String, initialMessage: String, completion: @escaping (Result<NegotiationResponse, Error>) -> Void) {
        let parameters = [
            "property_id": propertyId,
            "initial_message": initialMessage
        ]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.aiNegotiate,
            method: .POST,
            parameters: parameters,
            authenticated: true,
            completion: completion
        )
    }
    
    func sendNegotiationMessage(sessionId: String, message: String, completion: @escaping (Result<NegotiationResponse, Error>) -> Void) {
        let parameters = [
            "session_id": sessionId,
            "message": message
        ]
        
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.aiNegotiator,
            method: .POST,
            parameters: parameters,
            authenticated: true,
            completion: completion
        )
    }
    
    // MARK: - Sublease Methods
    
    func createSubleaseRequest(requestData: [String: Any], completion: @escaping (Result<SubleaseRequest, Error>) -> Void) {
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.subleaseRequest,
            method: .POST,
            parameters: requestData,
            authenticated: true,
            completion: completion
        )
    }
    
    func getSubleaseRequests(completion: @escaping (Result<[SubleaseRequest], Error>) -> Void) {
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.subleaseRequests,
            method: .GET,
            authenticated: true,
            completion: completion
        )
    }
    
    func updateSubleaseRequest(id: String, requestData: [String: Any], completion: @escaping (Result<SubleaseRequest, Error>) -> Void) {
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.subleaseRequests)/\(id)",
            method: .PUT,
            parameters: requestData,
            authenticated: true,
            completion: completion
        )
    }
    
    func deleteSubleaseRequest(id: String, completion: @escaping (Result<GenericResponse, Error>) -> Void) {
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.subleaseRequests)/\(id)",
            method: .DELETE,
            authenticated: true,
            completion: completion
        )
    }
    
    func getSubleaseMatches(requestId: String, completion: @escaping (Result<[SubleaseMatch], Error>) -> Void) {
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.subleaseMatches)/\(requestId)",
            method: .GET,
            authenticated: true,
            completion: completion
        )
    }
    
    func searchSubleases(filters: [String: Any], completion: @escaping (Result<[Property], Error>) -> Void) {
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.subleaseSearch,
            method: .GET,
            parameters: filters,
            authenticated: false,
            completion: completion
        )
    }
    
    // MARK: - Payment Methods
    
    func processPayment(paymentData: [String: Any], completion: @escaping (Result<PaymentResponse, Error>) -> Void) {
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.processPayment,
            method: .POST,
            parameters: paymentData,
            authenticated: true,
            completion: completion
        )
    }
    
    func getSubscriptionStatus(email: String, completion: @escaping (Result<SubscriptionResponse, Error>) -> Void) {
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.subscription)/\(email)",
            method: .GET,
            authenticated: true,
            completion: completion
        )
    }
    
    func getPaymentMethods(userId: String, completion: @escaping (Result<[PaymentMethod], Error>) -> Void) {
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.paymentMethods)/\(userId)",
            method: .GET,
            authenticated: true,
            completion: completion
        )
    }
    
    // MARK: - Analytics & Market Intelligence
    
    func getPropertyAnalytics(propertyId: String, completion: @escaping (Result<PropertyAnalytics, Error>) -> Void) {
        performSecureRequest(
            endpoint: "\(SecureAPIConfig.Endpoints.analytics)/property",
            method: .GET,
            parameters: ["property_id": propertyId],
            authenticated: true,
            completion: completion
        )
    }
    
    func getMarketIntelligence(location: String, completion: @escaping (Result<MarketIntelligence, Error>) -> Void) {
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.marketIntelligence,
            method: .GET,
            parameters: ["location": location],
            authenticated: true,
            completion: completion
        )
    }
    
    // MARK: - Configuration
    
    func getPublicConfig(completion: @escaping (Result<PublicConfig, Error>) -> Void) {
        performSecureRequest(
            endpoint: SecureAPIConfig.Endpoints.config,
            method: .GET,
            authenticated: false,
            completion: completion
        )
    }
    
    // MARK: - Generic Secure Request Method
    
    private func performSecureRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        parameters: [String: Any]? = nil,
        authenticated: Bool = true,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Validate session if authentication required
        if authenticated && !sessionManager.isSessionValid() {
            completion(.failure(SecureAPIError.sessionExpired))
            return
        }
        
        // Build URL
        guard let url = URL(string: "\(SecureAPIConfig.baseURL)\(endpoint)") else {
            completion(.failure(SecureAPIError.invalidURL))
            return
        }
        
        // Create request
        var request = URLRequest.create(url: url, method: method.rawValue, timeout: SecureAPIConfig.timeout)
        
        // Add authentication if required
        if authenticated {
            if let token = sessionManager.getAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                completion(.failure(SecureAPIError.noAuthToken))
                return
            }
        }
        
        // Add parameters
        if let parameters = parameters {
            if method == .GET {
                // Add as query parameters
                var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                urlComponents?.queryItems = parameters.map { key, value in
                    URLQueryItem(name: key, value: String(describing: value))
                }
                
                if let finalURL = urlComponents?.url {
                    request.url = finalURL
                }
            } else {
                // Add as JSON body
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                } catch {
                    completion(.failure(error))
                    return
                }
            }
        }
        
        // Set additional security headers
        request.setValue(keychain.getOrCreateDeviceId(), forHTTPHeaderField: "X-Device-ID")
        request.setValue(Bundle.main.bundleIdentifier ?? "unknown", forHTTPHeaderField: "X-Bundle-ID")
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue(UIDevice.current.systemVersion, forHTTPHeaderField: "X-OS-Version")
        
        // Perform request with network manager (includes retry logic)
        networkManager.performRequest(request, completion: completion)
        
        // Update session activity if authenticated
        if authenticated {
            sessionManager.updateActivity()
        }
    }
}

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Response Models
struct GenericResponse: Codable {
    let success: Bool
    let message: String?
    let data: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case success, message, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        data = try container.decodeIfPresent([String: Any].self, forKey: .data)
    }
}

struct ListingsResponse: Codable {
    let success: Bool
    let data: [Property]
    let pagination: PaginationInfo?
}

struct FavoriteStatusResponse: Codable {
    let success: Bool
    let is_favorite: Bool
}

struct NegotiationResponse: Codable {
    let success: Bool
    let session_id: String?
    let response: String?
    let offer_amount: Double?
    let status: String?
}

struct PaymentResponse: Codable {
    let success: Bool
    let transaction_id: String?
    let status: String?
}

struct SubscriptionResponse: Codable {
    let success: Bool
    let subscription: SubscriptionInfo?
}

struct PropertyAnalytics: Codable {
    let property_id: String
    let market_value: Double?
    let price_trend: String?
    let neighborhood_stats: [String: Any]?
}

struct MarketIntelligence: Codable {
    let location: String
    let average_rent: Double?
    let market_trends: [String: Any]?
    let comparable_properties: [Property]?
}

struct PublicConfig: Codable {
    let SUPABASE_URL: String
    let SUPABASE_ANON_KEY: String
    let GOOGLE_API_KEY: String?
}

struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}

struct SubscriptionInfo: Codable {
    let id: String
    let plan: String
    let status: String
    let expires_at: String?
}

struct PaymentMethod: Codable {
    let id: String
    let type: String
    let last_four: String
    let is_default: Bool
}

struct SubleaseRequest: Codable {
    let id: String
    let user_id: String
    let property_id: String?
    let title: String
    let description: String
    let move_in_date: String
    let move_out_date: String
    let max_budget: Double
    let status: String
    let created_at: String
}

struct SubleaseMatch: Codable {
    let id: String
    let request_id: String
    let property_id: String
    let match_score: Double
    let property: Property
}

// MARK: - Secure API Errors
enum SecureAPIError: LocalizedError {
    case invalidURL
    case noAuthToken
    case sessionExpired
    case networkError(String)
    case serverError(Int)
    case decodingError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noAuthToken:
            return "No authentication token available"
        case .sessionExpired:
            return "Session expired. Please log in again."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError(let message):
            return "Data parsing error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}