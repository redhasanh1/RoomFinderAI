import Foundation
import CoreLocation

struct Listing: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let price: Double
    let location: Location
    let bedrooms: Int
    let bathrooms: Int
    let squareFootage: Double?
    let propertyType: PropertyType
    let amenities: [String]
    let images: [String]
    let availableDate: Date
    let leaseTerm: Int
    let petPolicy: PetPolicy
    let smokingPolicy: SmokingPolicy
    let utilities: UtilitiesInfo
    let contactInfo: ContactInfo
    let landlordId: String
    let status: ListingStatus
    let features: [String]
    let createdAt: Date
    let updatedAt: Date
    let viewCount: Int
    let favoriteCount: Int
    let isFavorited: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, location, bedrooms, bathrooms
        case squareFootage = "square_footage"
        case propertyType = "property_type"
        case amenities, images
        case availableDate = "available_date"
        case leaseTerm = "lease_term"
        case petPolicy = "pet_policy"
        case smokingPolicy = "smoking_policy"
        case utilities
        case contactInfo = "contact_info"
        case landlordId = "landlord_id"
        case status, features
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case viewCount = "view_count"
        case favoriteCount = "favorite_count"
        case isFavorited = "is_favorited"
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

enum PropertyType: String, Codable, CaseIterable {
    case apartment = "apartment"
    case house = "house"
    case condo = "condo"
    case townhouse = "townhouse"
    case studio = "studio"
    case room = "room"
    case sublease = "sublease"
    
    var displayName: String {
        switch self {
        case .apartment: return "Apartment"
        case .house: return "House"
        case .condo: return "Condo"
        case .townhouse: return "Townhouse"
        case .studio: return "Studio"
        case .room: return "Room"
        case .sublease: return "Sublease"
        }
    }
    
    var icon: String {
        switch self {
        case .apartment: return "building.2"
        case .house: return "house"
        case .condo: return "building"
        case .townhouse: return "house.lodge"
        case .studio: return "rectangle.stack"
        case .room: return "bed.double"
        case .sublease: return "arrow.2.squarepath"
        }
    }
}

enum PetPolicy: String, Codable, CaseIterable {
    case allowed = "allowed"
    case notAllowed = "not_allowed"
    case negotiable = "negotiable"
    case catsOnly = "cats_only"
    case dogsOnly = "dogs_only"
    case deposit = "deposit_required"
    
    var displayName: String {
        switch self {
        case .allowed: return "Pets Allowed"
        case .notAllowed: return "No Pets"
        case .negotiable: return "Negotiable"
        case .catsOnly: return "Cats Only"
        case .dogsOnly: return "Dogs Only"
        case .deposit: return "Pet Deposit Required"
        }
    }
}

enum SmokingPolicy: String, Codable, CaseIterable {
    case allowed = "allowed"
    case notAllowed = "not_allowed"
    case outdoorOnly = "outdoor_only"
    case negotiable = "negotiable"
    
    var displayName: String {
        switch self {
        case .allowed: return "Smoking Allowed"
        case .notAllowed: return "No Smoking"
        case .outdoorOnly: return "Outdoor Only"
        case .negotiable: return "Negotiable"
        }
    }
}

struct UtilitiesInfo: Codable, Equatable {
    let electricity: Bool
    let water: Bool
    let gas: Bool
    let internet: Bool
    let cable: Bool
    let heating: Bool
    let airConditioning: Bool
    let trash: Bool
    let sewer: Bool
    let additionalCosts: Double?
    
    enum CodingKeys: String, CodingKey {
        case electricity, water, gas, internet, cable, heating, trash, sewer
        case airConditioning = "air_conditioning"
        case additionalCosts = "additional_costs"
    }
}

struct ContactInfo: Codable, Equatable {
    let name: String
    let email: String
    let phone: String?
    let preferredContact: ContactMethod
    let responseTime: String?
    
    enum CodingKeys: String, CodingKey {
        case name, email, phone
        case preferredContact = "preferred_contact"
        case responseTime = "response_time"
    }
}

enum ContactMethod: String, Codable, CaseIterable {
    case email = "email"
    case phone = "phone"
    case text = "text"
    case app = "app"
    
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .phone: return "Phone"
        case .text: return "Text"
        case .app: return "In-App"
        }
    }
}

enum ListingStatus: String, Codable, CaseIterable {
    case active = "active"
    case pending = "pending"
    case rented = "rented"
    case withdrawn = "withdrawn"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .pending: return "Pending"
        case .rented: return "Rented"
        case .withdrawn: return "Withdrawn"
        case .expired: return "Expired"
        }
    }
}

struct ListingSearchRequest: Codable {
    let query: String?
    let location: String?
    let minPrice: Double?
    let maxPrice: Double?
    let bedrooms: Int?
    let bathrooms: Int?
    let propertyType: PropertyType?
    let petFriendly: Bool?
    let smokingAllowed: Bool?
    let availableDate: Date?
    let radius: Double?
    let latitude: Double?
    let longitude: Double?
    let sortBy: SortOption?
    let page: Int
    let limit: Int
    
    enum CodingKeys: String, CodingKey {
        case query, location
        case minPrice = "min_price"
        case maxPrice = "max_price"
        case bedrooms, bathrooms
        case propertyType = "property_type"
        case petFriendly = "pet_friendly"
        case smokingAllowed = "smoking_allowed"
        case availableDate = "available_date"
        case radius, latitude, longitude
        case sortBy = "sort_by"
        case page, limit
    }
}

enum SortOption: String, Codable, CaseIterable {
    case price = "price"
    case date = "date"
    case distance = "distance"
    case bedrooms = "bedrooms"
    case popularity = "popularity"
    
    var displayName: String {
        switch self {
        case .price: return "Price"
        case .date: return "Date"
        case .distance: return "Distance"
        case .bedrooms: return "Bedrooms"
        case .popularity: return "Popularity"
        }
    }
}

struct ListingResponse: Codable {
    let listings: [Listing]
    let totalCount: Int
    let page: Int
    let totalPages: Int
    let hasNextPage: Bool
    let hasPreviousPage: Bool
    
    enum CodingKeys: String, CodingKey {
        case listings
        case totalCount = "total_count"
        case page
        case totalPages = "total_pages"
        case hasNextPage = "has_next_page"
        case hasPreviousPage = "has_previous_page"
    }
}