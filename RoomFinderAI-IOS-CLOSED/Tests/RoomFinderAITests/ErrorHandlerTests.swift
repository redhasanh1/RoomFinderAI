import XCTest
@testable import RoomFinderAI

class ErrorHandlerTests: XCTestCase {
    var errorHandler: ErrorHandler!
    
    override func setUp() {
        super.setUp()
        errorHandler = ErrorHandler.shared
        errorHandler.errorHistory.removeAll()
    }
    
    override func tearDown() {
        errorHandler.clearCurrentError()
        super.tearDown()
    }
    
    // MARK: - Error Mapping Tests
    
    func testMapNetworkError() {
        // Given
        let networkError = NetworkError.noInternetConnection
        let context = ErrorContext(additionalInfo: ["test": "network"])
        
        // When
        errorHandler.handle(networkError, context: context)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError)
        XCTAssertEqual(errorHandler.currentError?.errorCode, "NETWORK_NO_CONNECTION")
        XCTAssertEqual(errorHandler.currentError?.severity, .medium)
        XCTAssertEqual(errorHandler.errorHistory.count, 1)
    }
    
    func testMapAuthError() {
        // Given
        let authError = AuthError.invalidCredentials
        let context = ErrorContext(userID: "test_user")
        
        // When
        errorHandler.handle(authError, context: context)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError)
        XCTAssertEqual(errorHandler.currentError?.errorCode, "AUTH_INVALID_CREDENTIALS")
        XCTAssertEqual(errorHandler.currentError?.severity, .high)
        XCTAssertEqual(errorHandler.errorHistory.first?.context.userID, "test_user")
    }
    
    func testMapSupabaseError() {
        // Given
        let supabaseError = SupabaseError.rateLimitExceeded
        
        // When
        errorHandler.handle(supabaseError)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError)
        XCTAssertEqual(errorHandler.currentError?.errorCode, "SUPABASE_RATE_LIMIT")
        XCTAssertEqual(errorHandler.currentError?.severity, .low)
    }
    
    func testMapPaymentError() {
        // Given
        let paymentError = PaymentError.cardDeclined
        
        // When
        errorHandler.handle(paymentError)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError)
        XCTAssertEqual(errorHandler.currentError?.errorCode, "PAYMENT_CARD_DECLINED")
        XCTAssertEqual(errorHandler.currentError?.severity, .medium)
    }
    
    func testMapAIError() {
        // Given
        let aiError = AIError.rateLimitExceeded
        
        // When
        errorHandler.handle(aiError)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError)
        XCTAssertEqual(errorHandler.currentError?.errorCode, "AI_RATE_LIMIT")
        XCTAssertEqual(errorHandler.currentError?.severity, .low)
    }
    
    func testMapValidationError() {
        // Given
        let validationError = ValidationError.invalidEmail
        
        // When
        errorHandler.handle(validationError)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError)
        XCTAssertEqual(errorHandler.currentError?.errorCode, "VALIDATION_INVALID_EMAIL")
        XCTAssertEqual(errorHandler.currentError?.severity, .low)
    }
    
    func testMapUnknownError() {
        // Given
        let unknownError = NSError(domain: "TestError", code: 999, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When
        errorHandler.handle(unknownError)
        
        // Then
        XCTAssertNotNil(errorHandler.currentError)
        XCTAssertEqual(errorHandler.currentError?.errorCode, "UNKNOWN_ERROR")
        XCTAssertEqual(errorHandler.currentError?.severity, .high)
    }
    
    // MARK: - Error History Tests
    
    func testErrorHistoryMaxSize() {
        // Given
        let maxSize = 100
        
        // When
        for i in 0..<(maxSize + 10) {
            let error = NetworkError.timeoutError
            errorHandler.handle(error)
        }
        
        // Then
        XCTAssertEqual(errorHandler.errorHistory.count, maxSize)
    }
    
    func testErrorHistoryOrder() {
        // Given
        let error1 = NetworkError.timeoutError
        let error2 = AuthError.invalidCredentials
        let error3 = SupabaseError.rateLimitExceeded
        
        // When
        errorHandler.handle(error1)
        Thread.sleep(forTimeInterval: 0.01)
        errorHandler.handle(error2)
        Thread.sleep(forTimeInterval: 0.01)
        errorHandler.handle(error3)
        
        // Then
        XCTAssertEqual(errorHandler.errorHistory.count, 3)
        XCTAssertEqual(errorHandler.errorHistory[0].error.errorCode, "SUPABASE_RATE_LIMIT") // Most recent first
        XCTAssertEqual(errorHandler.errorHistory[1].error.errorCode, "AUTH_INVALID_CREDENTIALS")
        XCTAssertEqual(errorHandler.errorHistory[2].error.errorCode, "NETWORK_TIMEOUT")
    }
    
    // MARK: - Error Context Tests
    
    func testErrorContextCreation() {
        // Given
        let userID = "test_user"
        let sessionID = "test_session"
        let additionalInfo = ["key": "value"]
        
        // When
        let context = ErrorContext(
            userID: userID,
            sessionID: sessionID,
            additionalInfo: additionalInfo
        )
        
        // Then
        XCTAssertEqual(context.userID, userID)
        XCTAssertEqual(context.sessionID, sessionID)
        XCTAssertEqual(context.additionalInfo["key"] as? String, "value")
        XCTAssertNotNil(context.timestamp)
        XCTAssertNotNil(context.deviceInfo)
        XCTAssertNotNil(context.appVersion)
    }
    
    // MARK: - Error Clearing Tests
    
    func testClearCurrentError() {
        // Given
        let error = NetworkError.timeoutError
        errorHandler.handle(error)
        XCTAssertNotNil(errorHandler.currentError)
        
        // When
        errorHandler.clearCurrentError()
        
        // Then
        XCTAssertNil(errorHandler.currentError)
        XCTAssertEqual(errorHandler.errorHistory.count, 1) // History should remain
    }
    
    // MARK: - Error Publisher Tests
    
    func testErrorPublisher() {
        // Given
        let expectation = XCTestExpectation(description: "Error publisher receives error")
        var receivedError: AppError?
        
        let cancellable = errorHandler.errorPublisher()
            .sink { error in
                receivedError = error
                expectation.fulfill()
            }
        
        // When
        let testError = NetworkError.timeoutError
        errorHandler.handle(testError)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedError)
        XCTAssertEqual(receivedError?.errorCode, "NETWORK_TIMEOUT")
        
        cancellable.cancel()
    }
    
    // MARK: - Error Severity Tests
    
    func testErrorSeverityPriority() {
        // Given & When & Then
        XCTAssertTrue(ErrorSeverity.low < ErrorSeverity.medium)
        XCTAssertTrue(ErrorSeverity.medium < ErrorSeverity.high)
        XCTAssertTrue(ErrorSeverity.high < ErrorSeverity.critical)
        
        XCTAssertEqual(ErrorSeverity.low.priority, 1)
        XCTAssertEqual(ErrorSeverity.medium.priority, 2)
        XCTAssertEqual(ErrorSeverity.high.priority, 3)
        XCTAssertEqual(ErrorSeverity.critical.priority, 4)
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecoveryManagerRetryable() {
        // Given
        let recoveryManager = ErrorRecoveryManager.shared
        
        // When & Then
        let networkError = AppError.networkError(.noInternetConnection)
        let authError = AppError.authError(.tokenExpired)
        let rateLimitError = AppError.supabaseError(.rateLimitExceeded)
        let validationError = AppError.validationError(.invalidEmail)
        
        // These should be recoverable
        Task {
            let canRecoverNetwork = await recoveryManager.attemptRecovery(from: networkError)
            let canRecoverAuth = await recoveryManager.attemptRecovery(from: authError)
            let canRecoverRateLimit = await recoveryManager.attemptRecovery(from: rateLimitError)
            
            XCTAssertTrue(canRecoverNetwork)
            XCTAssertFalse(canRecoverAuth) // Token refresh would typically fail in tests
            XCTAssertTrue(canRecoverRateLimit)
        }
        
        // This should not be recoverable
        Task {
            let canRecoverValidation = await recoveryManager.attemptRecovery(from: validationError)
            XCTAssertFalse(canRecoverValidation)
        }
    }
    
    // MARK: - Performance Tests
    
    func testErrorHandlingPerformance() {
        // Given
        let iterations = 1000
        let errors = Array(0..<iterations).map { _ in NetworkError.timeoutError }
        
        // When
        measure {
            for error in errors {
                errorHandler.handle(error)
            }
        }
        
        // Then
        XCTAssertEqual(errorHandler.errorHistory.count, 100) // Should be capped at max size
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafety() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent error handling")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        // When
        for i in 0..<10 {
            queue.async {
                let error = NetworkError.timeoutError
                let context = ErrorContext(additionalInfo: ["thread": i])
                self.errorHandler.handle(error, context: context)
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(errorHandler.errorHistory.count, 10)
        XCTAssertNotNil(errorHandler.currentError)
    }
}