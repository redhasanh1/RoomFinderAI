import Foundation
import CoreLocation

// MARK: - Supporting Types
enum PropertyType: String, CaseIterable, Codable {
    case apartment = "apartment"
    case house = "house"
    case condo = "condo"
    case studio = "studio"
    case townhouse = "townhouse"
    case room = "room"
    
    var displayName: String {
        switch self {
        case .apartment: return "Apartment"
        case .house: return "House"
        case .condo: return "Condo"
        case .studio: return "Studio"
        case .townhouse: return "Townhouse"
        case .room: return "Room"
        }
    }
    
    var icon: String {
        switch self {
        case .apartment: return "building.2"
        case .house: return "house"
        case .condo: return "building"
        case .studio: return "bed.double"
        case .townhouse: return "house.lodge"
        case .room: return "door.left.hand.open"
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

// MARK: - Main Listing Model
struct Listing: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String?
    let price: Int
    let city: String
    let street: String
    let postalCode: String
    let houseType: String
    let bedrooms: Int
    let utilities: String
    let media: [String]
    let userEmail: String
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties for backwards compatibility
    var propertyType: PropertyType {
        PropertyType(rawValue: houseType.lowercased()) ?? .apartment
    }
    
    var location: Location {
        Location(
            address: "\(street), \(city)",
            city: city,
            state: "",
            zipCode: postalCode,
            country: "Canada",
            latitude: 43.6532 + Double.random(in: -0.1...0.1), // Mock Toronto coordinates
            longitude: -79.3832 + Double.random(in: -0.1...0.1),
            neighborhood: nil
        )
    }
    
    var images: [String] {
        return media
    }
    
    var imageURLs: [String] {
        return media
    }
    
    var isActive: Bool {
        return true // For now, assume all listings are active
    }
    
    var availableDate: Date {
        return Date() // Default to current date
    }
    
    var bathrooms: Int {
        return 1 // Default to 1 bathroom
    }
    
    var isFavorited: Bool {
        // This will be determined by checking favorites table
        return false
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, city, street, bedrooms, utilities, media
        case postalCode = "postal_code"
        case houseType = "house_type"
        case userEmail = "user_email"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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

