import XCTest
import Combine
@testable import RoomFinderAI

class NetworkInterceptorServiceTests: XCTestCase {
    var interceptorService: NetworkInterceptorService!
    var mockInterceptor: MockNetworkInterceptor!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        interceptorService = NetworkInterceptorService.shared
        mockInterceptor = MockNetworkInterceptor()
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing interceptors and requests
        interceptorService.clearActiveRequests()
    }
    
    override func tearDown() {
        interceptorService.clearActiveRequests()
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Interceptor Management Tests
    
    func testAddInterceptor() {
        // Given
        let initialCount = interceptorService.getInterceptors().count
        
        // When
        interceptorService.addInterceptor(mockInterceptor)
        
        // Then
        XCTAssertEqual(interceptorService.getInterceptors().count, initialCount + 1)
        XCTAssertTrue(interceptorService.getInterceptors().contains { $0 is MockNetworkInterceptor })
    }
    
    func testRemoveInterceptor() {
        // Given
        interceptorService.addInterceptor(mockInterceptor)
        let countWithMock = interceptorService.getInterceptors().count
        
        // When
        interceptorService.removeInterceptor(ofType: MockNetworkInterceptor.self)
        
        // Then
        XCTAssertEqual(interceptorService.getInterceptors().count, countWithMock - 1)
        XCTAssertFalse(interceptorService.getInterceptors().contains { $0 is MockNetworkInterceptor })
    }
    
    func testInterceptorPriority() {
        // Given
        let lowPriorityInterceptor = MockNetworkInterceptor(priority: 1000)
        let highPriorityInterceptor = MockNetworkInterceptor(priority: 1)
        
        // When
        interceptorService.addInterceptor(lowPriorityInterceptor)
        interceptorService.addInterceptor(highPriorityInterceptor)
        
        // Then
        let interceptors = interceptorService.getInterceptors()
        let mockInterceptors = interceptors.compactMap { $0 as? MockNetworkInterceptor }
        
        XCTAssertEqual(mockInterceptors.count, 2)
        XCTAssertTrue(mockInterceptors[0].priority < mockInterceptors[1].priority)
    }
    
    // MARK: - Request Interception Tests
    
    func testRequestInterception() async throws {
        // Given
        interceptorService.addInterceptor(mockInterceptor)
        let originalRequest = URLRequest(url: URL(string: "https://example.com")!)
        
        // When
        let interceptedRequest = try await interceptorService.intercept(request: originalRequest)
        
        // Then
        XCTAssertEqual(mockInterceptor.requestInterceptCount, 1)
        XCTAssertEqual(interceptedRequest.url, originalRequest.url)
        XCTAssertEqual(interceptedRequest.value(forHTTPHeaderField: "X-Test"), "intercepted")
    }
    
    func testRequestInterceptionWithError() async {
        // Given
        let errorInterceptor = MockNetworkInterceptor(shouldThrowError: true)
        interceptorService.addInterceptor(errorInterceptor)
        let originalRequest = URLRequest(url: URL(string: "https://example.com")!)
        
        // When & Then
        do {
            _ = try await interceptorService.intercept(request: originalRequest)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is MockNetworkError)
        }
    }
    
    // MARK: - Response Interception Tests
    
    func testResponseInterception() async {
        // Given
        interceptorService.addInterceptor(mockInterceptor)
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
        let data = "test data".data(using: .utf8)
        
        // When
        let interceptedResponse = await interceptorService.intercept(
            response: response,
            data: data,
            error: nil,
            for: request
        )
        
        // Then
        XCTAssertEqual(mockInterceptor.responseInterceptCount, 1)
        XCTAssertNotNil(interceptedResponse.response)
        XCTAssertNotNil(interceptedResponse.data)
        XCTAssertNil(interceptedResponse.error)
    }
    
    func testResponseInterceptionWithError() async {
        // Given
        interceptorService.addInterceptor(mockInterceptor)
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let error = NSError(domain: "TestError", code: 404, userInfo: nil)
        
        // When
        let interceptedResponse = await interceptorService.intercept(
            response: nil,
            data: nil,
            error: error,
            for: request
        )
        
        // Then
        XCTAssertEqual(mockInterceptor.responseInterceptCount, 1)
        XCTAssertNotNil(interceptedResponse.error)
    }
    
    // MARK: - Active Requests Tests
    
    func testActiveRequestsTracking() async throws {
        // Given
        let request = URLRequest(url: URL(string: "https://example.com")!)
        
        // When
        _ = try await interceptorService.intercept(request: request)
        
        // Then
        XCTAssertEqual(interceptorService.activeRequests.count, 1)
        let activeRequest = interceptorService.activeRequests.values.first
        XCTAssertNotNil(activeRequest)
        XCTAssertEqual(activeRequest?.status, .intercepted)
    }
    
    func testActiveRequestsClearing() async throws {
        // Given
        let request = URLRequest(url: URL(string: "https://example.com")!)
        _ = try await interceptorService.intercept(request: request)
        
        // When
        interceptorService.clearActiveRequests()
        
        // Then
        XCTAssertEqual(interceptorService.activeRequests.count, 0)
    }
    
    // MARK: - Statistics Tests
    
    func testRequestStatisticsUpdate() async throws {
        // Given
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
        let data = "test data".data(using: .utf8)
        
        let initialStats = interceptorService.requestStatistics
        
        // When
        let interceptedRequest = try await interceptorService.intercept(request: request)
        _ = await interceptorService.intercept(response: response, data: data, error: nil, for: interceptedRequest)
        
        // Give time for statistics to update
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        let updatedStats = interceptorService.requestStatistics
        XCTAssertEqual(updatedStats.totalRequests, initialStats.totalRequests + 1)
        XCTAssertEqual(updatedStats.totalSuccesses, initialStats.totalSuccesses + 1)
    }
    
    // MARK: - Built-in Interceptors Tests
    
    func testAuthenticationInterceptor() async throws {
        // Given
        let authInterceptor = AuthenticationInterceptor()
        let request = URLRequest(url: URL(string: "https://api.example.com")!)
        
        // When
        let interceptedRequest = try await authInterceptor.intercept(request: request)
        
        // Then
        XCTAssertNotNil(interceptedRequest.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(interceptedRequest.value(forHTTPHeaderField: "Authorization")?.starts(with: "Bearer ") ?? false)
    }
    
    func testHeaderInterceptor() async throws {
        // Given
        let headerInterceptor = HeaderInterceptor()
        let request = URLRequest(url: URL(string: "https://api.example.com")!)
        
        // When
        let interceptedRequest = try await headerInterceptor.intercept(request: request)
        
        // Then
        XCTAssertEqual(interceptedRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(interceptedRequest.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(interceptedRequest.value(forHTTPHeaderField: "User-Agent"), "RoomFinderAI/1.0")
        XCTAssertEqual(interceptedRequest.value(forHTTPHeaderField: "X-Platform"), "iOS")
        XCTAssertNotNil(interceptedRequest.value(forHTTPHeaderField: "X-App-Version"))
        XCTAssertNotNil(interceptedRequest.value(forHTTPHeaderField: "X-Correlation-ID"))
    }
    
    func testErrorHandlingInterceptor() async {
        // Given
        let errorInterceptor = ErrorHandlingInterceptor()
        let request = URLRequest(url: URL(string: "https://api.example.com")!)
        
        // Test 401 error
        let unauthorizedResponse = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)
        let unauthorizedInterceptedResponse = InterceptedResponse(response: unauthorizedResponse, data: nil, error: nil, timestamp: Date())
        
        // When
        let result = await errorInterceptor.intercept(response: unauthorizedInterceptedResponse, for: request)
        
        // Then
        XCTAssertTrue(result.error is AuthError)
    }
    
    func testRateLimitInterceptor() async throws {
        // Given
        let rateLimitInterceptor = RateLimitInterceptor()
        let request = URLRequest(url: URL(string: "https://api.example.com")!)
        
        // When - Make multiple requests quickly
        for _ in 0..<5 {
            _ = try await rateLimitInterceptor.intercept(request: request)
        }
        
        // Then - Should not throw rate limit error for small number of requests
        XCTAssertTrue(true) // If we get here, no rate limit error was thrown
    }
    
    func testRequestTimeoutInterceptor() async throws {
        // Given
        let timeoutInterceptor = RequestTimeoutInterceptor()
        
        // Test GET request
        let getRequest = URLRequest(url: URL(string: "https://api.example.com")!)
        let interceptedGetRequest = try await timeoutInterceptor.intercept(request: getRequest)
        
        // Test POST request
        var postRequest = URLRequest(url: URL(string: "https://api.example.com")!)
        postRequest.httpMethod = "POST"
        let interceptedPostRequest = try await timeoutInterceptor.intercept(request: postRequest)
        
        // Then
        XCTAssertEqual(interceptedGetRequest.timeoutInterval, 30.0)
        XCTAssertEqual(interceptedPostRequest.timeoutInterval, 60.0)
    }
    
    // MARK: - Request Statistics Tests
    
    func testRequestStatisticsInitialization() {
        // Given
        let statistics = RequestStatistics()
        
        // Then
        XCTAssertEqual(statistics.totalRequests, 0)
        XCTAssertEqual(statistics.totalSuccesses, 0)
        XCTAssertEqual(statistics.totalErrors, 0)
        XCTAssertEqual(statistics.averageResponseTime, 0)
        XCTAssertTrue(statistics.requestsByHost.isEmpty)
        XCTAssertTrue(statistics.errorsByType.isEmpty)
        XCTAssertEqual(statistics.successRate, 0)
        XCTAssertEqual(statistics.errorRate, 0)
    }
    
    func testRequestStatisticsUpdateRequest() {
        // Given
        var statistics = RequestStatistics()
        let request = URLRequest(url: URL(string: "https://api.example.com")!)
        let interceptedRequest = InterceptedRequest(
            id: "test_1",
            originalRequest: request,
            modifiedRequest: request,
            timestamp: Date(),
            status: .completed,
            response: InterceptedResponse(response: nil, data: nil, error: nil, timestamp: Date()),
            duration: 0.5
        )
        
        // When
        statistics.updateRequest(interceptedRequest)
        
        // Then
        XCTAssertEqual(statistics.requestsByHost["api.example.com"], 1)
        XCTAssertEqual(statistics.averageResponseTime, 0.5)
    }
    
    func testRequestStatisticsCalculations() {
        // Given
        var statistics = RequestStatistics()
        statistics.totalRequests = 10
        statistics.totalSuccesses = 8
        statistics.totalErrors = 2
        
        // When
        let successRate = statistics.successRate
        let errorRate = statistics.errorRate
        
        // Then
        XCTAssertEqual(successRate, 0.8, accuracy: 0.001)
        XCTAssertEqual(errorRate, 0.2, accuracy: 0.001)
    }
    
    // MARK: - Intercepted Request Tests
    
    func testInterceptedRequestInitialization() {
        // Given
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let timestamp = Date()
        
        // When
        let interceptedRequest = InterceptedRequest(
            id: "test_1",
            originalRequest: request,
            modifiedRequest: request,
            timestamp: timestamp,
            status: .pending
        )
        
        // Then
        XCTAssertEqual(interceptedRequest.id, "test_1")
        XCTAssertEqual(interceptedRequest.originalRequest.url, request.url)
        XCTAssertEqual(interceptedRequest.modifiedRequest.url, request.url)
        XCTAssertEqual(interceptedRequest.timestamp, timestamp)
        XCTAssertEqual(interceptedRequest.status, .pending)
        XCTAssertNil(interceptedRequest.response)
        XCTAssertNil(interceptedRequest.duration)
    }
    
    // MARK: - Intercepted Response Tests
    
    func testInterceptedResponseInitialization() {
        // Given
        let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        let data = "test data".data(using: .utf8)
        let error = NSError(domain: "TestError", code: 404, userInfo: nil)
        let timestamp = Date()
        
        // When
        let interceptedResponse = InterceptedResponse(
            response: response,
            data: data,
            error: error,
            timestamp: timestamp
        )
        
        // Then
        XCTAssertEqual(interceptedResponse.response as? HTTPURLResponse, response)
        XCTAssertEqual(interceptedResponse.data, data)
        XCTAssertNotNil(interceptedResponse.error)
        XCTAssertEqual(interceptedResponse.timestamp, timestamp)
    }
}

// MARK: - Mock Network Interceptor

class MockNetworkInterceptor: NetworkInterceptor {
    let priority: Int
    private let shouldThrowError: Bool
    
    var requestInterceptCount = 0
    var responseInterceptCount = 0
    
    init(priority: Int = 500, shouldThrowError: Bool = false) {
        self.priority = priority
        self.shouldThrowError = shouldThrowError
    }
    
    func intercept(request: URLRequest) async throws -> URLRequest {
        requestInterceptCount += 1
        
        if shouldThrowError {
            throw MockNetworkError.interceptorError
        }
        
        var modifiedRequest = request
        modifiedRequest.setValue("intercepted", forHTTPHeaderField: "X-Test")
        return modifiedRequest
    }
    
    func intercept(response: InterceptedResponse, for request: URLRequest) async -> InterceptedResponse {
        responseInterceptCount += 1
        return response
    }
}

// MARK: - Mock Network Error

enum MockNetworkError: Error {
    case interceptorError
}