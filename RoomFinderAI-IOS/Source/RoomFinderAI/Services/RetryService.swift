import Foundation
import Combine

// MARK: - Retry Configuration
struct RetryConfiguration {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    let jitter: Bool
    let retryableErrors: Set<String>
    
    static let `default` = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        jitter: true,
        retryableErrors: [
            "NETWORK_TIMEOUT",
            "NETWORK_NO_CONNECTION",
            "NETWORK_SERVER_ERROR_500",
            "NETWORK_SERVER_ERROR_502",
            "NETWORK_SERVER_ERROR_503",
            "SUPABASE_RATE_LIMIT",
            "SUPABASE_CONNECTION_ERROR",
            "AI_RATE_LIMIT",
            "AI_NETWORK_ERROR",
            "PAYMENT_NETWORK_ERROR",
            "PAYMENT_RATE_LIMIT"
        ]
    )
    
    static let aggressive = RetryConfiguration(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        backoffMultiplier: 1.5,
        jitter: true,
        retryableErrors: [
            "NETWORK_TIMEOUT",
            "NETWORK_NO_CONNECTION",
            "NETWORK_SERVER_ERROR_500",
            "NETWORK_SERVER_ERROR_502",
            "NETWORK_SERVER_ERROR_503",
            "NETWORK_SERVER_ERROR_504",
            "SUPABASE_RATE_LIMIT",
            "SUPABASE_CONNECTION_ERROR",
            "SUPABASE_DATABASE_ERROR",
            "AI_RATE_LIMIT",
            "AI_NETWORK_ERROR",
            "AI_MODEL_UNAVAILABLE",
            "PAYMENT_NETWORK_ERROR",
            "PAYMENT_RATE_LIMIT",
            "PAYMENT_PROCESSING_ERROR"
        ]
    )
    
    static let conservative = RetryConfiguration(
        maxRetries: 2,
        baseDelay: 2.0,
        maxDelay: 15.0,
        backoffMultiplier: 3.0,
        jitter: false,
        retryableErrors: [
            "NETWORK_TIMEOUT",
            "NETWORK_NO_CONNECTION",
            "SUPABASE_RATE_LIMIT",
            "AI_RATE_LIMIT"
        ]
    )
}

// MARK: - Retry Strategy
enum RetryStrategy {
    case exponentialBackoff
    case linearBackoff
    case fixedDelay
    case customDelay((Int) -> TimeInterval)
    
    func calculateDelay(attempt: Int, configuration: RetryConfiguration) -> TimeInterval {
        let delay: TimeInterval
        
        switch self {
        case .exponentialBackoff:
            delay = configuration.baseDelay * pow(configuration.backoffMultiplier, Double(attempt - 1))
        case .linearBackoff:
            delay = configuration.baseDelay * Double(attempt)
        case .fixedDelay:
            delay = configuration.baseDelay
        case .customDelay(let calculator):
            delay = calculator(attempt)
        }
        
        let cappedDelay = min(delay, configuration.maxDelay)
        
        if configuration.jitter {
            let jitterAmount = cappedDelay * 0.1
            let randomJitter = Double.random(in: -jitterAmount...jitterAmount)
            return max(0, cappedDelay + randomJitter)
        }
        
        return cappedDelay
    }
}

// MARK: - Retry Result
enum RetryResult<T> {
    case success(T)
    case failure(Error, attempts: Int)
    case maxRetriesExceeded(lastError: Error, attempts: Int)
    
    var value: T? {
        switch self {
        case .success(let value):
            return value
        case .failure, .maxRetriesExceeded:
            return nil
        }
    }
    
    var error: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error, _):
            return error
        case .maxRetriesExceeded(let error, _):
            return error
        }
    }
    
    var attempts: Int {
        switch self {
        case .success:
            return 1
        case .failure(_, let attempts):
            return attempts
        case .maxRetriesExceeded(_, let attempts):
            return attempts
        }
    }
}

// MARK: - Retry Service
class RetryService {
    static let shared = RetryService()
    
    private var activeRetries: [String: Task<Any, Error>] = [:]
    private let queue = DispatchQueue(label: "com.roomfinder.retry", qos: .utility)
    
    private init() {}
    
    // MARK: - Generic Retry Function
    
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        configuration: RetryConfiguration = .default,
        strategy: RetryStrategy = .exponentialBackoff,
        context: ErrorContext? = nil
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0
        
        repeat {
            attempt += 1
            
            do {
                let result = try await operation()
                
                if attempt > 1 {
                    logRetrySuccess(attempt: attempt, context: context)
                }
                
                return result
                
            } catch {
                lastError = error
                
                // Check if error is retryable
                guard isRetryable(error: error, configuration: configuration) else {
                    logRetryFailure(error: error, attempt: attempt, reason: "Non-retryable error", context: context)
                    throw error
                }
                
                // Check if we've reached max retries
                guard attempt < configuration.maxRetries else {
                    logRetryFailure(error: error, attempt: attempt, reason: "Max retries exceeded", context: context)
                    throw AppError.unknownError("Max retries (\(configuration.maxRetries)) exceeded. Last error: \(error.localizedDescription)")
                }
                
                // Calculate delay and wait
                let delay = strategy.calculateDelay(attempt: attempt, configuration: configuration)
                logRetryAttempt(attempt: attempt, delay: delay, error: error, context: context)
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        } while attempt < configuration.maxRetries
        
        throw lastError ?? AppError.unknownError("Retry failed with unknown error")
    }
    
    // MARK: - Async Publisher Retry
    
    func retry<T>(
        publisher: @escaping () -> AnyPublisher<T, Error>,
        configuration: RetryConfiguration = .default,
        strategy: RetryStrategy = .exponentialBackoff
    ) -> AnyPublisher<T, Error> {
        return publisher()
            .catch { error -> AnyPublisher<T, Error> in
                if self.isRetryable(error: error, configuration: configuration) {
                    return self.retryPublisher(
                        publisher: publisher,
                        configuration: configuration,
                        strategy: strategy,
                        attempt: 1,
                        lastError: error
                    )
                } else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func retryPublisher<T>(
        publisher: @escaping () -> AnyPublisher<T, Error>,
        configuration: RetryConfiguration,
        strategy: RetryStrategy,
        attempt: Int,
        lastError: Error
    ) -> AnyPublisher<T, Error> {
        guard attempt < configuration.maxRetries else {
            return Fail(error: lastError).eraseToAnyPublisher()
        }
        
        let delay = strategy.calculateDelay(attempt: attempt, configuration: configuration)
        
        return Just(())
            .delay(for: .milliseconds(Int(delay * 1000)), scheduler: DispatchQueue.main)
            .flatMap { _ in
                publisher()
                    .catch { error -> AnyPublisher<T, Error> in
                        if self.isRetryable(error: error, configuration: configuration) {
                            return self.retryPublisher(
                                publisher: publisher,
                                configuration: configuration,
                                strategy: strategy,
                                attempt: attempt + 1,
                                lastError: error
                            )
                        } else {
                            return Fail(error: error).eraseToAnyPublisher()
                        }
                    }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Cancellable Retry
    
    func executeWithCancellableRetry<T>(
        operation: @escaping () async throws -> T,
        configuration: RetryConfiguration = .default,
        strategy: RetryStrategy = .exponentialBackoff,
        operationId: String = UUID().uuidString,
        context: ErrorContext? = nil
    ) async throws -> T {
        let task = Task<T, Error> {
            try await self.executeWithRetry(
                operation: operation,
                configuration: configuration,
                strategy: strategy,
                context: context
            )
        }
        
        activeRetries[operationId] = Task<Any, Error> { try await task.value }
        
        defer {
            activeRetries.removeValue(forKey: operationId)
        }
        
        return try await task.value
    }
    
    func cancelRetry(operationId: String) {
        activeRetries[operationId]?.cancel()
        activeRetries.removeValue(forKey: operationId)
    }
    
    func cancelAllRetries() {
        activeRetries.values.forEach { $0.cancel() }
        activeRetries.removeAll()
    }
    
    // MARK: - Circuit Breaker Integration
    
    func executeWithCircuitBreaker<T>(
        operation: @escaping () async throws -> T,
        circuitBreaker: CircuitBreaker,
        configuration: RetryConfiguration = .default,
        strategy: RetryStrategy = .exponentialBackoff,
        context: ErrorContext? = nil
    ) async throws -> T {
        return try await circuitBreaker.execute {
            try await self.executeWithRetry(
                operation: operation,
                configuration: configuration,
                strategy: strategy,
                context: context
            )
        }
    }
    
    // MARK: - Batch Retry
    
    func executeBatchWithRetry<T>(
        operations: [() async throws -> T],
        configuration: RetryConfiguration = .default,
        strategy: RetryStrategy = .exponentialBackoff,
        maxConcurrency: Int = 5,
        context: ErrorContext? = nil
    ) async -> [Result<T, Error>] {
        return await withTaskGroup(of: Result<T, Error>.self) { group in
            let semaphore = AsyncSemaphore(value: maxConcurrency)
            var results: [Result<T, Error>] = []
            
            for operation in operations {
                group.addTask {
                    await semaphore.wait()
                    
                    let result: Result<T, Error>
                    do {
                        let operationResult = try await self.executeWithRetry(
                            operation: operation,
                            configuration: configuration,
                            strategy: strategy,
                            context: context
                        )
                        result = .success(operationResult)
                    } catch {
                        result = .failure(error)
                    }
                    
                    await semaphore.signal()
                    return result
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    // MARK: - Helper Methods
    
    private func isRetryable(error: Error, configuration: RetryConfiguration) -> Bool {
        if let appError = error as? AppError {
            return configuration.retryableErrors.contains(appError.errorCode)
        }
        
        let errorDescription = error.localizedDescription.lowercased()
        return errorDescription.contains("timeout") ||
               errorDescription.contains("network") ||
               errorDescription.contains("connection") ||
               errorDescription.contains("rate limit") ||
               errorDescription.contains("server error") ||
               errorDescription.contains("503") ||
               errorDescription.contains("502") ||
               errorDescription.contains("500")
    }
    
    private func logRetryAttempt(attempt: Int, delay: TimeInterval, error: Error, context: ErrorContext?) {
        let contextInfo = context?.additionalInfo.description ?? "N/A"
        print("🔄 Retry attempt \(attempt) after \(String(format: "%.1f", delay))s for error: \(error.localizedDescription)")
        print("   Context: \(contextInfo)")
    }
    
    private func logRetrySuccess(attempt: Int, context: ErrorContext?) {
        let contextInfo = context?.additionalInfo.description ?? "N/A"
        print("✅ Retry succeeded after \(attempt) attempts")
        print("   Context: \(contextInfo)")
    }
    
    private func logRetryFailure(error: Error, attempt: Int, reason: String, context: ErrorContext?) {
        let contextInfo = context?.additionalInfo.description ?? "N/A"
        print("❌ Retry failed after \(attempt) attempts: \(reason)")
        print("   Error: \(error.localizedDescription)")
        print("   Context: \(contextInfo)")
    }
}

// MARK: - Circuit Breaker
class CircuitBreaker {
    enum State {
        case closed
        case open
        case halfOpen
    }
    
    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let failureThreshold: Int
    private let timeout: TimeInterval
    private let resetTimeout: TimeInterval
    
    init(failureThreshold: Int = 5, timeout: TimeInterval = 60.0, resetTimeout: TimeInterval = 30.0) {
        self.failureThreshold = failureThreshold
        self.timeout = timeout
        self.resetTimeout = resetTimeout
    }
    
    func execute<T>(operation: @escaping () async throws -> T) async throws -> T {
        switch state {
        case .closed:
            return try await executeOperation(operation)
        case .open:
            if shouldAttemptReset() {
                state = .halfOpen
                return try await executeOperation(operation)
            } else {
                throw AppError.unknownError("Circuit breaker is open")
            }
        case .halfOpen:
            return try await executeOperation(operation)
        }
    }
    
    private func executeOperation<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        do {
            let result = try await operation()
            onSuccess()
            return result
        } catch {
            onFailure()
            throw error
        }
    }
    
    private func shouldAttemptReset() -> Bool {
        guard let lastFailureTime = lastFailureTime else { return true }
        return Date().timeIntervalSince(lastFailureTime) >= resetTimeout
    }
    
    private func onSuccess() {
        failureCount = 0
        state = .closed
        lastFailureTime = nil
    }
    
    private func onFailure() {
        failureCount += 1
        lastFailureTime = Date()
        
        if failureCount >= failureThreshold {
            state = .open
        }
    }
    
    var currentState: State {
        return state
    }
    
    var metrics: (failureCount: Int, state: State) {
        return (failureCount, state)
    }
}

// MARK: - Async Semaphore
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() async {
        if waiters.isEmpty {
            value += 1
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}

// MARK: - Retry Extensions
extension SupabaseService {
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        configuration: RetryConfiguration = .default
    ) async throws -> T {
        return try await RetryService.shared.executeWithRetry(
            operation: operation,
            configuration: configuration,
            context: ErrorContext(additionalInfo: ["service": "SupabaseService"])
        )
    }
}

extension AIService {
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        configuration: RetryConfiguration = .aggressive
    ) async throws -> T {
        return try await RetryService.shared.executeWithRetry(
            operation: operation,
            configuration: configuration,
            context: ErrorContext(additionalInfo: ["service": "AIService"])
        )
    }
}

extension StripeService {
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        configuration: RetryConfiguration = .conservative
    ) async throws -> T {
        return try await RetryService.shared.executeWithRetry(
            operation: operation,
            configuration: configuration,
            context: ErrorContext(additionalInfo: ["service": "StripeService"])
        )
    }
}