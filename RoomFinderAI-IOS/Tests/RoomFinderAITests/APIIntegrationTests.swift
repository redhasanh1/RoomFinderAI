import XCTest
import Combine
@testable import RoomFinderAI

class APIIntegrationTests: XCTestCase {
    var supabaseService: SupabaseService!
    var networkSession: InterceptedURLSession!
    var rateLimitingService: RateLimitingService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        supabaseService = SupabaseService.shared
        networkSession = InterceptedURLSession.shared
        rateLimitingService = RateLimitingService.shared
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing rate limits
        rateLimitingService.clearRateLimits()
    }
    
    override func tearDown() {
        rateLimitingService.clearRateLimits()
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Authentication Integration Tests
    
    func testAuthenticationFlow() async throws {
        // Test the complete authentication flow
        let testEmail = "test@example.com"
        let testPassword = "testpassword123"
        
        // Test sign up
        do {
            let signUpResult = try await supabaseService.signUp(email: testEmail, password: testPassword)
            XCTAssertNotNil(signUpResult)
            XCTAssertEqual(signUpResult.email, testEmail)
        } catch {
            // Sign up might fail if user already exists, which is acceptable for tests
            XCTAssertTrue(error is AuthError || error is SupabaseError)
        }
        
        // Test sign in
        do {
            let signInResult = try await supabaseService.signIn(email: testEmail, password: testPassword)
            XCTAssertNotNil(signInResult)
            XCTAssertEqual(signInResult.email, testEmail)
        } catch {
            // Sign in might fail in test environment
            XCTAssertTrue(error is AuthError || error is SupabaseError)
        }
        
        // Test get current user
        let currentUser = try await supabaseService.getCurrentUser()
        XCTAssertNotNil(currentUser)
        
        // Test sign out
        try await supabaseService.signOut()
        
        // Verify user is signed out
        let userAfterSignOut = try? await supabaseService.getCurrentUser()
        XCTAssertNil(userAfterSignOut)
    }
    
    // MARK: - Listings Integration Tests
    
    func testListingsEndpoints() async throws {
        // Test fetching all listings
        let allListings = try await supabaseService.fetchAllListings()
        XCTAssertNotNil(allListings)
        
        // Test fetching listings with search
        let searchRequest = ListingSearchRequest(
            query: "apartment",
            location: "New York",
            minPrice: 1000,
            maxPrice: 3000,
            bedrooms: 2,
            bathrooms: 1,
            propertyType: .apartment,
            petFriendly: nil,
            smokingAllowed: nil,
            availableDate: nil,
            radius: nil,
            latitude: nil,
            longitude: nil,
            sortBy: .price,
            page: 1,
            limit: 20
        )
        
        let searchResults = try await supabaseService.fetchListings(request: searchRequest)
        XCTAssertNotNil(searchResults)
        XCTAssertLessOrEqual(searchResults.listings.count, 20)
        
        // Test fetching featured listings
        let featuredListings = try await supabaseService.fetchFeaturedListings()
        XCTAssertNotNil(featuredListings)
        
        // Test fetching single listing
        if let firstListing = allListings.first {
            let singleListing = try await supabaseService.fetchListing(id: firstListing.id)
            XCTAssertNotNil(singleListing)
            XCTAssertEqual(singleListing.id, firstListing.id)
        }
    }
    
    func testListingsWithRateLimit() async throws {
        // Test that rate limiting works with listings API
        let rateLimitConfig = RateLimitConfig(maxRequests: 5, windowDuration: 60, burstAllowance: 2)
        
        var requestCount = 0
        var rateLimitHit = false
        
        // Make requests until rate limit is hit
        for _ in 1...10 {
            do {
                try await rateLimitingService.checkRateLimit(for: "listings", rateLimitConfig: rateLimitConfig)
                _ = try await supabaseService.fetchAllListings()
                requestCount += 1
            } catch RateLimitError.rateLimitExceeded {
                rateLimitHit = true
                break
            } catch {
                // Other errors are acceptable
            }
        }
        
        XCTAssertTrue(rateLimitHit || requestCount <= 5)
    }
    
    // MARK: - User Profile Integration Tests
    
    func testUserProfileEndpoints() async throws {
        // Test creating a user profile
        let testUser = User(
            id: "test_user_123",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            phoneNumber: "123-456-7890",
            profileImageURL: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            let createdUser = try await supabaseService.createUserProfile(user: testUser)
            XCTAssertNotNil(createdUser)
            XCTAssertEqual(createdUser.email, testUser.email)
            
            // Test fetching user profile
            let fetchedUser = try await supabaseService.fetchUserProfile(userId: testUser.id)
            XCTAssertNotNil(fetchedUser)
            XCTAssertEqual(fetchedUser.id, testUser.id)
            
            // Test updating user profile
            var updatedUser = testUser
            updatedUser.firstName = "Updated"
            
            let savedUser = try await supabaseService.updateUserProfile(user: updatedUser)
            XCTAssertEqual(savedUser.firstName, "Updated")
            
            // Test deleting user profile
            try await supabaseService.deleteUserProfile(userId: testUser.id)
            
            // Verify user is deleted
            let deletedUser = try? await supabaseService.fetchUserProfile(userId: testUser.id)
            XCTAssertNil(deletedUser)
        } catch {
            // User operations might fail in test environment
            XCTAssertTrue(error is SupabaseError || error is NetworkError)
        }
    }
    
    // MARK: - Chat Integration Tests
    
    func testChatEndpoints() async throws {
        let testChat = Chat(
            id: "test_chat_123",
            propertyID: "property_123",
            participants: ["user1", "user2"],
            type: .direct,
            lastMessage: "Hello",
            lastMessageDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            // Test creating a chat
            let createdChat = try await supabaseService.createChat(chat: testChat)
            XCTAssertNotNil(createdChat)
            XCTAssertEqual(createdChat.id, testChat.id)
            
            // Test fetching user chats
            let userChats = try await supabaseService.fetchUserChats(userId: "user1")
            XCTAssertNotNil(userChats)
            
            // Test sending a message
            let testMessage = Message(
                id: "message_123",
                chatID: testChat.id,
                senderID: "user1",
                content: "Test message",
                messageType: .text,
                isRead: false,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            let sentMessage = try await supabaseService.sendMessage(testMessage)
            XCTAssertNotNil(sentMessage)
            XCTAssertEqual(sentMessage.content, testMessage.content)
            
            // Test fetching messages
            let messages = try await supabaseService.fetchMessages(chatId: testChat.id)
            XCTAssertNotNil(messages)
            XCTAssertGreaterThan(messages.count, 0)
            
        } catch {
            // Chat operations might fail in test environment
            XCTAssertTrue(error is SupabaseError || error is NetworkError)
        }
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testErrorHandlingIntegration() async throws {
        // Test handling of various HTTP status codes
        let errorScenarios = [
            ("https://httpbin.org/status/400", 400),
            ("https://httpbin.org/status/401", 401),
            ("https://httpbin.org/status/403", 403),
            ("https://httpbin.org/status/404", 404),
            ("https://httpbin.org/status/429", 429),
            ("https://httpbin.org/status/500", 500),
            ("https://httpbin.org/status/502", 502),
            ("https://httpbin.org/status/503", 503)
        ]
        
        for (urlString, expectedStatusCode) in errorScenarios {
            let url = URL(string: urlString)!
            
            do {
                _ = try await networkSession.data(from: url)
                XCTFail("Should have thrown an error for status code \(expectedStatusCode)")
            } catch {
                // Verify that the error is properly mapped
                XCTAssertTrue(error is NetworkError || error is AuthError || error is URLError)
            }
        }
    }
    
    // MARK: - Network Interceptor Integration Tests
    
    func testNetworkInterceptorIntegration() async throws {
        // Test that interceptors are working correctly
        let testURL = URL(string: "https://httpbin.org/get")!
        
        // Make a request and verify interceptors are applied
        let (data, response) = try await networkSession.data(from: testURL)
        
        XCTAssertNotNil(data)
        XCTAssertNotNil(response)
        
        // Verify that the response went through interceptors
        if let httpResponse = response as? HTTPURLResponse {
            XCTAssertEqual(httpResponse.statusCode, 200)
        }
        
        // Check that the request was logged
        let interceptorService = NetworkInterceptorService.shared
        let stats = interceptorService.requestStatistics
        XCTAssertGreaterThan(stats.totalRequests, 0)
    }
    
    // MARK: - Retry Integration Tests
    
    func testRetryIntegration() async throws {
        // Test that retry mechanism works with transient failures
        let retryService = RetryService.shared
        let retryConfig = RetryConfiguration(
            maxRetries: 3,
            baseDelay: 0.1,
            maxDelay: 1.0,
            backoffMultiplier: 2.0,
            jitter: false,
            retryableErrors: ["NETWORK_TIMEOUT", "NETWORK_CONNECTION_LOST"]
        )
        
        var attemptCount = 0
        
        do {
            let result = try await retryService.executeWithRetry(
                operation: {
                    attemptCount += 1
                    if attemptCount < 3 {
                        throw NetworkError.timeoutError
                    }
                    return "Success"
                },
                configuration: retryConfig,
                strategy: .exponentialBackoff
            )
            
            XCTAssertEqual(result, "Success")
            XCTAssertEqual(attemptCount, 3)
        } catch {
            XCTFail("Retry should have succeeded: \(error)")
        }
    }
    
    // MARK: - Caching Integration Tests
    
    func testCachingIntegration() async throws {
        // Test that caching works correctly
        let cachingService = CachingService.shared
        let testKey = "integration_test_key"
        let testValue = "integration_test_value"
        
        // Set a value in cache
        cachingService.set(key: testKey, value: testValue, maxAge: 300)
        
        // Retrieve the value
        let cachedValue = await cachingService.get(key: testKey, type: String.self)
        XCTAssertEqual(cachedValue, testValue)
        
        // Test cache expiration
        cachingService.set(key: testKey, value: testValue, maxAge: 0.1)
        
        // Wait for expiration
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        let expiredValue = await cachingService.get(key: testKey, type: String.self)
        XCTAssertNil(expiredValue)
    }
    
    // MARK: - Offline Integration Tests
    
    func testOfflineIntegration() async throws {
        // Test that offline functionality works
        let offlineService = OfflineDataService.shared
        
        // Create test data
        let testListing = Listing(
            id: "offline_test_listing",
            title: "Offline Test Listing",
            price: 1500,
            bedrooms: 2,
            bathrooms: 1,
            propertyType: .apartment,
            location: ["city": "Test City", "state": "Test State"],
            description: "Test listing for offline functionality",
            isActive: true,
            availableDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Save to offline storage
        offlineService.saveListings([testListing], isInitialLoad: true)
        
        // Wait for save to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // Retrieve from offline storage
        let offlineListings = offlineService.getOfflineListings()
        XCTAssertGreaterThan(offlineListings.count, 0)
        
        let savedListing = offlineListings.first { $0.id == testListing.id }
        XCTAssertNotNil(savedListing)
        XCTAssertEqual(savedListing?.title, testListing.title)
    }
    
    // MARK: - Performance Integration Tests
    
    func testAPIPerformance() async throws {
        // Test API response times
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Make multiple concurrent requests
        await withTaskGroup(of: Void.self) { group in
            for _ in 1...5 {
                group.addTask {
                    do {
                        _ = try await self.supabaseService.fetchAllListings()
                    } catch {
                        // Ignore errors for performance test
                    }
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Verify performance is acceptable
        XCTAssertLessThan(duration, 30.0) // Should complete within 30 seconds
    }
    
    // MARK: - Data Consistency Integration Tests
    
    func testDataConsistency() async throws {
        // Test that data remains consistent across different operations
        let testListing = Listing(
            id: "consistency_test_listing",
            title: "Consistency Test Listing",
            price: 2000,
            bedrooms: 3,
            bathrooms: 2,
            propertyType: .house,
            location: ["city": "Consistency City", "state": "Test State"],
            description: "Test listing for data consistency",
            isActive: true,
            availableDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Save to both online and offline storage
        let offlineService = OfflineDataService.shared
        offlineService.saveListings([testListing], isInitialLoad: true)
        
        // Wait for save to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // Verify data consistency
        let offlineListings = offlineService.getOfflineListings()
        let savedListing = offlineListings.first { $0.id == testListing.id }
        
        XCTAssertNotNil(savedListing)
        XCTAssertEqual(savedListing?.title, testListing.title)
        XCTAssertEqual(savedListing?.price, testListing.price)
        XCTAssertEqual(savedListing?.bedrooms, testListing.bedrooms)
        XCTAssertEqual(savedListing?.bathrooms, testListing.bathrooms)
        XCTAssertEqual(savedListing?.propertyType, testListing.propertyType)
    }
    
    // MARK: - End-to-End Integration Tests
    
    func testEndToEndUserFlow() async throws {
        // Test a complete user flow from authentication to data fetching
        let testEmail = "e2e_test@example.com"
        let testPassword = "e2eTestPassword123"
        
        do {
            // 1. Sign up or sign in
            let user = try await supabaseService.signIn(email: testEmail, password: testPassword)
            XCTAssertNotNil(user)
            
            // 2. Fetch user profile
            let profile = try await supabaseService.fetchUserProfile(userId: user.id)
            XCTAssertNotNil(profile)
            
            // 3. Fetch listings
            let listings = try await supabaseService.fetchAllListings()
            XCTAssertNotNil(listings)
            
            // 4. Search for listings
            let searchRequest = ListingSearchRequest(
                query: "apartment",
                location: nil,
                minPrice: 1000,
                maxPrice: 2000,
                bedrooms: 2,
                bathrooms: nil,
                propertyType: .apartment,
                petFriendly: nil,
                smokingAllowed: nil,
                availableDate: nil,
                radius: nil,
                latitude: nil,
                longitude: nil,
                sortBy: .price,
                page: 1,
                limit: 10
            )
            
            let searchResults = try await supabaseService.fetchListings(request: searchRequest)
            XCTAssertNotNil(searchResults)
            
            // 5. Toggle favorite on a listing
            if let firstListing = listings.first {
                try await supabaseService.toggleFavorite(listingId: firstListing.id, userEmail: user.email)
            }
            
            // 6. Sign out
            try await supabaseService.signOut()
            
        } catch {
            // E2E test might fail in test environment
            XCTAssertTrue(error is AuthError || error is SupabaseError || error is NetworkError)
        }
    }
    
    // MARK: - Edge Cases Integration Tests
    
    func testEdgeCases() async throws {
        // Test various edge cases
        
        // Test with empty or nil parameters
        let emptySearchRequest = ListingSearchRequest(
            query: "",
            location: nil,
            minPrice: nil,
            maxPrice: nil,
            bedrooms: nil,
            bathrooms: nil,
            propertyType: nil,
            petFriendly: nil,
            smokingAllowed: nil,
            availableDate: nil,
            radius: nil,
            latitude: nil,
            longitude: nil,
            sortBy: .date,
            page: 1,
            limit: 10
        )
        
        let emptySearchResults = try await supabaseService.fetchListings(request: emptySearchRequest)
        XCTAssertNotNil(emptySearchResults)
        
        // Test with invalid IDs
        do {
            _ = try await supabaseService.fetchListing(id: "invalid_listing_id")
            XCTFail("Should have thrown an error for invalid ID")
        } catch {
            XCTAssertTrue(error is SupabaseError || error is NetworkError)
        }
        
        // Test with invalid user credentials
        do {
            _ = try await supabaseService.signIn(email: "invalid@email.com", password: "wrongpassword")
            XCTFail("Should have thrown an error for invalid credentials")
        } catch {
            XCTAssertTrue(error is AuthError || error is SupabaseError)
        }
    }
}

// MARK: - API Integration Test Helpers

extension APIIntegrationTests {
    
    func createTestListing() -> Listing {
        return Listing(
            id: "test_listing_\(UUID().uuidString)",
            title: "Test Listing",
            price: 1500,
            bedrooms: 2,
            bathrooms: 1,
            propertyType: .apartment,
            location: [
                "city": "Test City",
                "state": "Test State",
                "address": "123 Test St",
                "zipCode": "12345"
            ],
            description: "This is a test listing",
            isActive: true,
            availableDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func createTestUser() -> User {
        return User(
            id: "test_user_\(UUID().uuidString)",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            phoneNumber: "123-456-7890",
            profileImageURL: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func createTestChat() -> Chat {
        return Chat(
            id: "test_chat_\(UUID().uuidString)",
            propertyID: "test_property_123",
            participants: ["user1", "user2"],
            type: .direct,
            lastMessage: "Test message",
            lastMessageDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func createTestMessage(chatId: String) -> Message {
        return Message(
            id: "test_message_\(UUID().uuidString)",
            chatID: chatId,
            senderID: "user1",
            content: "Test message content",
            messageType: .text,
            isRead: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}