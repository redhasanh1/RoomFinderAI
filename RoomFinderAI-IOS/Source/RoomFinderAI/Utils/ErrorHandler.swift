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
    
    var code: String {
        switch self {
        case .noConnection: return "NET_NO_CONNECTION"
        case .timeout: return "NET_TIMEOUT"
        case .invalidResponse: return "NET_INVALID_RESPONSE"
        case .serverError(let code): return "NET_SERVER_ERROR_\(code)"
        case .decodingError: return "NET_DECODING_ERROR"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .noConnection: return .high
        case .timeout: return .medium
        case .invalidResponse: return .high
        case .serverError: return .high
        case .decodingError: return .medium
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
    
    var code: String {
        switch self {
        case .clientError: return "SUPABASE_CLIENT_ERROR"
        case .authenticationFailed: return "SUPABASE_AUTH_FAILED"
        case .connectionError: return "SUPABASE_CONNECTION_ERROR"
        case .queryError: return "SUPABASE_QUERY_ERROR"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .clientError: return .high
        case .authenticationFailed: return .high
        case .connectionError: return .high
        case .queryError: return .medium
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
