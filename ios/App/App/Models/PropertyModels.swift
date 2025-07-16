import Foundation
import SwiftUI

// MARK: - Property Models

struct Property: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let price: Double
    let location: String
    let category: String
    let bedrooms: Int?
    let bathrooms: Int?
    let imageUrl: String?
    let featured: Bool?
    let createdAt: String?
    let userEmail: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, location, category, bedrooms, bathrooms, featured
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case userEmail = "user_email"
    }
    
    // Computed properties for UI
    var formattedPrice: String {
        return "$\(Int(price))/month"
    }
    
    var roomInfo: String {
        let beds = bedrooms ?? 0
        let baths = bathrooms ?? 0
        return "\(beds) bed • \(baths) bath"
    }
    
    var categoryIcon: String {
        switch category.lowercased() {
        case "apartment": return "building.2"
        case "house": return "house"
        case "condo": return "building"
        case "studio": return "rectangle"
        default: return "house"
        }
    }
}

// MARK: - Search Filters

struct SearchFilters {
    var category: String?
    var minPrice: Double?
    var maxPrice: Double?
    var bedrooms: Int?
    var bathrooms: Int?
    var location: String?
    var searchQuery: String?
    
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let category = category { dict["category"] = category }
        if let minPrice = minPrice { dict["minPrice"] = minPrice }
        if let maxPrice = maxPrice { dict["maxPrice"] = maxPrice }
        if let bedrooms = bedrooms { dict["bedrooms"] = bedrooms }
        if let bathrooms = bathrooms { dict["bathrooms"] = bathrooms }
        if let location = location { dict["location"] = location }
        if let searchQuery = searchQuery { dict["searchQuery"] = searchQuery }
        return dict
    }
}

// MARK: - User Models

struct User: Codable {
    let id: String?
    let email: String
    let firstName: String?
    let lastName: String?
    let profileImage: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case profileImage = "profile_image"
    }
    
    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        } else if let first = firstName {
            return first
        } else {
            return email
        }
    }
}

// MARK: - Chat Models

struct Conversation: Identifiable, Codable {
    let id: String
    let listingId: String?
    let senderEmail: String
    let receiverEmail: String
    let lastMessageAt: String?
    let listing: Property?
    
    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case senderEmail = "sender_email"
        case receiverEmail = "receiver_email"
        case lastMessageAt = "last_message_at"
        case listing
    }
}

struct Message: Identifiable, Codable {
    let id: String
    let conversationId: String
    let senderEmail: String
    let content: String
    let messageType: String
    let createdAt: String
    let read: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderEmail = "sender_email"
        case content
        case messageType = "message_type"
        case createdAt = "created_at"
        case read
    }
    
    var isImage: Bool {
        return messageType == "image"
    }
    
    var isFile: Bool {
        return messageType == "file"
    }
}

// MARK: - AI Models

struct AISearchResult {
    let recommendation: String
    let listings: [Property]
    let searchQuery: String
}

struct NegotiationAdvice {
    let advice: String
    let listing: Property
    let context: [String: Any]
}

// MARK: - Payment Models

struct SubscriptionStatus: Codable {
    let status: String
    let type: String
    let planId: String?
    let expiresAt: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case status, type
        case planId = "plan_id"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
    
    var isActive: Bool {
        return status == "active"
    }
    
    var isPremium: Bool {
        return type == "premium" || type == "enterprise"
    }
}