import Foundation

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let name: String?
    let createdAt: Date?
    let profileImageURL: String?
    let preferences: UserPreferences?
    
    init(id: String, email: String, name: String? = nil, createdAt: Date? = nil, profileImageURL: String? = nil, preferences: UserPreferences? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.createdAt = createdAt
        self.profileImageURL = profileImageURL
        self.preferences = preferences
    }
}

struct UserPreferences: Codable {
    let maxBudget: Double?
    let preferredLocation: String?
    let preferredAmenities: [String]
    let roomType: RoomType?
    let moveInDate: Date?
    let notifications: NotificationSettings
    
    init(maxBudget: Double? = nil, preferredLocation: String? = nil, preferredAmenities: [String] = [], roomType: RoomType? = nil, moveInDate: Date? = nil, notifications: NotificationSettings = NotificationSettings()) {
        self.maxBudget = maxBudget
        self.preferredLocation = preferredLocation
        self.preferredAmenities = preferredAmenities
        self.roomType = roomType
        self.moveInDate = moveInDate
        self.notifications = notifications
    }
}

struct NotificationSettings: Codable {
    let newListings: Bool
    let priceDrops: Bool
    let messages: Bool
    let marketUpdates: Bool
    
    init(newListings: Bool = true, priceDrops: Bool = true, messages: Bool = true, marketUpdates: Bool = false) {
        self.newListings = newListings
        self.priceDrops = priceDrops
        self.messages = messages
        self.marketUpdates = marketUpdates
    }
}

enum RoomType: String, Codable, CaseIterable {
    case studio = "studio"
    case oneBedroom = "1_bedroom"
    case twoBedroom = "2_bedroom"
    case threeBedroom = "3_bedroom"
    case shared = "shared"
    case entirePlace = "entire_place"
    
    var displayName: String {
        switch self {
        case .studio:
            return "Studio"
        case .oneBedroom:
            return "1 Bedroom"
        case .twoBedroom:
            return "2 Bedroom"
        case .threeBedroom:
            return "3+ Bedroom"
        case .shared:
            return "Shared Room"
        case .entirePlace:
            return "Entire Place"
        }
    }
}