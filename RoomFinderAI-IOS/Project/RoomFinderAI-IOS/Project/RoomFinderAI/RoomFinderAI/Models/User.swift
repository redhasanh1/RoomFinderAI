import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let profileImage: String?
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties for backwards compatibility
    var name: String? {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        }
        return firstName ?? lastName
    }
    
    var avatar: String? {
        return profileImage
    }
    
    // Simple verification status for demo
    var verificationStatus: VerificationStatus {
        return .verified // Always verified for demo
    }
    
    // Simple subscription status for demo
    var subscriptionStatus: SubscriptionStatus {
        return .free // Always free for demo
    }
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case profileImage = "profile_image"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// Simple verification status enum
enum VerificationStatus {
    case verified
    case unverified
    case pending
    
    var displayName: String {
        switch self {
        case .verified:
            return "Verified"
        case .unverified:
            return "Unverified"
        case .pending:
            return "Pending"
        }
    }
}

enum SubscriptionStatus {
    case free
    case premium
    case pro
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .premium:
            return "Premium"
        case .pro:
            return "Pro"
        }
    }
}

// Simplified models for basic auth

struct SimpleAuthRequest: Codable, Equatable {
    let email: String
    let password: String
}

struct SimpleSignUpRequest: Codable, Equatable {
    let email: String
    let password: String
    let firstName: String?
    let lastName: String?
}