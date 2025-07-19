import Foundation
import Combine

// MARK: - Rate Limiting Service
class RateLimitingService: ObservableObject {
    static let shared = RateLimitingService()
    
    // MARK: - Properties
    @Published var activeRateLimits: [String: RateLimit] = [:]
    @Published var throttledRequests: [String: ThrottledRequest] = [:]
    @Published var rateLimitStatistics: RateLimitStatistics = RateLimitStatistics()
    
    private let queue = DispatchQueue(label: "RateLimitingService", qos: .utility)
    private var cleanupTimer: Timer?
    
    // MARK: - Initialization
    private init() {
        setupCleanupTimer()
    }
    
    // MARK: - Setup
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.cleanupExpiredLimits()
        }
    }
    
    // MARK: - Rate Limiting
    func checkRateLimit(for endpoint: String, rateLimitConfig: RateLimitConfig = .default) async throws {
        let key = rateLimitKey(for: endpoint, config: rateLimitConfig)
        
        try await queue.sync {
            var rateLimit = activeRateLimits[key] ?? RateLimit(
                endpoint: endpoint,
                config: rateLimitConfig,
                windowStart: Date()
            )
            
            // Check if we need to reset the window
            if Date().timeIntervalSince(rateLimit.windowStart) >= rateLimitConfig.windowDuration {
                rateLimit.reset()
            }
            
            // Check if rate limit is exceeded
            if rateLimit.requestCount >= rateLimitConfig.maxRequests {
                let retryAfter = rateLimitConfig.windowDuration - Date().timeIntervalSince(rateLimit.windowStart)
                
                DispatchQueue.main.async {
                    self.rateLimitStatistics.rateLimitHits += 1
                }
                
                LoggingService.shared.warning(
                    "Rate limit exceeded for endpoint: \(endpoint)",
                    category: .network,
                    metadata: [
                        "endpoint": endpoint,
                        "requestCount": rateLimit.requestCount,
                        "maxRequests": rateLimitConfig.maxRequests,
                        "retryAfter": retryAfter
                    ]
                )
                
                throw RateLimitError.rateLimitExceeded(retryAfter: retryAfter)
            }
            
            // Increment request count
            rateLimit.requestCount += 1
            rateLimit.lastRequest = Date()
            activeRateLimits[key] = rateLimit
            
            DispatchQueue.main.async {
                self.rateLimitStatistics.totalRequests += 1
            }
        }
    }
    
    // MARK: - Throttling
    func throttleRequest(for endpoint: String, throttleConfig: ThrottleConfig = .default) async throws {
        let key = throttleKey(for: endpoint, config: throttleConfig)
        
        try await queue.sync {
            if let existingRequest = throttledRequests[key] {
                let timeSinceLastRequest = Date().timeIntervalSince(existingRequest.lastRequest)
                
                if timeSinceLastRequest < throttleConfig.minimumInterval {
                    let waitTime = throttleConfig.minimumInterval - timeSinceLastRequest
                    
                    DispatchQueue.main.async {
                        self.rateLimitStatistics.throttledRequests += 1
                    }
                    
                    LoggingService.shared.info(
                        "Request throttled for endpoint: \(endpoint)",
                        category: .network,
                        metadata: [
                            "endpoint": endpoint,
                            "waitTime": waitTime,
                            "minimumInterval": throttleConfig.minimumInterval
                        ]
                    )
                    
                    // Wait for the required interval
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
            
            // Update throttled request
            throttledRequests[key] = ThrottledRequest(
                endpoint: endpoint,
                config: throttleConfig,
                lastRequest: Date()
            )
        }
    }
    
    // MARK: - Token Bucket Rate Limiting
    func checkTokenBucket(for endpoint: String, tokenBucketConfig: TokenBucketConfig = .default) async throws {
        let key = tokenBucketKey(for: endpoint, config: tokenBucketConfig)
        
        try await queue.sync {
            var tokenBucket = activeTokenBuckets[key] ?? TokenBucket(
                endpoint: endpoint,
                config: tokenBucketConfig,
                tokens: tokenBucketConfig.capacity,
                lastRefill: Date()
            )
            
            // Refill tokens based on time elapsed
            let now = Date()
            let timeSinceLastRefill = now.timeIntervalSince(tokenBucket.lastRefill)
            let tokensToAdd = Int(timeSinceLastRefill * tokenBucketConfig.refillRate)
            
            if tokensToAdd > 0 {
                tokenBucket.tokens = min(tokenBucket.tokens + tokensToAdd, tokenBucketConfig.capacity)
                tokenBucket.lastRefill = now
            }
            
            // Check if we have tokens available
            if tokenBucket.tokens < 1 {
                let waitTime = 1.0 / tokenBucketConfig.refillRate
                
                DispatchQueue.main.async {
                    self.rateLimitStatistics.tokenBucketHits += 1
                }
                
                LoggingService.shared.warning(
                    "Token bucket empty for endpoint: \(endpoint)",
                    category: .network,
                    metadata: [
                        "endpoint": endpoint,
                        "tokens": tokenBucket.tokens,
                        "capacity": tokenBucketConfig.capacity,
                        "waitTime": waitTime
                    ]
                )
                
                throw RateLimitError.tokenBucketEmpty(retryAfter: waitTime)
            }
            
            // Consume a token
            tokenBucket.tokens -= 1
            activeTokenBuckets[key] = tokenBucket
            
            DispatchQueue.main.async {
                self.rateLimitStatistics.tokenBucketRequests += 1
            }
        }
    }
    
    // MARK: - Adaptive Rate Limiting
    func checkAdaptiveRateLimit(for endpoint: String, adaptiveConfig: AdaptiveRateLimitConfig = .default) async throws {
        let key = adaptiveRateLimitKey(for: endpoint, config: adaptiveConfig)
        
        try await queue.sync {
            var adaptiveLimit = activeAdaptiveLimits[key] ?? AdaptiveRateLimit(
                endpoint: endpoint,
                config: adaptiveConfig,
                currentLimit: adaptiveConfig.initialLimit,
                successCount: 0,
                errorCount: 0,
                windowStart: Date()
            )
            
            // Check if we need to reset the window
            if Date().timeIntervalSince(adaptiveLimit.windowStart) >= adaptiveConfig.windowDuration {
                adaptiveLimit.adjustLimit()
                adaptiveLimit.reset()
            }
            
            // Check if rate limit is exceeded
            if adaptiveLimit.requestCount >= adaptiveLimit.currentLimit {
                let retryAfter = adaptiveConfig.windowDuration - Date().timeIntervalSince(adaptiveLimit.windowStart)
                
                DispatchQueue.main.async {
                    self.rateLimitStatistics.adaptiveRateLimitHits += 1
                }
                
                throw RateLimitError.adaptiveRateLimitExceeded(retryAfter: retryAfter)
            }
            
            // Increment request count
            adaptiveLimit.requestCount += 1
            adaptiveLimit.lastRequest = Date()
            activeAdaptiveLimits[key] = adaptiveLimit
            
            DispatchQueue.main.async {
                self.rateLimitStatistics.adaptiveRateLimitRequests += 1
            }
        }
    }
    
    // MARK: - Response Handling
    func handleResponse(for endpoint: String, isSuccess: Bool, statusCode: Int?) {
        queue.async {
            // Update adaptive rate limits based on response
            for (key, adaptiveLimit) in self.activeAdaptiveLimits {
                if adaptiveLimit.endpoint == endpoint {
                    var updatedLimit = adaptiveLimit
                    
                    if isSuccess {
                        updatedLimit.successCount += 1
                    } else {
                        updatedLimit.errorCount += 1
                        
                        // Handle specific error codes
                        if let statusCode = statusCode {
                            switch statusCode {
                            case 429: // Too Many Requests
                                updatedLimit.currentLimit = max(1, Int(Double(updatedLimit.currentLimit) * 0.5))
                            case 500...599: // Server errors
                                updatedLimit.currentLimit = max(1, Int(Double(updatedLimit.currentLimit) * 0.8))
                            default:
                                break
                            }
                        }
                    }
                    
                    self.activeAdaptiveLimits[key] = updatedLimit
                }
            }
            
            // Update statistics
            DispatchQueue.main.async {
                if isSuccess {
                    self.rateLimitStatistics.successfulRequests += 1
                } else {
                    self.rateLimitStatistics.failedRequests += 1
                }
            }
        }
    }
    
    // MARK: - Management
    func clearRateLimits() {
        queue.async {
            self.activeRateLimits.removeAll()
            self.throttledRequests.removeAll()
            self.activeTokenBuckets.removeAll()
            self.activeAdaptiveLimits.removeAll()
            
            DispatchQueue.main.async {
                self.rateLimitStatistics = RateLimitStatistics()
            }
        }
    }
    
    func getRateLimitStatus(for endpoint: String) -> RateLimitStatus {
        let rateLimitKey = rateLimitKey(for: endpoint, config: .default)
        let throttleKey = throttleKey(for: endpoint, config: .default)
        
        return RateLimitStatus(
            endpoint: endpoint,
            rateLimit: activeRateLimits[rateLimitKey],
            throttledRequest: throttledRequests[throttleKey],
            isRateLimited: activeRateLimits[rateLimitKey]?.isLimited ?? false,
            isThrottled: throttledRequests[throttleKey]?.isThrottled ?? false
        )
    }
    
    // MARK: - Private Properties
    private var activeTokenBuckets: [String: TokenBucket] = [:]
    private var activeAdaptiveLimits: [String: AdaptiveRateLimit] = [:]
    
    // MARK: - Private Methods
    private func cleanupExpiredLimits() {
        queue.async {
            let now = Date()
            
            // Clean up expired rate limits
            self.activeRateLimits = self.activeRateLimits.filter { _, rateLimit in
                now.timeIntervalSince(rateLimit.windowStart) < rateLimit.config.windowDuration * 2
            }
            
            // Clean up old throttled requests
            self.throttledRequests = self.throttledRequests.filter { _, request in
                now.timeIntervalSince(request.lastRequest) < request.config.minimumInterval * 10
            }
            
            // Clean up old token buckets
            self.activeTokenBuckets = self.activeTokenBuckets.filter { _, bucket in
                now.timeIntervalSince(bucket.lastRefill) < 3600 // 1 hour
            }
            
            // Clean up old adaptive limits
            self.activeAdaptiveLimits = self.activeAdaptiveLimits.filter { _, limit in
                now.timeIntervalSince(limit.windowStart) < limit.config.windowDuration * 2
            }
        }
    }
    
    private func rateLimitKey(for endpoint: String, config: RateLimitConfig) -> String {
        return "rateLimit_\(endpoint)_\(config.maxRequests)_\(config.windowDuration)"
    }
    
    private func throttleKey(for endpoint: String, config: ThrottleConfig) -> String {
        return "throttle_\(endpoint)_\(config.minimumInterval)"
    }
    
    private func tokenBucketKey(for endpoint: String, config: TokenBucketConfig) -> String {
        return "tokenBucket_\(endpoint)_\(config.capacity)_\(config.refillRate)"
    }
    
    private func adaptiveRateLimitKey(for endpoint: String, config: AdaptiveRateLimitConfig) -> String {
        return "adaptiveRateLimit_\(endpoint)_\(config.initialLimit)_\(config.windowDuration)"
    }
}

// MARK: - Rate Limit Error
enum RateLimitError: Error, LocalizedError {
    case rateLimitExceeded(retryAfter: TimeInterval)
    case tokenBucketEmpty(retryAfter: TimeInterval)
    case adaptiveRateLimitExceeded(retryAfter: TimeInterval)
    case throttled(retryAfter: TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded(let retryAfter):
            return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds."
        case .tokenBucketEmpty(let retryAfter):
            return "Token bucket empty. Retry after \(String(format: "%.2f", retryAfter)) seconds."
        case .adaptiveRateLimitExceeded(let retryAfter):
            return "Adaptive rate limit exceeded. Retry after \(Int(retryAfter)) seconds."
        case .throttled(let retryAfter):
            return "Request throttled. Retry after \(String(format: "%.2f", retryAfter)) seconds."
        }
    }
    
    var retryAfter: TimeInterval {
        switch self {
        case .rateLimitExceeded(let retryAfter),
             .tokenBucketEmpty(let retryAfter),
             .adaptiveRateLimitExceeded(let retryAfter),
             .throttled(let retryAfter):
            return retryAfter
        }
    }
}

// MARK: - Rate Limit Configuration
struct RateLimitConfig {
    let maxRequests: Int
    let windowDuration: TimeInterval
    let burstAllowance: Int
    
    static let `default` = RateLimitConfig(maxRequests: 100, windowDuration: 60, burstAllowance: 10)
    static let strict = RateLimitConfig(maxRequests: 50, windowDuration: 60, burstAllowance: 5)
    static let lenient = RateLimitConfig(maxRequests: 200, windowDuration: 60, burstAllowance: 20)
}

// MARK: - Throttle Configuration
struct ThrottleConfig {
    let minimumInterval: TimeInterval
    let burstSize: Int
    
    static let `default` = ThrottleConfig(minimumInterval: 0.1, burstSize: 5)
    static let strict = ThrottleConfig(minimumInterval: 0.5, burstSize: 2)
    static let lenient = ThrottleConfig(minimumInterval: 0.05, burstSize: 10)
}

// MARK: - Token Bucket Configuration
struct TokenBucketConfig {
    let capacity: Int
    let refillRate: Double // tokens per second
    
    static let `default` = TokenBucketConfig(capacity: 10, refillRate: 1.0)
    static let strict = TokenBucketConfig(capacity: 5, refillRate: 0.5)
    static let lenient = TokenBucketConfig(capacity: 20, refillRate: 2.0)
}

// MARK: - Adaptive Rate Limit Configuration
struct AdaptiveRateLimitConfig {
    let initialLimit: Int
    let windowDuration: TimeInterval
    let increaseRate: Double
    let decreaseRate: Double
    let minLimit: Int
    let maxLimit: Int
    
    static let `default` = AdaptiveRateLimitConfig(
        initialLimit: 50,
        windowDuration: 60,
        increaseRate: 1.1,
        decreaseRate: 0.9,
        minLimit: 10,
        maxLimit: 200
    )
}

// MARK: - Rate Limit Models
struct RateLimit {
    let endpoint: String
    let config: RateLimitConfig
    var windowStart: Date
    var requestCount: Int = 0
    var lastRequest: Date?
    
    var isLimited: Bool {
        return requestCount >= config.maxRequests
    }
    
    var remainingRequests: Int {
        return max(0, config.maxRequests - requestCount)
    }
    
    var resetTime: Date {
        return windowStart.addingTimeInterval(config.windowDuration)
    }
    
    mutating func reset() {
        windowStart = Date()
        requestCount = 0
        lastRequest = nil
    }
}

struct ThrottledRequest {
    let endpoint: String
    let config: ThrottleConfig
    var lastRequest: Date
    
    var isThrottled: Bool {
        return Date().timeIntervalSince(lastRequest) < config.minimumInterval
    }
    
    var nextAllowedTime: Date {
        return lastRequest.addingTimeInterval(config.minimumInterval)
    }
}

struct TokenBucket {
    let endpoint: String
    let config: TokenBucketConfig
    var tokens: Int
    var lastRefill: Date
    
    var isEmpty: Bool {
        return tokens < 1
    }
    
    var fillPercentage: Double {
        return Double(tokens) / Double(config.capacity)
    }
}

struct AdaptiveRateLimit {
    let endpoint: String
    let config: AdaptiveRateLimitConfig
    var currentLimit: Int
    var successCount: Int
    var errorCount: Int
    var windowStart: Date
    var requestCount: Int = 0
    var lastRequest: Date?
    
    var isLimited: Bool {
        return requestCount >= currentLimit
    }
    
    var successRate: Double {
        let total = successCount + errorCount
        guard total > 0 else { return 0 }
        return Double(successCount) / Double(total)
    }
    
    mutating func adjustLimit() {
        if successRate > 0.95 && errorCount < 5 {
            // Increase limit if success rate is high
            currentLimit = min(
                Int(Double(currentLimit) * config.increaseRate),
                config.maxLimit
            )
        } else if successRate < 0.8 || errorCount > 10 {
            // Decrease limit if success rate is low or many errors
            currentLimit = max(
                Int(Double(currentLimit) * config.decreaseRate),
                config.minLimit
            )
        }
    }
    
    mutating func reset() {
        windowStart = Date()
        requestCount = 0
        successCount = 0
        errorCount = 0
        lastRequest = nil
    }
}

struct RateLimitStatus {
    let endpoint: String
    let rateLimit: RateLimit?
    let throttledRequest: ThrottledRequest?
    let isRateLimited: Bool
    let isThrottled: Bool
    
    var nextAllowedTime: Date? {
        if isRateLimited, let rateLimit = rateLimit {
            return rateLimit.resetTime
        }
        if isThrottled, let throttledRequest = throttledRequest {
            return throttledRequest.nextAllowedTime
        }
        return nil
    }
}

struct RateLimitStatistics {
    var totalRequests: Int = 0
    var rateLimitHits: Int = 0
    var throttledRequests: Int = 0
    var tokenBucketHits: Int = 0
    var tokenBucketRequests: Int = 0
    var adaptiveRateLimitHits: Int = 0
    var adaptiveRateLimitRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    
    var rateLimitHitRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(rateLimitHits) / Double(totalRequests)
    }
    
    var throttleRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(throttledRequests) / Double(totalRequests)
    }
    
    var successRate: Double {
        let total = successfulRequests + failedRequests
        guard total > 0 else { return 0 }
        return Double(successfulRequests) / Double(total)
    }
    
    var tokenBucketHitRate: Double {
        guard tokenBucketRequests > 0 else { return 0 }
        return Double(tokenBucketHits) / Double(tokenBucketRequests)
    }
    
    var adaptiveRateLimitHitRate: Double {
        guard adaptiveRateLimitRequests > 0 else { return 0 }
        return Double(adaptiveRateLimitHits) / Double(adaptiveRateLimitRequests)
    }
}