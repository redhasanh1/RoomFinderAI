import Foundation
import SwiftUI

// MARK: - App Constants
struct AppConstants {
    // App Information
    static let appName = "Room Finder AI"
    static let appVersion = "1.0.0"
    static let supportEmail = "support@roomfinderai.com"
    
    // API Configuration
    struct API {
        static let baseURL = "https://api.roomfinderai.com"
        static let timeout: TimeInterval = 30.0
        static let retryCount = 3
    }
    
    // UI Constants
    struct UI {
        static let cornerRadius: CGFloat = 10.0
        static let shadowRadius: CGFloat = 5.0
        static let animationDuration: Double = 0.3
        static let tabBarHeight: CGFloat = 80.0
        static let navigationBarHeight: CGFloat = 44.0
        
        // Spacing
        static let smallSpacing: CGFloat = 8.0
        static let mediumSpacing: CGFloat = 16.0
        static let largeSpacing: CGFloat = 24.0
        static let extraLargeSpacing: CGFloat = 32.0
        
        // Padding
        static let smallPadding: CGFloat = 8.0
        static let standardPadding: CGFloat = 16.0
        static let largePadding: CGFloat = 24.0
    }
    
    // Chat Configuration
    struct Chat {
        static let maxMessageLength = 500
        static let typingIndicatorDelay: Double = 1.5
        static let messageAnimationDuration: Double = 0.2
        static let maxChatHistory = 100
    }
    
    // Listings Configuration
    struct Listings {
        static let itemsPerPage = 20
        static let maxPrice = 10000.0
        static let minPrice = 0.0
        static let maxSearchRadius = 50.0 // miles
        static let imageCompressionQuality: CGFloat = 0.8
    }
    
    // User Preferences
    struct UserDefaults {
        static let isFirstLaunch = "isFirstLaunch"
        static let userPreferences = "userPreferences"
        static let chatHistory = "chatHistory"
        static let savedListings = "savedListings"
        static let notificationSettings = "notificationSettings"
        static let darkModeEnabled = "darkModeEnabled"
        static let pushNotificationsEnabled = "pushNotificationsEnabled"
    }
    
    // Notifications
    struct Notifications {
        static let newMessage = "newMessage"
        static let listingUpdate = "listingUpdate"
        static let authStateChanged = "authStateChanged"
        static let networkStatusChanged = "networkStatusChanged"
    }
    
    // File System
    struct FileSystem {
        static let documentsDirectoryName = "RoomFinderAI"
        static let cacheDirectoryName = "Cache"
        static let imagesDirectoryName = "Images"
        static let logsDirectoryName = "Logs"
        static let maxCacheSize: Int64 = 100_000_000 // 100MB
        static let maxLogFileSize: Int64 = 10_000_000 // 10MB
    }
    
    // Validation
    struct Validation {
        static let minPasswordLength = 8
        static let maxNameLength = 50
        static let maxDescriptionLength = 1000
        static let phoneRegex = "^[+]?[1-9]?[0-9]{7,15}$"
        static let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    }
    
    // Map Configuration
    struct Map {
        static let defaultZoom: Float = 12.0
        static let maxZoom: Float = 18.0
        static let minZoom: Float = 8.0
        static let markerSize: CGFloat = 40.0
        static let clusterRadius: Double = 50.0
    }
    
    // Error Messages
    struct ErrorMessages {
        static let networkUnavailable = "Network connection is unavailable. Please check your internet connection."
        static let genericError = "An unexpected error occurred. Please try again."
        static let authenticationRequired = "Authentication is required for this action."
        static let invalidCredentials = "Invalid email or password."
        static let userNotFound = "User account not found."
        static let emailAlreadyExists = "An account with this email already exists."
        static let weakPassword = "Password must be at least 8 characters long."
        static let invalidEmail = "Please enter a valid email address."
        static let serverError = "Server error. Please try again later."
        static let timeout = "Request timed out. Please try again."
        static let unknownError = "Unknown error occurred."
    }
    
    // Success Messages
    struct SuccessMessages {
        static let accountCreated = "Account created successfully!"
        static let loginSuccessful = "Welcome back!"
        static let logoutSuccessful = "You have been logged out."
        static let profileUpdated = "Profile updated successfully."
        static let messageSent = "Message sent successfully."
        static let listingSaved = "Listing saved to favorites."
        static let listingRemoved = "Listing removed from favorites."
    }
}

// MARK: - Color Constants
extension Color {
    static let primaryColor = Color("PrimaryColor")
    static let secondaryColor = Color("SecondaryColor")
    static let accentColor = Color("AccentColor")
    static let backgroundColor = Color("BackgroundColor")
    static let surfaceColor = Color("SurfaceColor")
    static let errorColor = Color("ErrorColor")
    static let warningColor = Color("WarningColor")
    static let successColor = Color("SuccessColor")
    
    // Custom colors
    static let chatUserBubble = Color.blue
    static let chatAIBubble = Color(.systemGray5)
    static let cardBackground = Color(.systemGray6)
    static let separatorColor = Color(.separator)
    static let placeholderText = Color(.placeholderText)
}

// MARK: - Font Constants
extension Font {
    static let appTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let cardTitle = Font.system(size: 18, weight: .medium, design: .rounded)
    static let bodyText = Font.system(size: 16, weight: .regular, design: .default)
    static let captionText = Font.system(size: 14, weight: .regular, design: .default)
    static let smallText = Font.system(size: 12, weight: .regular, design: .default)
    static let buttonText = Font.system(size: 16, weight: .semibold, design: .rounded)
}

// MARK: - Animation Constants
extension Animation {
    static let gentleBounce = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let quickFade = Animation.easeInOut(duration: 0.2)
    static let standardSlide = Animation.easeInOut(duration: 0.3)
    static let slowTransition = Animation.easeInOut(duration: 0.5)
}