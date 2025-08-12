import Foundation
import Supabase
import PostgREST

enum RealtimeChange<T> {
    case insert(T)
    case update(T)
    case delete(T)
}

enum ListingsServiceError: LocalizedError {
    case networkTimeout
    case serverError(String)
    case decodingError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkTimeout:
            return "Network timeout. Please check your connection and try again."
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let message):
            return "Data parsing error: \(message)"
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
}

final class ListingsService: ObservableObject {
    private let client = SupabaseConfig.client
    private let maxRetries = 2
    private let retryDelay: TimeInterval = 1.0
    
    func fetchListings(page: Int, pageSize: Int = 20, filters: ListingsFilter = .empty) async throws -> [Listing] {
        return try await withRetry {
            let from = page * pageSize
            let to = from + pageSize - 1
            
            var query = client
                .from("listings")
                .select("*")
                .order("created_at", ascending: false)
                .range(from: from, to: to)
            
            if let city = filters.city, !city.isEmpty {
                query = query.eq("city", value: city)
            }
            
            if let maxPrice = filters.maxPrice {
                query = query.lte("price", value: maxPrice)
            }
            
            if let minPrice = filters.minPrice {
                query = query.gte("price", value: minPrice)
            }
            
            if let houseType = filters.houseType, !houseType.isEmpty {
                query = query.eq("house_type", value: houseType)
            }
            
            if let bedrooms = filters.bedrooms {
                query = query.eq("bedrooms", value: bedrooms)
            }
            
            if let search = filters.search, !search.isEmpty {
                query = query.eq("title", value: search)
            }
            
            let response: [Listing] = try await query.execute().value
            return response
        }
    }
    
    func fetchListing(id: UUID) async throws -> Listing? {
        let response: Listing = try await client
            .from("listings")
            .select("*")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        return response
    }
    
    func createListing(_ listing: CreateListingRequest) async throws -> Listing {
        let response: Listing = try await client
            .from("listings")
            .insert(listing)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    func updateListing(id: UUID, updates: UpdateListingRequest) async throws -> Listing {
        let response: Listing = try await client
            .from("listings")
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    func deleteListing(id: UUID) async throws {
        try await client
            .from("listings")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func getListingsByUser(_ userEmail: String) async throws -> [Listing] {
        let response: [Listing] = try await client
            .from("listings")
            .select("*")
            .eq("user_email", value: userEmail)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    private func withRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    // Exponential backoff
                    let delay = retryDelay * Double(1 << attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? ListingsServiceError.unknownError("Max retries exceeded")
    }
}

struct CreateListingRequest: Codable {
    let title: String
    let price: Int
    let city: String
    let street: String
    let postalCode: String
    let houseType: String
    let bedrooms: Int
    let utilities: String
    let description: String?
    let media: [String]
    let userEmail: String
    
    enum CodingKeys: String, CodingKey {
        case title, price, city, street, bedrooms, utilities, description, media
        case postalCode = "postal_code"
        case houseType = "house_type"
        case userEmail = "user_email"
    }
}

struct UpdateListingRequest: Codable {
    let title: String?
    let price: Int?
    let city: String?
    let street: String?
    let postalCode: String?
    let houseType: String?
    let bedrooms: Int?
    let utilities: String?
    let description: String?
    let media: [String]?
    
    enum CodingKeys: String, CodingKey {
        case title, price, city, street, bedrooms, utilities, description, media
        case postalCode = "postal_code"
        case houseType = "house_type"
    }
}