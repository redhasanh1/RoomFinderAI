import Foundation

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    // TODO: Re-enable when Secrets module is properly imported
    private let baseURL = URL(string: "https://fkktwhjybuflxqzopaex.supabase.co")!
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"
    private let networkManager = NetworkManager.shared
    
    private init() {}
    
    private var defaultHeaders: [String: String] {
        [
            "apikey": anonKey,
            "Authorization": "Bearer \(anonKey)"
        ]
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String) async throws -> AuthResponse {
        let url = baseURL.appendingPathComponent("auth/v1/signup")
        let body = SignUpRequest(email: email, password: password)
        let bodyData = try JSONEncoder().encode(body)
        
        return try await networkManager.performRequest(
            url: url,
            method: .POST,
            body: bodyData,
            headers: defaultHeaders,
            responseType: AuthResponse.self
        )
    }
    
    func signIn(email: String, password: String) async throws -> AuthResponse {
        let url = baseURL.appendingPathComponent("auth/v1/token?grant_type=password")
        let body = SignInRequest(email: email, password: password)
        let bodyData = try JSONEncoder().encode(body)
        
        return try await networkManager.performRequest(
            url: url,
            method: .POST,
            body: bodyData,
            headers: defaultHeaders,
            responseType: AuthResponse.self
        )
    }
    
    func signOut(accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("auth/v1/logout")
        var headers = defaultHeaders
        headers["Authorization"] = "Bearer \(accessToken)"
        
        let _: EmptyResponse = try await networkManager.performRequest(
            url: url,
            method: .POST,
            headers: headers,
            responseType: EmptyResponse.self
        )
    }
    
    // MARK: - Database Operations
    
    func fetchListings() async throws -> [RoomListingData] {
        let url = baseURL.appendingPathComponent("rest/v1/room_listings")
        
        return try await networkManager.performRequest(
            url: url,
            method: .GET,
            headers: defaultHeaders,
            responseType: [RoomListingData].self
        )
    }
    
    func createListing(_ listing: CreateListingRequest, accessToken: String) async throws -> RoomListingData {
        let url = baseURL.appendingPathComponent("rest/v1/room_listings")
        let bodyData = try JSONEncoder().encode(listing)
        var headers = defaultHeaders
        headers["Authorization"] = "Bearer \(accessToken)"
        
        return try await networkManager.performRequest(
            url: url,
            method: .POST,
            body: bodyData,
            headers: headers,
            responseType: RoomListingData.self
        )
    }
}

// MARK: - Request Models

struct SignUpRequest: Codable {
    let email: String
    let password: String
}

struct SignInRequest: Codable {
    let email: String
    let password: String
}

struct CreateListingRequest: Codable {
    let title: String
    let description: String
    let price: Double
    let location: String
    let amenities: [String]
}

// MARK: - Response Models

struct AuthResponse: Codable {
    let accessToken: String?
    let tokenType: String?
    let expiresIn: Int?
    let user: UserData?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

struct UserData: Codable {
    let id: String
    let email: String
    let emailVerified: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case emailVerified = "email_verified"
    }
}

struct RoomListingData: Codable {
    let id: String
    let title: String
    let description: String
    let price: Double
    let location: String
    let amenities: [String]?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case price
        case location
        case amenities
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct EmptyResponse: Codable {}