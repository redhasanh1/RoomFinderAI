import Foundation
import Combine

// MARK: - Error Severity
enum ErrorSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Error Context
struct ErrorContext {
    let timestamp: Date
    let additionalInfo: [String: Any]
    let userID: String?
    let sessionID: String?
    
    init(
        timestamp: Date = Date(),
        additionalInfo: [String: Any] = [:],
        userID: String? = nil,
        sessionID: String? = nil
    ) {
        self.timestamp = timestamp
        self.additionalInfo = additionalInfo
        self.userID = userID
        self.sessionID = sessionID
    }
}

// MARK: - Specific Error Types
enum NetworkError: Error, LocalizedError {
    case noConnection
    case timeout
    case invalidResponse
    case serverError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .noConnection: return "No internet connection"
        case .timeout: return "Request timed out"
        case .invalidResponse: return "Invalid response from server"
        case .serverError(let code): return "Server error: \(code)"
        case .decodingError: return "Data decoding error"
        }
    }
}

enum SupabaseError: Error, LocalizedError {
    case clientError(String)
    case authenticationFailed
    case connectionError
    case queryError(String)
    
    var errorDescription: String? {
        switch self {
        case .clientError(let message): return "Supabase client error: \(message)"
        case .authenticationFailed: return "Authentication failed"
        case .connectionError: return "Connection to Supabase failed"
        case .queryError(let message): return "Query error: \(message)"
        }
    }
}

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case userNotFound
    case accountDisabled
    case tokenExpired
    case emailNotVerified
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid email or password"
        case .userNotFound: return "User not found"
        case .accountDisabled: return "Account has been disabled"
        case .tokenExpired: return "Session expired"
        case .emailNotVerified: return "Email not verified"
        }
    }
}

enum PaymentError: Error, LocalizedError {
    case cardDeclined
    case insufficientFunds
    case invalidCard
    case processingError
    
    var errorDescription: String? {
        switch self {
        case .cardDeclined: return "Card was declined"
        case .insufficientFunds: return "Insufficient funds"
        case .invalidCard: return "Invalid card information"
        case .processingError: return "Payment processing error"
        }
    }
}

enum AIError: Error, LocalizedError {
    case apiKeyMissing
    case rateLimitExceeded
    case invalidRequest
    case modelError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing: return "AI API key is missing"
        case .rateLimitExceeded: return "API rate limit exceeded"
        case .invalidRequest: return "Invalid AI request"
        case .modelError(let message): return "AI model error: \(message)"
        }
    }
}

enum ValidationError: Error, LocalizedError {
    case invalidEmail
    case passwordTooShort
    case missingRequiredField(String)
    case invalidInput(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "Invalid email format"
        case .passwordTooShort: return "Password must be at least 8 characters"
        case .missingRequiredField(let field): return "\(field) is required"
        case .invalidInput(let message): return "Invalid input: \(message)"
        }
    }
}

// MARK: - Main App Error
enum AppError: Error, LocalizedError {
    case networkError(NetworkError)
    case supabaseError(SupabaseError)
    case authError(AuthError)
    case paymentError(PaymentError)
    case aiError(AIError)
    case validationError(ValidationError)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return error.localizedDescription
        case .supabaseError(let error):
            return error.localizedDescription
        case .authError(let error):
            return error.localizedDescription
        case .paymentError(let error):
            return error.localizedDescription
        case .aiError(let error):
            return error.localizedDescription
        case .validationError(let error):
            return error.localizedDescription
        case .unknownError(let message):
            return message
        }
    }
    
    var errorCode: String {
        switch self {
        case .networkError(let error):
            return error.code
        case .supabaseError(let error):
            return error.code
        case .authError(let error):
            return error.code
        case .paymentError(let error):
            return error.code
        case .aiError(let error):
            return error.code
        case .validationError(let error):
            return error.code
        case .unknownError:
            return "UNKNOWN_ERROR"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .networkError(let error):
            return error.severity
        case .supabaseError(let error):
            return error.severity
        case .authError(let error):
            return error.severity
        case .paymentError(let error):
            return error.severity
        case .aiError(let error):
            return error.severity
        case .validationError(let error):
            return error.severity
        case .unknownError:
            return .high
        }
    }
}

// MARK: - Network Errors
enum NetworkError: Error, LocalizedError {
    case noInternetConnection
    case timeoutError
    case serverError(Int)
    case invalidResponse
    case parseError
    case rateLimitExceeded
    case unauthorized
    case forbidden
    case notFound
    case internalServerError
    case requestFailed(String)
    case badRequest
    case hostNotFound
    
    var localizedDescription: String {
        switch self {
        case .noInternetConnection:
            return "No internet connection. Please check your network settings."
        case .timeoutError:
            return "Request timed out. Please try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .invalidResponse:
            return "Invalid response from server."
        case .parseError:
            return "Failed to parse server response."
        case .rateLimitExceeded:
            return "Too many requests. Please wait and try again."
        case .unauthorized:
            return "Unauthorized access. Please log in again."
        case .forbidden:
            return "Access denied. You don't have permission to perform this action."
        case .notFound:
            return "The requested resource was not found."
        case .internalServerError:
            return "Internal server error. Please try again later."
        case .requestFailed(let message):
            return "Request failed: \(message)"
        case .badRequest:
            return "Bad request. Please check your input and try again."
        case .hostNotFound:
            return "Host not found. Please check your connection."
        }
    }
    
    var code: String {
        switch self {
        case .noInternetConnection: return "NETWORK_NO_CONNECTION"
        case .timeoutError: return "NETWORK_TIMEOUT"
        case .serverError(let code): return "NETWORK_SERVER_ERROR_\(code)"
        case .invalidResponse: return "NETWORK_INVALID_RESPONSE"
        case .parseError: return "NETWORK_PARSE_ERROR"
        case .rateLimitExceeded: return "NETWORK_RATE_LIMIT"
        case .unauthorized: return "NETWORK_UNAUTHORIZED"
        case .forbidden: return "NETWORK_FORBIDDEN"
        case .notFound: return "NETWORK_NOT_FOUND"
        case .internalServerError: return "NETWORK_INTERNAL_ERROR"
        case .requestFailed: return "NETWORK_REQUEST_FAILED"
        case .badRequest: return "NETWORK_BAD_REQUEST"
        case .hostNotFound: return "NETWORK_HOST_NOT_FOUND"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .noInternetConnection, .timeoutError, .rateLimitExceeded:
            return .medium
        case .serverError, .internalServerError:
            return .high
        case .unauthorized, .forbidden:
            return .high
        case .invalidResponse, .parseError, .notFound:
            return .low
        case .requestFailed, .badRequest:
            return .medium
        case .hostNotFound:
            return .medium
        }
    }
}

// MARK: - Supabase Errors
enum SupabaseError: Error, LocalizedError {
    case databaseError(String)
    case queryError(String)
    case insertError(String)
    case updateError(String)
    case deleteError(String)
    case authenticationError(String)
    case permissionDenied
    case connectionError
    case rateLimitExceeded
    
    var localizedDescription: String {
        switch self {
        case .databaseError(let message):
            return "Database error: \(message)"
        case .queryError(let message):
            return "Query error: \(message)"
        case .insertError(let message):
            return "Failed to create record: \(message)"
        case .updateError(let message):
            return "Failed to update record: \(message)"
        case .deleteError(let message):
            return "Failed to delete record: \(message)"
        case .authenticationError(let message):
            return "Authentication error: \(message)"
        case .permissionDenied:
            return "Permission denied. You don't have access to this resource."
        case .connectionError:
            return "Failed to connect to database."
        case .rateLimitExceeded:
            return "Database rate limit exceeded. Please try again later."
        }
    }
    
    var code: String {
        switch self {
        case .databaseError: return "SUPABASE_DATABASE_ERROR"
        case .queryError: return "SUPABASE_QUERY_ERROR"
        case .insertError: return "SUPABASE_INSERT_ERROR"
        case .updateError: return "SUPABASE_UPDATE_ERROR"
        case .deleteError: return "SUPABASE_DELETE_ERROR"
        case .authenticationError: return "SUPABASE_AUTH_ERROR"
        case .permissionDenied: return "SUPABASE_PERMISSION_DENIED"
        case .connectionError: return "SUPABASE_CONNECTION_ERROR"
        case .rateLimitExceeded: return "SUPABASE_RATE_LIMIT"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .databaseError, .connectionError:
            return .high
        case .authenticationError, .permissionDenied:
            return .high
        case .queryError, .insertError, .updateError, .deleteError:
            return .medium
        case .rateLimitExceeded:
            return .low
        }
    }
}

// MARK: - Auth Errors
enum AuthError: Error, LocalizedError {
    case signUpFailed(String)
    case signInFailed(String)
    case userNotFound
    case invalidCredentials
    case emailAlreadyExists
    case weakPassword
    case invalidEmail
    case accountDisabled
    case tooManyAttempts
    case networkError
    case tokenExpired
    case refreshTokenFailed
    case insufficientPermissions
    
    var localizedDescription: String {
        switch self {
        case .signUpFailed(let message):
            return "Failed to create account: \(message)"
        case .signInFailed(let message):
            return "Failed to sign in: \(message)"
        case .userNotFound:
            return "User not found. Please check your email."
        case .invalidCredentials:
            return "Invalid email or password."
        case .emailAlreadyExists:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password is too weak. Please use at least 8 characters with numbers and symbols."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .accountDisabled:
            return "Your account has been disabled. Please contact support."
        case .tooManyAttempts:
            return "Too many failed attempts. Please try again later."
        case .networkError:
            return "Network error. Please check your connection."
        case .tokenExpired:
            return "Your session has expired. Please log in again."
        case .refreshTokenFailed:
            return "Failed to refresh session. Please log in again."
        case .insufficientPermissions:
            return "Insufficient permissions. You don't have access to this resource."
        }
    }
    
    var code: String {
        switch self {
        case .signUpFailed: return "AUTH_SIGNUP_FAILED"
        case .signInFailed: return "AUTH_SIGNIN_FAILED"
        case .userNotFound: return "AUTH_USER_NOT_FOUND"
        case .invalidCredentials: return "AUTH_INVALID_CREDENTIALS"
        case .emailAlreadyExists: return "AUTH_EMAIL_EXISTS"
        case .weakPassword: return "AUTH_WEAK_PASSWORD"
        case .invalidEmail: return "AUTH_INVALID_EMAIL"
        case .accountDisabled: return "AUTH_ACCOUNT_DISABLED"
        case .tooManyAttempts: return "AUTH_TOO_MANY_ATTEMPTS"
        case .networkError: return "AUTH_NETWORK_ERROR"
        case .tokenExpired: return "AUTH_TOKEN_EXPIRED"
        case .refreshTokenFailed: return "AUTH_REFRESH_FAILED"
        case .insufficientPermissions: return "AUTH_INSUFFICIENT_PERMISSIONS"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .signUpFailed, .signInFailed, .networkError, .tokenExpired, .refreshTokenFailed:
            return .high
        case .userNotFound, .invalidCredentials, .accountDisabled:
            return .high
        case .emailAlreadyExists, .weakPassword, .invalidEmail, .tooManyAttempts:
            return .medium
        case .insufficientPermissions:
            return .high
        }
    }
}

// MARK: - Payment Errors
enum PaymentError: Error, LocalizedError {
    case invalidCard
    case cardDeclined
    case insufficientFunds
    case expiredCard
    case invalidCVC
    case processingError
    case networkError
    case rateLimitExceeded
    case subscriptionError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidCard:
            return "Invalid card information. Please check your card details."
        case .cardDeclined:
            return "Your card was declined. Please try a different card."
        case .insufficientFunds:
            return "Insufficient funds. Please check your account balance."
        case .expiredCard:
            return "Your card has expired. Please use a valid card."
        case .invalidCVC:
            return "Invalid CVC code. Please check your card's security code."
        case .processingError:
            return "Payment processing error. Please try again."
        case .networkError:
            return "Network error during payment. Please try again."
        case .rateLimitExceeded:
            return "Too many payment attempts. Please wait and try again."
        case .subscriptionError(let message):
            return "Subscription error: \(message)"
        }
    }
    
    var code: String {
        switch self {
        case .invalidCard: return "PAYMENT_INVALID_CARD"
        case .cardDeclined: return "PAYMENT_CARD_DECLINED"
        case .insufficientFunds: return "PAYMENT_INSUFFICIENT_FUNDS"
        case .expiredCard: return "PAYMENT_EXPIRED_CARD"
        case .invalidCVC: return "PAYMENT_INVALID_CVC"
        case .processingError: return "PAYMENT_PROCESSING_ERROR"
        case .networkError: return "PAYMENT_NETWORK_ERROR"
        case .rateLimitExceeded: return "PAYMENT_RATE_LIMIT"
        case .subscriptionError: return "PAYMENT_SUBSCRIPTION_ERROR"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .invalidCard, .cardDeclined, .insufficientFunds, .expiredCard, .invalidCVC:
            return .medium
        case .processingError, .networkError, .subscriptionError:
            return .high
        case .rateLimitExceeded:
            return .low
        }
    }
}

// MARK: - AI Errors
