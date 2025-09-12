import Foundation

// MARK: - Saved Listing Model
struct SavedListing: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let listingId: String
    let savedAt: Date
    let listing: Listing?
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", listingId = "listing_id"
        case savedAt = "saved_at", listing
    }
}

// MARK: - Search History Model
struct SearchHistoryItem: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let query: String
    let filters: SearchFilters?
    let resultsCount: Int
    let searchedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", query, filters
        case resultsCount = "results_count"
        case searchedAt = "searched_at"
    }
}

struct SearchFilters: Codable, Equatable {
    let propertyType: PropertyType?
    let minPrice: Double?
    let maxPrice: Double?
    let bedrooms: Int?
    let bathrooms: Int?
    let location: String?
    let radius: Double?
    
    enum CodingKeys: String, CodingKey {
        case propertyType = "property_type"
        case minPrice = "min_price"
        case maxPrice = "max_price"
        case bedrooms, bathrooms, location, radius
    }
}

// MARK: - Notification Model
struct NotificationItem: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let title: String
    let body: String
    let type: NotificationType
    let data: NotificationData?
    let isRead: Bool
    let createdAt: Date
    let readAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", title, body, type, data
        case isRead = "is_read", createdAt = "created_at", readAt = "read_at"
    }
}

enum NotificationType: String, Codable, CaseIterable {
    case newMessage = "new_message"
    case newListing = "new_listing"
    case priceUpdate = "price_update"
    case favoriteUpdate = "favorite_update"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .newMessage: return "New Message"
        case .newListing: return "New Listing"
        case .priceUpdate: return "Price Update"
        case .favoriteUpdate: return "Favorite Update"
        case .general: return "General"
        }
    }
    
    var notificationIcon: String {
        switch self {
        case .newMessage: return "message.fill"
        case .newListing: return "house.fill"
        case .priceUpdate: return "dollarsign.circle.fill"
        case .favoriteUpdate: return "heart.fill"
        case .general: return "bell.fill"
        }
    }
}

struct NotificationData: Codable, Equatable {
    let listingId: String?
    let conversationId: String?
    let url: String?
    
    enum CodingKeys: String, CodingKey {
        case listingId = "listing_id"
        case conversationId = "conversation_id"
        case url
    }
}

// MARK: - User Statistics Model
struct UserStats: Codable, Equatable {
    let userId: String
    let listingsCount: Int
    let savedListingsCount: Int
    let messagesCount: Int
    let reviewsCount: Int
    let averageRating: Double?
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case listingsCount = "listings_count"
        case savedListingsCount = "saved_listings_count"
        case messagesCount = "messages_count"
        case reviewsCount = "reviews_count"
        case averageRating = "average_rating"
        case lastUpdated = "last_updated"
    }
}

// MARK: - User Settings Model
struct UserSettings: Codable, Equatable {
    let userId: String
    let pushNotifications: Bool
    let emailNotifications: Bool
    let newListingAlerts: Bool
    let priceUpdateAlerts: Bool
    let messageAlerts: Bool
    let marketingEmails: Bool
    let theme: AppTheme
    let language: String
    let privacyLevel: PrivacyLevel
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case pushNotifications = "push_notifications"
        case emailNotifications = "email_notifications"
        case newListingAlerts = "new_listing_alerts"
        case priceUpdateAlerts = "price_update_alerts"
        case messageAlerts = "message_alerts"
        case marketingEmails = "marketing_emails"
        case theme, language, privacyLevel = "privacy_level"
        case updatedAt = "updated_at"
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum PrivacyLevel: String, Codable, CaseIterable {
    case `public` = "public"
    case friends = "friends"
    case `private` = "private"
    
    var displayName: String {
        switch self {
        case .`public`: return "Public"
        case .friends: return "Friends Only"
        case .`private`: return "Private"
        }
    }
}