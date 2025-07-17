import Foundation

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let name: String?
    let avatar: String?
    let phone: String?
    let location: String?
    let preferences: UserPreferences?
    let createdAt: Date
    let updatedAt: Date
    let verificationStatus: VerificationStatus
    let subscriptionStatus: SubscriptionStatus
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, avatar, phone, location, preferences
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case verificationStatus = "verification_status"
        case subscriptionStatus = "subscription_status"
    }
}

struct UserPreferences: Codable {
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

struct NotificationPreferences: Codable {
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

struct UserSession: Codable {
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

struct AuthRequest: Codable {
    let email: String
    let password: String
}

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let name: String?
    let phone: String?
    
    enum CodingKeys: String, CodingKey {
        case email, password, name, phone
    }
}

struct ForgotPasswordRequest: Codable {
    let email: String
}

struct ResetPasswordRequest: Codable {
    let token: String
    let newPassword: String
    
    enum CodingKeys: String, CodingKey {
        case token
        case newPassword = "new_password"
    }
}