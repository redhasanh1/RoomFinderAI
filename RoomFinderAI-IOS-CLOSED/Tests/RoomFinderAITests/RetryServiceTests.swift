import XCTest
@testable import RoomFinderAI

class RetryServiceTests: XCTestCase {
    var retryService: RetryService!
    
    override func setUp() {
        super.setUp()
        retryService = RetryService.shared
    }
    
    override func tearDown() {
        retryService.cancelAllRetries()
        super.tearDown()
    }
    
    // MARK: - Basic Retry Tests
    
    func testSuccessfulOperationNoRetry() async throws {
        // Given
        var callCount = 0
        let expectedResult = "success"
        
        let operation = {
            callCount += 1
            return expectedResult
        }
        
        // When
        let result = try await retryService.executeWithRetry(operation: operation)
        
        // Then
        XCTAssertEqual(result, expectedResult)
        XCTAssertEqual(callCount, 1)
    }
    
    func testRetryOnFailure() async throws {
        // Given
        var callCount = 0
        let expectedResult = "success"
        
        let operation = {
            callCount += 1
            if callCount < 3 {
                throw NetworkError.timeoutError
            }
            return expectedResult
        }
        
        // When
        let result = try await retryService.executeWithRetry(operation: operation)
        
        // Then
        XCTAssertEqual(result, expectedResult)
        XCTAssertEqual(callCount, 3)
    }
    
    func testMaxRetriesExceeded() async {
        // Given
        var callCount = 0
        let configuration = RetryConfiguration(
            maxRetries: 2,
            baseDelay: 0.1,
            maxDelay: 1.0,
            backoffMultiplier: 2.0,
            jitter: false,
            retryableErrors: ["NETWORK_TIMEOUT"]
        )
        
        let operation = {
            callCount += 1
            throw NetworkError.timeoutError
        }
        
        // When & Then
        do {
            _ = try await retryService.executeWithRetry(
                operation: operation,
                configuration: configuration
            )
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(callCount, 2)
            XCTAssertTrue(error.localizedDescription.contains("Max retries"))
        }
    }
    
    func testNonRetryableError() async {
        // Given
        var callCount = 0
        let configuration = RetryConfiguration(
            maxRetries: 3,
            baseDelay: 0.1,
            maxDelay: 1.0,
            backoffMultiplier: 2.0,
            jitter: false,
            retryableErrors: ["NETWORK_TIMEOUT"]
        )
        
        let operation = {
            callCount += 1
            throw ValidationError.invalidEmail
        }
        
        // When & Then
        do {
            _ = try await retryService.executeWithRetry(
                operation: operation,
                configuration: configuration
            )
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(callCount, 1)
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - Retry Strategy Tests
    
    func testExponentialBackoffStrategy() {
        // Given
        let strategy = RetryStrategy.exponentialBackoff
        let configuration = RetryConfiguration(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            backoffMultiplier: 2.0,
            jitter: false,
            retryableErrors: []
        )
        
        // When & Then
        let delay1 = strategy.calculateDelay(attempt: 1, configuration: configuration)
        let delay2 = strategy.calculateDelay(attempt: 2, configuration: configuration)
        let delay3 = strategy.calculateDelay(attempt: 3, configuration: configuration)
        
        XCTAssertEqual(delay1, 1.0)
        XCTAssertEqual(delay2, 2.0)
        XCTAssertEqual(delay3, 4.0)
    }
    
    func testLinearBackoffStrategy() {
        // Given
        let strategy = RetryStrategy.linearBackoff
        let configuration = RetryConfiguration(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            backoffMultiplier: 2.0,
            jitter: false,
            retryableErrors: []
        )
        
        // When & Then
        let delay1 = strategy.calculateDelay(attempt: 1, configuration: configuration)
        let delay2 = strategy.calculateDelay(attempt: 2, configuration: configuration)
        let delay3 = strategy.calculateDelay(attempt: 3, configuration: configuration)
        
        XCTAssertEqual(delay1, 1.0)
        XCTAssertEqual(delay2, 2.0)
        XCTAssertEqual(delay3, 3.0)
    }
    
    func testFixedDelayStrategy() {
        // Given
        let strategy = RetryStrategy.fixedDelay
        let configuration = RetryConfiguration(
            maxRetries: 3,
            baseDelay: 1.5,
            maxDelay: 10.0,
            backoffMultiplier: 2.0,
            jitter: false,
            retryableErrors: []
        )
        
        // When & Then
        let delay1 = strategy.calculateDelay(attempt: 1, configuration: configuration)
        let delay2 = strategy.calculateDelay(attempt: 2, configuration: configuration)
        let delay3 = strategy.calculateDelay(attempt: 3, configuration: configuration)
        
        XCTAssertEqual(delay1, 1.5)
        XCTAssertEqual(delay2, 1.5)
        XCTAssertEqual(delay3, 1.5)
    }
    
    func testCustomDelayStrategy() {
        // Given
        let strategy = RetryStrategy.customDelay { attempt in
            return Double(attempt * 2)
        }
        let configuration = RetryConfiguration(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            backoffMultiplier: 2.0,
            jitter: false,
            retryableErrors: []
        )
        
        // When & Then
        let delay1 = strategy.calculateDelay(attempt: 1, configuration: configuration)
        let delay2 = strategy.calculateDelay(attempt: 2, configuration: configuration)
        let delay3 = strategy.calculateDelay(attempt: 3, configuration: configuration)
        
        XCTAssertEqual(delay1, 2.0)
        XCTAssertEqual(delay2, 4.0)
        XCTAssertEqual(delay3, 6.0)
    }
    
    func testMaxDelayCappping() {
        // Given
        let strategy = RetryStrategy.exponentialBackoff
        let configuration = RetryConfiguration(
            maxRetries: 5,
            baseDelay: 2.0,
            maxDelay: 5.0,
            backoffMultiplier: 2.0,
            jitter: false,
            retryableErrors: []
        )
        
        // When & Then
        let delay1 = strategy.calculateDelay(attempt: 1, configuration: configuration)
        let delay2 = strategy.calculateDelay(attempt: 2, configuration: configuration)
        let delay3 = strategy.calculateDelay(attempt: 3, configuration: configuration)
        let delay4 = strategy.calculateDelay(attempt: 4, configuration: configuration)
        
        XCTAssertEqual(delay1, 2.0)
        XCTAssertEqual(delay2, 4.0)
        XCTAssertEqual(delay3, 5.0) // Capped at maxDelay
        XCTAssertEqual(delay4, 5.0) // Capped at maxDelay
    }
    
    func testJitterEnabled() {
        // Given
        let strategy = RetryStrategy.exponentialBackoff
        let configuration = RetryConfiguration(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            backoffMultiplier: 2.0,
            jitter: true,
            retryableErrors: []
        )
        
        // When
        let delays = (1...10).map { attempt in
            strategy.calculateDelay(attempt: attempt, configuration: configuration)
        }
        
        // Then
        // With jitter enabled, delays should vary slightly
        let uniqueDelays = Set(delays.map { Int($0 * 1000) }) // Convert to milliseconds for comparison
        XCTAssertGreaterThan(uniqueDelays.count, 1)
    }
    
    // MARK: - Circuit Breaker Tests
    
    func testCircuitBreakerClosed() async throws {
        // Given
        let circuitBreaker = CircuitBreaker(failureThreshold: 3, timeout: 1.0)
        var callCount = 0
        
        let operation = {
            callCount += 1
            return "success"
        }
        
        // When
        let result = try await circuitBreaker.execute(operation: operation)
        
        // Then
        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(circuitBreaker.currentState, .closed)
    }
    
    func testCircuitBreakerOpen() async throws {
        // Given
        let circuitBreaker = CircuitBreaker(failureThreshold: 2, timeout: 0.1)
        var callCount = 0
        
        let failingOperation = {
            callCount += 1
            throw NetworkError.timeoutError
        }
        
        // When - Fail enough times to open circuit
        for _ in 0..<3 {
            do {
                _ = try await circuitBreaker.execute(operation: failingOperation)
            } catch {
                // Expected to fail
            }
        }
        
        // Then
        XCTAssertEqual(circuitBreaker.currentState, .open)
        XCTAssertEqual(callCount, 3)
        
        // When - Try to execute with open circuit
        do {
            _ = try await circuitBreaker.execute(operation: failingOperation)
            XCTFail("Should have thrown circuit breaker error")
        } catch {
            XCTAssertEqual(callCount, 3) // Should not increment
        }
    }
    
    func testCircuitBreakerHalfOpen() async throws {
        // Given
        let circuitBreaker = CircuitBreaker(failureThreshold: 2, timeout: 0.1, resetTimeout: 0.1)
        var callCount = 0
        
        let failingOperation = {
            callCount += 1
            throw NetworkError.timeoutError
        }
        
        // When - Open the circuit
        for _ in 0..<3 {
            do {
                _ = try await circuitBreaker.execute(operation: failingOperation)
            } catch {
                // Expected to fail
            }
        }
        
        // Wait for reset timeout
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms
        
        // Then - Circuit should allow one attempt (half-open)
        XCTAssertEqual(circuitBreaker.currentState, .open)
        
        do {
            _ = try await circuitBreaker.execute(operation: failingOperation)
        } catch {
            // Expected to fail, but circuit should be half-open momentarily
        }
    }
    
    // MARK: - Batch Operation Tests
    
    func testBatchOperationsSuccess() async throws {
        // Given
        let operations = Array(0..<5).map { index in
            return {
                return "result_\(index)"
            }
        }
        
        // When
        let results = await retryService.executeBatchWithRetry(
            operations: operations,
            configuration: .default
        )
        
        // Then
        XCTAssertEqual(results.count, 5)
        for (index, result) in results.enumerated() {
            switch result {
            case .success(let value):
                XCTAssertEqual(value, "result_\(index)")
            case .failure:
                XCTFail("Operation should have succeeded")
            }
        }
    }
    
    func testBatchOperationsPartialFailure() async throws {
        // Given
        let operations = Array(0..<5).map { index in
            return {
                if index == 2 {
                    throw NetworkError.timeoutError
                }
                return "result_\(index)"
            }
        }
        
        // When
        let results = await retryService.executeBatchWithRetry(
            operations: operations,
            configuration: .default
        )
        
        // Then
        XCTAssertEqual(results.count, 5)
        
        for (index, result) in results.enumerated() {
            if index == 2 {
                switch result {
                case .success:
                    XCTFail("Operation should have failed")
                case .failure(let error):
                    XCTAssertTrue(error is NetworkError)
                }
            } else {
                switch result {
                case .success(let value):
                    XCTAssertEqual(value, "result_\(index)")
                case .failure:
                    XCTFail("Operation should have succeeded")
                }
            }
        }
    }
    
    // MARK: - Cancellation Tests
    
    func testCancellableRetry() async throws {
        // Given
        let operationId = "test_operation"
        var callCount = 0
        
        let operation = {
            callCount += 1
            if callCount < 5 {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                throw NetworkError.timeoutError
            }
            return "success"
        }
        
        // When
        let task = Task {
            try await retryService.executeWithCancellableRetry(
                operation: operation,
                operationId: operationId
            )
        }
        
        // Cancel after short delay
        Task {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            retryService.cancelRetry(operationId: operationId)
        }
        
        // Then
        do {
            _ = try await task.value
            XCTFail("Should have been cancelled")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testRetryPerformance() async throws {
        // Given
        let iterations = 100
        let operations = Array(0..<iterations).map { index in
            return {
                return "result_\(index)"
            }
        }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let results = await retryService.executeBatchWithRetry(
            operations: operations,
            configuration: .minimal
        )
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Then
        XCTAssertEqual(results.count, iterations)
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
        
        // All should succeed
        for result in results {
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("Operation should have succeeded")
            }
        }
    }
    
    // MARK: - Configuration Tests
    
    func testRetryConfigurationDefault() {
        // Given
        let config = RetryConfiguration.default
        
        // Then
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.baseDelay, 1.0)
        XCTAssertEqual(config.maxDelay, 30.0)
        XCTAssertEqual(config.backoffMultiplier, 2.0)
        XCTAssertTrue(config.jitter)
        XCTAssertTrue(config.retryableErrors.contains("NETWORK_TIMEOUT"))
    }
    
    func testRetryConfigurationAggressive() {
        // Given
        let config = RetryConfiguration.aggressive
        
        // Then
        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertEqual(config.baseDelay, 0.5)
        XCTAssertEqual(config.maxDelay, 60.0)
        XCTAssertEqual(config.backoffMultiplier, 1.5)
        XCTAssertTrue(config.jitter)
        XCTAssertTrue(config.retryableErrors.contains("SUPABASE_DATABASE_ERROR"))
    }
    
    func testRetryConfigurationConservative() {
        // Given
        let config = RetryConfiguration.conservative
        
        // Then
        XCTAssertEqual(config.maxRetries, 2)
        XCTAssertEqual(config.baseDelay, 2.0)
        XCTAssertEqual(config.maxDelay, 15.0)
        XCTAssertEqual(config.backoffMultiplier, 3.0)
        XCTAssertFalse(config.jitter)
        XCTAssertFalse(config.retryableErrors.contains("SUPABASE_DATABASE_ERROR"))
    }
}