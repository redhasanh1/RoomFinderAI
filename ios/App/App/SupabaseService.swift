import Foundation
import UIKit

// MARK: - Configuration
struct SupabaseConfig {
    // Static configuration - will be enhanced with EnvironmentManager once added to project
    static let url = "https://roomfinder-ai-negotiator-production.up.railway.app"
    static let apiPath = "/api"
    
    // Direct Supabase configuration
    static let supabaseURL = "https://zmxyysauqtfkvntgtjsm.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpteHl5c2F1cXRma3ZudGd0anNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTc3OTQsImV4cCI6MjA1MjUzMzc5NH0.F6M7G-fxnRDnKzWAWgO4y0Z7IuKIDaecvSUBz8aVeQM"
    
    struct Endpoints {
        static let config = "/config"
        static let listings = "/listings"
        static let users = "/users"
        static let conversations = "/conversations"
        static let messages = "/messages"
        static let aiChats = "/ai-chats"
        static let auth = "/auth"
        static let negotiate = "/ai/negotiate"
        static let analytics = "/analytics"
    }
}

// MARK: - Data Models
struct SupabaseListing: Codable {
    let id: String
    let title: String
    let price: Int
    let city: String
    let street: String
    let postalCode: String
    let houseType: String
    let bedrooms: Int
    let utilities: String?
    let description: String?
    let media: [String]
    let userEmail: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, price, city, street, bedrooms, utilities, description, media
        case postalCode = "postal_code"
        case houseType = "house_type"
        case userEmail = "user_email"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Convert to our Property model
    func toProperty() -> Property {
        return Property(
            id: id,
            title: title,
            description: description ?? "",
            address: street,
            city: city,
            state: "", // Not in Supabase schema
            zipCode: postalCode,
            price: Double(price),
            bedrooms: bedrooms,
            bathrooms: 1, // Default, not in schema
            sqft: 1000, // Default, not in schema
            propertyType: houseType,
            images: media.isEmpty ? [] : media,
            amenities: utilities != nil ? [utilities!] : [],
            latitude: 0.0, // Would need geocoding
            longitude: 0.0, // Would need geocoding
            createdAt: createdAt,
            updatedAt: updatedAt,
            isFavorite: false
        )
    }
}

struct SupabaseUser: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let profileImage: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case profileImage = "profile_image"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Convert to our User model
    func toUser() -> User {
        return User(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            phone: nil,
            profileImage: profileImage,
            createdAt: createdAt
        )
    }
}

struct SupabaseSearchFilters {
    var city: String?
    var maxPrice: Int?
    var minPrice: Int?
    var houseType: String?
    var bedrooms: Int?
    var offset: Int = 0
    var limit: Int = 20
}

struct SupabaseResponse<T: Codable>: Codable {
    let data: T?
    let error: String?
    let count: Int?
}

// MARK: - Supabase Service
class SupabaseService {
    static let shared = SupabaseService()
    
    private var supabaseUrl: String?
    private var supabaseKey: String?
    private var isConfigured = false
    
    private init() {}
    
    // MARK: - Configuration
    func configure() async throws {
        guard !isConfigured else { return }
        
        let configUrl = "\(SupabaseConfig.url)\(SupabaseConfig.apiPath)\(SupabaseConfig.Endpoints.config)"
        
        guard let url = URL(string: configUrl) else {
            throw APIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct ConfigResponse: Codable {
            let SUPABASE_URL: String
            let SUPABASE_ANON_KEY: String
            let GOOGLE_API_KEY: String?
        }
        
        let config = try JSONDecoder().decode(ConfigResponse.self, from: data)
        
        self.supabaseUrl = config.SUPABASE_URL
        self.supabaseKey = config.SUPABASE_ANON_KEY
        self.isConfigured = true
    }
    
    // MARK: - Generic Request Method
    private func makeSupabaseRequest<T: Codable>(
        table: String,
        method: HTTPMethod = .GET,
        parameters: [String: Any]? = nil,
        filters: [String: String]? = nil,
        responseType: T.Type
    ) async throws -> T {
        
        try await configure()
        
        guard let supabaseUrl = supabaseUrl,
              let supabaseKey = supabaseKey else {
            throw APIError.notConfigured
        }
        
        var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/\(table)")!
        
        // Add filters as query parameters
        if let filters = filters {
            var queryItems: [URLQueryItem] = []
            
            for (key, value) in filters {
                queryItems.append(URLQueryItem(name: key, value: value))
            }
            
            // Add select parameter for GET requests
            if method == .GET {
                queryItems.append(URLQueryItem(name: "select", value: "*"))
            }
            
            urlComponents.queryItems = queryItems
        } else if method == .GET {
            urlComponents.queryItems = [URLQueryItem(name: "select", value: "*")]
        }
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Add mobile-specific headers
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("RoomFinderAI/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(SupabaseConfig.url, forHTTPHeaderField: "Origin")
        
        // Add body for POST/PUT requests
        if let parameters = parameters, method != .GET {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Supabase Error: \(errorString)")
                }
                throw APIError.serverError(httpResponse.statusCode)
            }
        }
        
        // For array responses, decode directly
        if T.self == [SupabaseListing].self {
            return try JSONDecoder().decode(T.self, from: data)
        }
        
        // For single object responses
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Listings Methods
    func fetchListings(filters: SupabaseSearchFilters? = nil) async throws -> [SupabaseListing] {
        var queryFilters: [String: String] = [:]
        
        if let filters = filters {
            // Order by created_at descending
            queryFilters["order"] = "created_at.desc"
            
            // Apply filters
            if let city = filters.city, !city.isEmpty {
                queryFilters["city"] = "ilike.*\(city)*"
            }
            
            if let maxPrice = filters.maxPrice {
                queryFilters["price"] = "lte.\(maxPrice)"
            }
            
            if let minPrice = filters.minPrice {
                queryFilters["price"] = "gte.\(minPrice)"
            }
            
            if let houseType = filters.houseType, !houseType.isEmpty {
                queryFilters["house_type"] = "eq.\(houseType)"
            }
            
            if let bedrooms = filters.bedrooms {
                queryFilters["bedrooms"] = "eq.\(bedrooms)"
            }
            
            // Pagination
            if filters.limit > 0 {
                queryFilters["limit"] = "\(filters.limit)"
            }
            
            if filters.offset > 0 {
                queryFilters["offset"] = "\(filters.offset)"
            }
        } else {
            queryFilters["order"] = "created_at.desc"
            queryFilters["limit"] = "20"
        }
        
        return try await makeSupabaseRequest(
            table: "listings",
            filters: queryFilters,
            responseType: [SupabaseListing].self
        )
    }
    
    func createListing(_ listing: [String: Any]) async throws -> SupabaseListing {
        let response: [SupabaseListing] = try await makeSupabaseRequest(
            table: "listings",
            method: .POST,
            parameters: listing,
            responseType: [SupabaseListing].self
        )
        
        guard let createdListing = response.first else {
            throw APIError.invalidResponse
        }
        
        return createdListing
    }
    
    func searchListings(query: String) async throws -> [SupabaseListing] {
        let queryFilters: [String: String] = [
            "or": "(title.ilike.*\(query)*,city.ilike.*\(query)*,description.ilike.*\(query)*)",
            "order": "created_at.desc",
            "limit": "50"
        ]
        
        return try await makeSupabaseRequest(
            table: "listings",
            filters: queryFilters,
            responseType: [SupabaseListing].self
        )
    }
    
    // MARK: - User Methods
    func fetchUser(email: String) async throws -> SupabaseUser {
        let queryFilters: [String: String] = [
            "email": "eq.\(email)"
        ]
        
        let users: [SupabaseUser] = try await makeSupabaseRequest(
            table: "users",
            filters: queryFilters,
            responseType: [SupabaseUser].self
        )
        
        guard let user = users.first else {
            throw APIError.userNotFound
        }
        
        return user
    }
    
    func createUser(_ userData: [String: Any]) async throws -> SupabaseUser {
        let response: [SupabaseUser] = try await makeSupabaseRequest(
            table: "users",
            method: .POST,
            parameters: userData,
            responseType: [SupabaseUser].self
        )
        
        guard let createdUser = response.first else {
            throw APIError.invalidResponse
        }
        
        return createdUser
    }
    
    // MARK: - Helper Methods
    func validateConnection() async -> Bool {
        do {
            try await configure()
            return isConfigured
        } catch {
            print("Supabase connection validation failed: \(error)")
            return false
        }
    }
}

// MARK: - HTTP Methods

// MARK: - Errors
extension APIError {
    static let notConfigured = APIError.custom("Supabase not configured")
    static let userNotFound = APIError.custom("User not found")
}