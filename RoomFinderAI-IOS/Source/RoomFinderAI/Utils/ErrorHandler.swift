import Foundation
import Combine

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
enum AIError: Error, LocalizedError {
    case apiKeyInvalid
    case requestFailed(String)
    case responseParsingFailed
    case rateLimitExceeded
    case modelNotAvailable
    case contentFiltered
    case networkError
    case quotaExceeded
    
    var localizedDescription: String {
        switch self {
        case .apiKeyInvalid:
            return "AI service configuration error. Please contact support."
        case .requestFailed(let message):
            return "AI request failed: \(message)"
        case .responseParsingFailed:
            return "Failed to process AI response."
        case .rateLimitExceeded:
            return "Too many AI requests. Please wait and try again."
        case .modelNotAvailable:
            return "AI model is currently unavailable. Please try again later."
        case .contentFiltered:
            return "Content was filtered by AI safety systems."
        case .networkError:
            return "Network error connecting to AI service."
        case .quotaExceeded:
            return "AI service quota exceeded. Please try again later."
        }
    }
    
    var code: String {
        switch self {
        case .apiKeyInvalid: return "AI_INVALID_API_KEY"
        case .requestFailed: return "AI_REQUEST_FAILED"
        case .responseParsingFailed: return "AI_RESPONSE_PARSING_FAILED"
        case .rateLimitExceeded: return "AI_RATE_LIMIT"
        case .modelNotAvailable: return "AI_MODEL_UNAVAILABLE"
        case .contentFiltered: return "AI_CONTENT_FILTERED"
        case .networkError: return "AI_NETWORK_ERROR"
        case .quotaExceeded: return "AI_QUOTA_EXCEEDED"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .apiKeyInvalid, .modelNotAvailable, .quotaExceeded:
            return .high
        case .requestFailed, .responseParsingFailed, .networkError:
            return .medium
        case .rateLimitExceeded, .contentFiltered:
            return .low
        }
    }
}

// MARK: - Validation Errors
enum ValidationError: Error, LocalizedError {
    case invalidEmail
    case invalidPassword
    case invalidPhoneNumber
    case invalidPrice
    case invalidDate
    case missingRequiredField(String)
    case invalidFormat(String)
    case valueTooLong(String, Int)
    case valueTooShort(String, Int)
    case invalidRange(String, Double, Double)
    
    var localizedDescription: String {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .invalidPassword:
            return "Password must be at least 8 characters long."
        case .invalidPhoneNumber:
            return "Please enter a valid phone number."
        case .invalidPrice:
            return "Please enter a valid price."
        case .invalidDate:
            return "Please enter a valid date."
        case .missingRequiredField(let field):
            return "\(field) is required."
        case .invalidFormat(let field):
            return "\(field) has an invalid format."
        case .valueTooLong(let field, let max):
            return "\(field) must be less than \(max) characters."
        case .valueTooShort(let field, let min):
            return "\(field) must be at least \(min) characters."
        case .invalidRange(let field, let min, let max):
            return "\(field) must be between \(min) and \(max)."
        }
    }
    
    var code: String {
        switch self {
        case .invalidEmail: return "VALIDATION_INVALID_EMAIL"
        case .invalidPassword: return "VALIDATION_INVALID_PASSWORD"
        case .invalidPhoneNumber: return "VALIDATION_INVALID_PHONE"
        case .invalidPrice: return "VALIDATION_INVALID_PRICE"
        case .invalidDate: return "VALIDATION_INVALID_DATE"
        case .missingRequiredField: return "VALIDATION_MISSING_FIELD"
        case .invalidFormat: return "VALIDATION_INVALID_FORMAT"
        case .valueTooLong: return "VALIDATION_VALUE_TOO_LONG"
        case .valueTooShort: return "VALIDATION_VALUE_TOO_SHORT"
        case .invalidRange: return "VALIDATION_INVALID_RANGE"
        }
    }
    
    var severity: ErrorSeverity {
        .low
    }
}

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
    let userID: String?
    let sessionID: String?
    let deviceInfo: String
    let appVersion: String
    let function: String
    let file: String
    let line: Int
    let additionalInfo: [String: Any]
    
    init(
        userID: String? = nil,
        sessionID: String? = nil,
        additionalInfo: [String: Any] = [:],
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        self.timestamp = Date()
        self.userID = userID
        self.sessionID = sessionID
        self.deviceInfo = "\(UIDevice.current.model) - \(UIDevice.current.systemVersion)"
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.function = function
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.line = line
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Error Handler
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: AppError?
    @Published var errorHistory: [ErrorLogEntry] = []
    
    private let maxHistorySize = 100
    private var errorSubject = PassthroughSubject<AppError, Never>()
    
    private init() {}
    
    func handle(_ error: Error, context: ErrorContext? = nil) {
        let appError = mapToAppError(error)
        let logEntry = ErrorLogEntry(
            error: appError,
            context: context ?? ErrorContext()
        )
        
        DispatchQueue.main.async {
            self.currentError = appError
            self.errorHistory.insert(logEntry, at: 0)
            
            if self.errorHistory.count > self.maxHistorySize {
                self.errorHistory.removeLast()
            }
        }
        
        logError(logEntry)
        errorSubject.send(appError)
        
        // Send to analytics/crash reporting if severity is high
        if appError.severity.priority >= ErrorSeverity.high.priority {
            sendToCrashReporting(logEntry)
        }
    }
    
    func clearCurrentError() {
        DispatchQueue.main.async {
            self.currentError = nil
        }
    }
    
    func errorPublisher() -> AnyPublisher<AppError, Never> {
        return errorSubject.eraseToAnyPublisher()
    }
    
    private func mapToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        if let networkError = error as? NetworkError {
            return .networkError(networkError)
        }
        
        if let supabaseError = error as? SupabaseError {
            return .supabaseError(supabaseError)
        }
        
        if let authError = error as? AuthError {
            return .authError(authError)
        }
        
        if let paymentError = error as? PaymentError {
            return .paymentError(paymentError)
        }
        
        if let aiError = error as? AIError {
            return .aiError(aiError)
        }
        
        if let validationError = error as? ValidationError {
            return .validationError(validationError)
        }
        
        return .unknownError(error.localizedDescription)
    }
    
    private func logError(_ entry: ErrorLogEntry) {
        let logLevel: LogLevel = entry.error.severity == .critical ? .critical :
                                entry.error.severity == .high ? .error :
                                entry.error.severity == .medium ? .warning : .info
        
        var metadata = entry.context.additionalInfo
        metadata["error_code"] = entry.error.errorCode
        metadata["error_severity"] = entry.error.severity.rawValue
        metadata["device_info"] = entry.context.deviceInfo
        metadata["app_version"] = entry.context.appVersion
        metadata["user_id"] = entry.context.userID as Any
        metadata["session_id"] = entry.context.sessionID as Any
        
        // Determine category based on error type
        let category: LogCategory
        switch entry.error {
        case .networkError:
            category = .network
        case .supabaseError:
            category = .database
        case .authError:
            category = .auth
        case .paymentError:
            category = .payment
        case .aiError:
            category = .ai
        case .validationError:
            category = .ui
        case .unknownError:
            category = .general
        }
        
        // Log using the appropriate method based on level
        switch logLevel {
        case .debug:
            LoggingService.shared.debug(entry.error.localizedDescription, category: category, metadata: metadata, function: entry.context.function, file: entry.context.file, line: entry.context.line)
        case .info:
            LoggingService.shared.info(entry.error.localizedDescription, category: category, metadata: metadata, function: entry.context.function, file: entry.context.file, line: entry.context.line)
        case .warning:
            LoggingService.shared.warning(entry.error.localizedDescription, category: category, metadata: metadata, function: entry.context.function, file: entry.context.file, line: entry.context.line)
        case .error:
            LoggingService.shared.error(entry.error.localizedDescription, category: category, metadata: metadata, function: entry.context.function, file: entry.context.file, line: entry.context.line)
        case .critical:
            LoggingService.shared.critical(entry.error.localizedDescription, category: category, metadata: metadata, function: entry.context.function, file: entry.context.file, line: entry.context.line)
        }
    }
    
    private func sendToCrashReporting(_ entry: ErrorLogEntry) {
        // Implement crash reporting service integration
        // e.g., Firebase Crashlytics, Sentry, etc.
        print("📊 Sending error to crash reporting service: \(entry.error.errorCode)")
    }
}

// MARK: - Error Log Entry
struct ErrorLogEntry: Identifiable {
    let id = UUID()
    let error: AppError
    let context: ErrorContext
    let timestamp: Date
    
    init(error: AppError, context: ErrorContext) {
        self.error = error
        self.context = context
        self.timestamp = Date()
    }
}

// MARK: - Error Recovery
protocol ErrorRecoverable {
    func canRecover(from error: AppError) -> Bool
    func recover(from error: AppError) async throws
}

class ErrorRecoveryManager {
    static let shared = ErrorRecoveryManager()
    
    private init() {}
    
    func attemptRecovery(from error: AppError) async -> Bool {
        switch error {
        case .networkError(.noInternetConnection):
            return await waitForConnection()
        case .authError(.tokenExpired):
            return await refreshToken()
        case .supabaseError(.rateLimitExceeded):
            return await waitForRateLimit()
        default:
            return false
        }
    }
    
    private func waitForConnection() async -> Bool {
        // Implement network connectivity check
        try? await Task.sleep(for: .seconds(2))
        return true // Simplified
    }
    
    private func refreshToken() async -> Bool {
        // Implement token refresh logic
        return false // Simplified
    }
    
    private func waitForRateLimit() async -> Bool {
        // Wait for rate limit to reset
        try? await Task.sleep(for: .seconds(60))
        return true
    }
}