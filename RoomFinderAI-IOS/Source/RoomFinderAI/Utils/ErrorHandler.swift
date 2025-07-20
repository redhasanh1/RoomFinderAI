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
    case noInternetConnection
    case timeoutError
    case noConnection
    case timeout
    case invalidResponse
    case serverError(Int)
    case decodingError
    case unauthorized
    case forbidden
    case notFound
    case internalServerError
    case parseError
    case requestFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noInternetConnection, .noConnection: return "No internet connection"
        case .timeoutError, .timeout: return "Request timed out"
        case .invalidResponse: return "Invalid response from server"
        case .serverError(let code): return "Server error: \(code)"
        case .decodingError: return "Data decoding error"
        case .unauthorized: return "Unauthorized access"
        case .forbidden: return "Access forbidden"
        case .notFound: return "Resource not found"
        case .internalServerError: return "Internal server error"
        case .parseError: return "Failed to parse response"
        case .requestFailed(let message): return "Request failed: \(message)"
        }
    }
    
    var code: String {
        switch self {
        case .noInternetConnection, .noConnection: return "NET_NO_CONNECTION"
        case .timeoutError, .timeout: return "NET_TIMEOUT"
        case .invalidResponse: return "NET_INVALID_RESPONSE"
        case .serverError(let code): return "NET_SERVER_ERROR_\(code)"
        case .decodingError: return "NET_DECODING_ERROR"
        case .unauthorized: return "NET_UNAUTHORIZED"
        case .forbidden: return "NET_FORBIDDEN"
        case .notFound: return "NET_NOT_FOUND"
        case .internalServerError: return "NET_INTERNAL_SERVER_ERROR"
        case .parseError: return "NET_PARSE_ERROR"
        case .requestFailed: return "NET_REQUEST_FAILED"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .noInternetConnection, .noConnection: return .high
        case .timeoutError, .timeout: return .medium
        case .invalidResponse: return .high
        case .serverError: return .high
        case .decodingError: return .medium
        case .unauthorized: return .high
        case .forbidden: return .high
        case .notFound: return .medium
        case .internalServerError: return .critical
        case .parseError: return .medium
        case .requestFailed: return .high
        }
    }
}

enum SupabaseError: Error, LocalizedError {
    case clientError(String)
    case authenticationFailed
    case connectionError
    case queryError(String)
    case rateLimitExceeded
    case permissionDenied
    case insertError(String)
    case updateError(String)
    case deleteError(String)
    case databaseError(String)
    
    var errorDescription: String? {
        switch self {
        case .clientError(let message): return "Supabase client error: \(message)"
        case .authenticationFailed: return "Authentication failed"
        case .connectionError: return "Connection to Supabase failed"
        case .queryError(let message): return "Query error: \(message)"
        case .rateLimitExceeded: return "Rate limit exceeded"
        case .permissionDenied: return "Permission denied"
        case .insertError(let message): return "Insert error: \(message)"
        case .updateError(let message): return "Update error: \(message)"
        case .deleteError(let message): return "Delete error: \(message)"
        case .databaseError(let message): return "Database error: \(message)"
        }
    }
    
    var code: String {
        switch self {
        case .clientError: return "SUPABASE_CLIENT_ERROR"
        case .authenticationFailed: return "SUPABASE_AUTH_FAILED"
        case .connectionError: return "SUPABASE_CONNECTION_ERROR"
        case .queryError: return "SUPABASE_QUERY_ERROR"
        case .rateLimitExceeded: return "SUPABASE_RATE_LIMIT"
        case .permissionDenied: return "SUPABASE_PERMISSION_DENIED"
        case .insertError: return "SUPABASE_INSERT_ERROR"
        case .updateError: return "SUPABASE_UPDATE_ERROR"
        case .deleteError: return "SUPABASE_DELETE_ERROR"
        case .databaseError: return "SUPABASE_DATABASE_ERROR"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .clientError: return .high
        case .authenticationFailed: return .high
        case .connectionError: return .high
        case .queryError: return .medium
        case .rateLimitExceeded: return .high
        case .permissionDenied: return .high
        case .insertError: return .medium
        case .updateError: return .medium
        case .deleteError: return .medium
        case .databaseError: return .high
        }
    }
}

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case userNotFound
    case accountDisabled
    case tokenExpired
    case emailNotVerified
    case emailAlreadyExists
    case weakPassword
    case signInFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid email or password"
        case .userNotFound: return "User not found"
        case .accountDisabled: return "Account has been disabled"
        case .tokenExpired: return "Session expired"
        case .emailNotVerified: return "Email not verified"
        case .emailAlreadyExists: return "Email already exists"
        case .weakPassword: return "Password is too weak"
        case .signInFailed(let message): return "Sign in failed: \(message)"
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
    
    var code: String {
        switch self {
        case .invalidEmail: return "VALIDATION_INVALID_EMAIL"
        case .passwordTooShort: return "VALIDATION_PASSWORD_TOO_SHORT"
        case .missingRequiredField(let field): return "VALIDATION_MISSING_\(field.uppercased())"
        case .invalidInput: return "VALIDATION_INVALID_INPUT"
        }
    }
    
    var severity: ErrorSeverity {
        return .medium
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
        case .authError:
            return "AUTH_ERROR"
        case .paymentError:
            return "PAYMENT_ERROR"
        case .aiError:
            return "AI_ERROR"
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
        case .authError:
            return .high
        case .paymentError:
            return .high
        case .aiError:
            return .medium
        case .validationError(let error):
            return error.severity
        case .unknownError:
            return .high
        }
    }
}

// MARK: - ErrorHandler Class
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: AppError?
    @Published var isShowingError = false
    
    private let loggingService = LoggingService.shared
    
    private init() {}
    
    func handle(_ error: AppError, context: ErrorContext? = nil) {
        let errorContext = context ?? ErrorContext()
        
        // Log the error
        loggingService.error(
            error.localizedDescription,
            category: .error,
            metadata: [
                "errorCode": error.errorCode,
                "severity": error.severity.rawValue,
                "timestamp": errorContext.timestamp.iso8601String,
                "userID": errorContext.userID ?? "unknown",
                "sessionID": errorContext.sessionID ?? "unknown"
            ]
        )
        
        // Show error to user if severity is medium or higher
        if error.severity.priority >= ErrorSeverity.medium.priority {
            DispatchQueue.main.async {
                self.currentError = error
                self.isShowingError = true
            }
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.isShowingError = false
        }
    }
}

// MARK: - Date Extension for ISO8601
extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
