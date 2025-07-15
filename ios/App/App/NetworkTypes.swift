import Foundation

// MARK: - Shared Network Types

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

struct AuthResponse: Codable {
    let success: Bool
    let token: String?
    let user: User?
    let message: String?
}

struct User: Codable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phone: String?
    let profileImage: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, email, phone, createdAt
        case firstName = "first_name"
        case lastName = "last_name"
        case profileImage = "profile_image"
    }
}

struct ChatMessage: Codable {
    let id: String
    let conversationId: String
    let senderId: String
    let receiverId: String
    let content: String
    let messageType: String
    let timestamp: String
    let isRead: Bool
    let senderName: String?
    let propertyId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, content, timestamp, propertyId
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case messageType = "message_type"
        case isRead = "is_read"
        case senderName = "sender_name"
    }
}

struct ChatConversation: Codable {
    let id: String
    let participantIds: [String]
    let propertyId: String?
    let propertyTitle: String?
    let lastMessage: String?
    let lastMessageTime: String?
    let unreadCount: Int
    let otherParticipant: User?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, createdAt
        case participantIds = "participant_ids"
        case propertyId = "property_id"
        case propertyTitle = "property_title"
        case lastMessage = "last_message"
        case lastMessageTime = "last_message_time"
        case unreadCount = "unread_count"
        case otherParticipant = "other_participant"
    }
}

struct Property: Codable {
    let id: String
    let title: String
    let description: String
    let address: String
    let city: String
    let state: String
    let zipCode: String
    let price: Double
    let bedrooms: Int
    let bathrooms: Int
    let sqft: Int
    let propertyType: String
    let images: [String]
    let amenities: [String]
    let latitude: Double?
    let longitude: Double?
    let createdAt: String
    let updatedAt: String
    var isFavorite: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, address, city, state, price, bedrooms, bathrooms, sqft, amenities, latitude, longitude, isFavorite
        case zipCode = "zip_code"
        case propertyType = "property_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case images
    }
}

struct SearchFilters: Codable {
    let minPrice: Double?
    let maxPrice: Double?
    let bedrooms: Int?
    let bathrooms: Int?
    let propertyType: String?
    let city: String?
    let amenities: [String]?
    let sortBy: String?
    let sortOrder: String?
}