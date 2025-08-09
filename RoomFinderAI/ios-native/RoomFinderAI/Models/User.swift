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
    
    var verificationStatus: VerificationStatus {
        return .pending
    }
    
    var subscriptionStatus: SubscriptionStatus {
        return .free
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

struct UserPreferences: Codable, Equatable {
    let maxBudget: Double?
    let preferredLocations: [String]
    let bedroomCount: Int?
    let bathroomCount: Int?
    let petFriendly: Bool
    let smokingAllowed: Bool
    let notifications: NotificationPreferences
    
    enum CodingKeys: String, CodingKey {
        case maxBudget = "max_budget"
        case preferredLocations = "preferred_locations"
        case bedroomCount = "bedroom_count"
        case bathroomCount = "bathroom_count"
        case petFriendly = "pet_friendly"
        case smokingAllowed = "smoking_allowed"
        case notifications
    }
}

struct NotificationPreferences: Codable, Equatable {
    let emailNotifications: Bool
    let pushNotifications: Bool
    let smsNotifications: Bool
    let newListings: Bool
    let messageAlerts: Bool
    let priceAlerts: Bool
    
    enum CodingKeys: String, CodingKey {
        case emailNotifications = "email_notifications"
        case pushNotifications = "push_notifications"
        case smsNotifications = "sms_notifications"
        case newListings = "new_listings"
        case messageAlerts = "message_alerts"
        case priceAlerts = "price_alerts"
    }
}

enum VerificationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case verified = "verified"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .verified: return "Verified"
        case .rejected: return "Rejected"
        }
    }
}

enum SubscriptionStatus: String, Codable, CaseIterable {
    case free = "free"
    case basic = "basic"
    case premium = "premium"
    case enterprise = "enterprise"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .basic: return "Basic"
        case .premium: return "Premium"
        case .enterprise: return "Enterprise"
        }
    }
}

struct UserSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }
}

struct AuthRequest: Codable, Equatable {
    let email: String
    let password: String
}

struct SignUpRequest: Codable, Equatable {
    let email: String
    let password: String
    let name: String?
    let phone: String?
    
    enum CodingKeys: String, CodingKey {
        case email, password, name, phone
    }
}

struct ForgotPasswordRequest: Codable, Equatable {
    let email: String
}

struct ResetPasswordRequest: Codable, Equatable {
    let token: String
    let newPassword: String
    
    enum CodingKeys: String, CodingKey {
        case token
        case newPassword = "new_password"
    }
}