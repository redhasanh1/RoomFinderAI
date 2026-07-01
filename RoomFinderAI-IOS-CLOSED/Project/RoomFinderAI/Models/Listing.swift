import Foundation

struct Listing: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let price: Double
    let location: String
    let address: Address?
    let roomType: RoomType
    let amenities: [String]
    let images: [String]
    let availableDate: Date?
    let contactInfo: ContactInfo
    let createdAt: Date
    let updatedAt: Date
    let ownerId: String
    let isAvailable: Bool
    let coordinates: Coordinates?
    
    init(id: String, title: String, description: String, price: Double, location: String, address: Address? = nil, roomType: RoomType, amenities: [String] = [], images: [String] = [], availableDate: Date? = nil, contactInfo: ContactInfo, createdAt: Date = Date(), updatedAt: Date = Date(), ownerId: String, isAvailable: Bool = true, coordinates: Coordinates? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.location = location
        self.address = address
        self.roomType = roomType
        self.amenities = amenities
        self.images = images
        self.availableDate = availableDate
        self.contactInfo = contactInfo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.ownerId = ownerId
        self.isAvailable = isAvailable
        self.coordinates = coordinates
    }
}

struct Address: Codable {
    let street: String
    let city: String
    let state: String
    let zipCode: String
    let country: String
    
    var fullAddress: String {
        return "\(street), \(city), \(state) \(zipCode)"
    }
}

struct ContactInfo: Codable {
    let name: String
    let email: String?
    let phone: String?
    let preferredContactMethod: ContactMethod
    
    enum ContactMethod: String, Codable, CaseIterable {
        case email = "email"
        case phone = "phone"
        case inApp = "in_app"
        
        var displayName: String {
            switch self {
            case .email:
                return "Email"
            case .phone:
                return "Phone"
            case .inApp:
                return "In-App Message"
            }
        }
    }
}

struct Coordinates: Codable {
    let latitude: Double
    let longitude: Double
}

// Extension to convert from our existing RoomListing to the new Listing model
extension RoomListing {
    func toListing(ownerId: String = "unknown") -> Listing {
        return Listing(
            id: self.id,
            title: self.title,
            description: self.description,
            price: self.price,
            location: self.location,
            roomType: .shared, // Default to shared for now
            amenities: self.amenities,
            contactInfo: ContactInfo(
                name: "Property Owner",
                email: nil,
                phone: nil,
                preferredContactMethod: .inApp
            ),
            ownerId: ownerId
        )
    }
}

// For backwards compatibility, keep the RoomListing struct
struct RoomListing {
    let id: String
    let title: String
    let description: String
    let price: Double
    let location: String
    let imageURL: String?
    let amenities: [String]
    let availableDate: Date?
    
    init(id: String, title: String, description: String, price: Double, location: String, imageURL: String? = nil, amenities: [String] = [], availableDate: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.location = location
        self.imageURL = imageURL
        self.amenities = amenities
        self.availableDate = availableDate
    }
}