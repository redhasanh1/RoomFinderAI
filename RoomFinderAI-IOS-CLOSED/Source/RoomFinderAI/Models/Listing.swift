import Foundation
import CoreLocation

// MARK: - Supporting Types

enum PropertyType: String, CaseIterable, Codable {
    case apartment = "Apartment"
    case house = "House"
    case condo = "Condo"
    case townhouse = "Townhouse"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .apartment: return "building.2"
        case .house: return "house"
        case .condo: return "building"
        case .townhouse: return "house.lodge"
        }
    }
}

enum SortOption: String, CaseIterable {
    case date = "date"
    case price = "price"
    case priceHigh = "price_high"
    case location = "location"
    case bedrooms = "bedrooms"
    case distance = "distance"
    
    var displayName: String {
        switch self {
        case .date: return "Date"
        case .price: return "Price (Low to High)"
        case .priceHigh: return "Price (High to Low)"
        case .location: return "Location"
        case .bedrooms: return "Bedrooms"
        case .distance: return "Distance"
        }
    }
    
    func distance(from location1: String, to location2: String) -> String {
        return "distance"
    }
}

struct Location: Codable, Equatable {
    let address: String
    let city: String
    let state: String
    let zipCode: String
    let country: String
    let latitude: Double
    let longitude: Double
    let neighborhood: String?
    
    enum CodingKeys: String, CodingKey {
        case address, city, state, country, neighborhood
        case zipCode = "zip_code"
        case latitude, longitude
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var fullAddress: String {
        "\(address), \(city), \(state) \(zipCode)"
    }
}

/*
WebQuerySpec (from frontend/listings-api.js):
- SOURCE: "listings"
- SELECT: "*" (all columns)
- ORDER: created_at desc
- FILTERS: city (ilike), maxPrice (lte), minPrice (gte), house_type (eq), bedrooms (eq)
*/

// MARK: - Main Listing Model
struct Listing: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let price: Double
    let city: String
    let street: String
    let postalCode: String
    let houseType: String
    let bedrooms: Int
    let utilities: String
    let description: String?
    let media: [MediaItem]?
    let userEmail: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, price, city, street, description, media, bedrooms, utilities
        case houseType = "house_type"
        case userEmail = "user_email"
        case postalCode = "postalCode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Computed properties for backwards compatibility
    var propertyType: PropertyType {
        PropertyType(rawValue: houseType.capitalized) ?? .apartment
    }
    
    var images: [String]? {
        return media?.map { $0.url } // Extract URLs from MediaItem array
    }
}

// MARK: - Search and Response Types
struct ListingSearchRequest: Codable {
    let query: String?
    let location: String?
    let propertyType: String?
    let minPrice: Double?
    let maxPrice: Double?
    let bedrooms: Int?
    let bathrooms: Int?
    let radius: Double?
    let sortBy: String?
    let page: Int
    let limit: Int
    let availableDate: Date?
    let latitude: Double?
    let longitude: Double?
    let petFriendly: Bool?
    let smokingAllowed: Bool?
    
    enum CodingKeys: String, CodingKey {
        case query, location, propertyType, minPrice, maxPrice
        case bedrooms, bathrooms, radius, sortBy, page, limit
        case availableDate, latitude, longitude, petFriendly, smokingAllowed
    }
}

// Note: ListingResponse moved to SupabaseListingsService.swift to avoid conflicts

