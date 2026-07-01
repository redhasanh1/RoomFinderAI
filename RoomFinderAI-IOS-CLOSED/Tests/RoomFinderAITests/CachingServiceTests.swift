import XCTest
@testable import RoomFinderAI

class CachingServiceTests: XCTestCase {
    var multiLevelCache: MultiLevelCache!
    var testCacheDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create test cache directory
        let tempDir = FileManager.default.temporaryDirectory
        testCacheDirectory = tempDir.appendingPathComponent("test_cache_\(UUID().uuidString)")
        
        let testConfig = CacheConfiguration(
            memoryCapacity: 1024 * 1024, // 1MB
            diskCapacity: 5 * 1024 * 1024, // 5MB
            maxAge: 300, // 5 minutes
            cleanupInterval: 60,
            compressionEnabled: false, // Disable for testing
            encryptionEnabled: false // Disable for testing
        )
        
        multiLevelCache = MultiLevelCache(configuration: testConfig, strategy: .lru)
    }
    
    override func tearDown() {
        multiLevelCache.clear()
        
        // Clean up test directory
        if FileManager.default.fileExists(atPath: testCacheDirectory.path) {
            try? FileManager.default.removeItem(at: testCacheDirectory)
        }
        
        super.tearDown()
    }
    
    // MARK: - Basic Cache Operations
    
    func testSetAndGetFromCache() async {
        // Given
        let key = "test_key"
        let value = "test_value"
        
        // When
        multiLevelCache.set(key: key, value: value)
        
        // Give it a moment to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let retrievedValue = await multiLevelCache.get(key: key, type: String.self)
        
        // Then
        XCTAssertEqual(retrievedValue, value)
    }
    
    func testGetFromCacheNonExistentKey() async {
        // Given
        let key = "non_existent_key"
        
        // When
        let retrievedValue = await multiLevelCache.get(key: key, type: String.self)
        
        // Then
        XCTAssertNil(retrievedValue)
    }
    
    func testCacheWithCustomMaxAge() async {
        // Given
        let key = "test_key"
        let value = "test_value"
        let maxAge: TimeInterval = 0.1 // 100ms
        
        // When
        multiLevelCache.set(key: key, value: value, maxAge: maxAge)
        
        // Retrieve immediately
        let immediateValue = await multiLevelCache.get(key: key, type: String.self)
        XCTAssertEqual(immediateValue, value)
        
        // Wait for expiration
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        let expiredValue = await multiLevelCache.get(key: key, type: String.self)
        
        // Then
        XCTAssertNil(expiredValue)
    }
    
    func testCacheWithMetadata() async {
        // Given
        let key = "test_key"
        let value = "test_value"
        let metadata = ["type": "test", "priority": "high"]
        
        // When
        multiLevelCache.set(key: key, value: value, metadata: metadata)
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let retrievedValue = await multiLevelCache.get(key: key, type: String.self)
        
        // Then
        XCTAssertEqual(retrievedValue, value)
    }
    
    // MARK: - Cache Removal Tests
    
    func testRemoveFromCache() async {
        // Given
        let key = "test_key"
        let value = "test_value"
        
        multiLevelCache.set(key: key, value: value)
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Verify item is cached
        let cachedValue = await multiLevelCache.get(key: key, type: String.self)
        XCTAssertEqual(cachedValue, value)
        
        // When
        multiLevelCache.remove(key: key)
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let removedValue = await multiLevelCache.get(key: key, type: String.self)
        
        // Then
        XCTAssertNil(removedValue)
    }
    
    func testClearAllCache() async {
        // Given
        let keys = ["key1", "key2", "key3"]
        let values = ["value1", "value2", "value3"]
        
        for (key, value) in zip(keys, values) {
            multiLevelCache.set(key: key, value: value)
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Verify items are cached
        for (key, value) in zip(keys, values) {
            let cachedValue = await multiLevelCache.get(key: key, type: String.self)
            XCTAssertEqual(cachedValue, value)
        }
        
        // When
        multiLevelCache.clear()
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then
        for key in keys {
            let clearedValue = await multiLevelCache.get(key: key, type: String.self)
            XCTAssertNil(clearedValue)
        }
    }
    
    // MARK: - Complex Data Types Tests
    
    func testCacheComplexDataTypes() async {
        // Given
        struct TestStruct: Codable, Equatable {
            let id: String
            let name: String
            let count: Int
        }
        
        let key = "complex_key"
        let value = TestStruct(id: "123", name: "test", count: 42)
        
        // When
        multiLevelCache.set(key: key, value: value)
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let retrievedValue = await multiLevelCache.get(key: key, type: TestStruct.self)
        
        // Then
        XCTAssertEqual(retrievedValue, value)
    }
    
    func testCacheArrayOfObjects() async {
        // Given
        struct Item: Codable, Equatable {
            let id: String
            let value: String
        }
        
        let key = "array_key"
        let value = [
            Item(id: "1", value: "first"),
            Item(id: "2", value: "second"),
            Item(id: "3", value: "third")
        ]
        
        // When
        multiLevelCache.set(key: key, value: value)
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let retrievedValue = await multiLevelCache.get(key: key, type: [Item].self)
        
        // Then
        XCTAssertEqual(retrievedValue, value)
    }
    
    // MARK: - Cache Statistics Tests
    
    func testCacheStatistics() async {
        // Given
        let key1 = "key1"
        let key2 = "key2"
        let nonExistentKey = "nonexistent"
        
        // When
        multiLevelCache.set(key: key1, value: "value1")
        multiLevelCache.set(key: key2, value: "value2")
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Generate hits and misses
        _ = await multiLevelCache.get(key: key1, type: String.self) // Hit
        _ = await multiLevelCache.get(key: key2, type: String.self) // Hit
        _ = await multiLevelCache.get(key: nonExistentKey, type: String.self) // Miss
        
        let stats = multiLevelCache.getStatistics()
        
        // Then
        XCTAssertEqual(stats.hits, 2)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.hitRate, 2.0/3.0, accuracy: 0.01)
    }
    
    // MARK: - Cache Size Tests
    
    func testCacheSize() {
        // Given
        let keys = Array(0..<10).map { "key_\($0)" }
        let values = Array(0..<10).map { "value_\($0)" }
        
        // When
        for (key, value) in zip(keys, values) {
            multiLevelCache.set(key: key, value: value)
        }
        
        let cacheSize = multiLevelCache.getCacheSize()
        
        // Then
        XCTAssertGreaterThan(cacheSize.memorySize, 0)
        XCTAssertGreaterThan(cacheSize.diskSize, 0)
    }
    
    // MARK: - Specialized Cache Tests
    
    func testListingCache() async {
        // Given
        let listingCache = ListingCache.shared
        let key = "test_listings"
        let mockListings = [
            createMockListing(id: "1", title: "Test Listing 1"),
            createMockListing(id: "2", title: "Test Listing 2")
        ]
        
        // When
        listingCache.cacheListings(mockListings, key: key)
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let cachedListings = await listingCache.getCachedListings(key: key)
        
        // Then
        XCTAssertNotNil(cachedListings)
        XCTAssertEqual(cachedListings?.count, 2)
        XCTAssertEqual(cachedListings?.first?.id, "1")
        XCTAssertEqual(cachedListings?.first?.title, "Test Listing 1")
    }
    
    func testUserCache() async {
        // Given
        let userCache = UserCache.shared
        let key = "test_user"
        let mockUser = createMockUser(id: "123", email: "test@example.com")
        
        // When
        userCache.cacheUser(mockUser, key: key)
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let cachedUser = await userCache.getCachedUser(key: key)
        
        // Then
        XCTAssertNotNil(cachedUser)
        XCTAssertEqual(cachedUser?.id, "123")
        XCTAssertEqual(cachedUser?.email, "test@example.com")
    }
    
    // MARK: - Cache Manager Tests
    
    func testCacheManagerStatistics() {
        // Given
        let cacheManager = CacheManager.shared
        
        // When
        let stats = cacheManager.getCacheStatistics()
        
        // Then
        XCTAssertTrue(stats.keys.contains("listings"))
        XCTAssertTrue(stats.keys.contains("images"))
        XCTAssertTrue(stats.keys.contains("users"))
        
        if let listingStats = stats["listings"] as? [String: Any] {
            XCTAssertNotNil(listingStats["hitRate"])
            XCTAssertNotNil(listingStats["hits"])
            XCTAssertNotNil(listingStats["misses"])
        }
    }
    
    func testCacheManagerSizes() {
        // Given
        let cacheManager = CacheManager.shared
        
        // When
        let sizes = cacheManager.getCacheSizes()
        
        // Then
        XCTAssertTrue(sizes.keys.contains("listings_memory"))
        XCTAssertTrue(sizes.keys.contains("listings_disk"))
        XCTAssertTrue(sizes.keys.contains("images_memory"))
        XCTAssertTrue(sizes.keys.contains("images_disk"))
        XCTAssertTrue(sizes.keys.contains("users_memory"))
        XCTAssertTrue(sizes.keys.contains("users_disk"))
    }
    
    func testCacheManagerClearAll() async {
        // Given
        let cacheManager = CacheManager.shared
        let listingCache = ListingCache.shared
        let userCache = UserCache.shared
        
        // Set some data
        let mockListings = [createMockListing(id: "1", title: "Test")]
        let mockUser = createMockUser(id: "123", email: "test@example.com")
        
        listingCache.cacheListings(mockListings, key: "test_listings")
        userCache.cacheUser(mockUser, key: "test_user")
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Verify data is cached
        let cachedListings = await listingCache.getCachedListings(key: "test_listings")
        let cachedUser = await userCache.getCachedUser(key: "test_user")
        XCTAssertNotNil(cachedListings)
        XCTAssertNotNil(cachedUser)
        
        // When
        cacheManager.clearAllCaches()
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then
        let clearedListings = await listingCache.getCachedListings(key: "test_listings")
        let clearedUser = await userCache.getCachedUser(key: "test_user")
        XCTAssertNil(clearedListings)
        XCTAssertNil(clearedUser)
    }
    
    // MARK: - Performance Tests
    
    func testCachePerformance() async {
        // Given
        let iterations = 1000
        let keys = Array(0..<iterations).map { "key_\($0)" }
        let values = Array(0..<iterations).map { "value_\($0)" }
        
        // When - Measure write performance
        let writeStartTime = CFAbsoluteTimeGetCurrent()
        
        for (key, value) in zip(keys, values) {
            multiLevelCache.set(key: key, value: value)
        }
        
        let writeEndTime = CFAbsoluteTimeGetCurrent()
        let writeDuration = writeEndTime - writeStartTime
        
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms for processing
        
        // Measure read performance
        let readStartTime = CFAbsoluteTimeGetCurrent()
        
        var retrievedCount = 0
        for key in keys {
            let value = await multiLevelCache.get(key: key, type: String.self)
            if value != nil {
                retrievedCount += 1
            }
        }
        
        let readEndTime = CFAbsoluteTimeGetCurrent()
        let readDuration = readEndTime - readStartTime
        
        // Then
        XCTAssertLessThan(writeDuration, 5.0) // Write should complete within 5 seconds
        XCTAssertLessThan(readDuration, 5.0) // Read should complete within 5 seconds
        XCTAssertGreaterThan(retrievedCount, iterations * 0.8) // At least 80% should be retrieved
    }
    
    // MARK: - Helper Methods
    
    private func createMockListing(id: String, title: String) -> Listing {
        return Listing(
            id: id,
            title: title,
            price: 1000,
            bedrooms: 2,
            bathrooms: 1,
            propertyType: .apartment,
            location: ["city": "Test City", "state": "Test State"],
            description: "Test description",
            isActive: true,
            availableDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func createMockUser(id: String, email: String) -> User {
        return User(
            id: id,
            email: email,
            firstName: "Test",
            lastName: "User",
            phoneNumber: "123-456-7890",
            profileImageURL: nil,
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}