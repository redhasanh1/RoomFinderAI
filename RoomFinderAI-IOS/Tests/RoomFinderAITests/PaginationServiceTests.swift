import XCTest
import Combine
@testable import RoomFinderAI

// MARK: - Mock Data Source
class MockPaginatedDataSource: PaginatedDataSource {
    typealias Item = MockItem
    
    struct MockItem: Codable, Identifiable {
        let id: String
        let name: String
        let value: Int
    }
    
    var items: [MockItem] = []
    var pageSize: Int = 10
    var shouldFail: Bool = false
    var delay: TimeInterval = 0
    
    init(totalItems: Int = 50, pageSize: Int = 10) {
        self.pageSize = pageSize
        self.items = Array(0..<totalItems).map { index in
            MockItem(id: "\(index)", name: "Item \(index)", value: index)
        }
    }
    
    func fetchPage(request: PaginationRequest) async throws -> PaginationResponse<MockItem> {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldFail {
            throw NetworkError.timeoutError
        }
        
        let startIndex = (request.page - 1) * request.size
        let endIndex = min(startIndex + request.size, items.count)
        
        guard startIndex < items.count else {
            return PaginationResponse(
                items: [],
                currentPage: request.page,
                totalPages: (items.count + request.size - 1) / request.size,
                totalItems: items.count,
                hasNext: false,
                hasPrevious: request.page > 1,
                pageSize: request.size
            )
        }
        
        let pageItems = Array(items[startIndex..<endIndex])
        let totalPages = (items.count + request.size - 1) / request.size
        
        return PaginationResponse(
            items: pageItems,
            currentPage: request.page,
            totalPages: totalPages,
            totalItems: items.count,
            hasNext: request.page < totalPages,
            hasPrevious: request.page > 1,
            pageSize: request.size
        )
    }
    
    func refresh() async throws -> PaginationResponse<MockItem> {
        let request = PaginationRequest(page: 1, size: pageSize)
        return try await fetchPage(request: request)
    }
}

class PaginationServiceTests: XCTestCase {
    var mockDataSource: MockPaginatedDataSource!
    var paginationManager: PaginationManager<MockPaginatedDataSource.MockItem>!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockDataSource = MockPaginatedDataSource(totalItems: 50, pageSize: 10)
        paginationManager = PaginationManager(
            dataSource: mockDataSource,
            configuration: .default,
            initialRequest: PaginationRequest(page: 1, size: 10)
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Basic Pagination Tests
    
    func testLoadInitialPage() async {
        // Given
        let expectation = XCTestExpectation(description: "Initial page loaded")
        
        paginationManager.$items
            .dropFirst()
            .sink { items in
                if !items.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await paginationManager.loadInitialPage()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertEqual(paginationManager.items.count, 10)
        XCTAssertEqual(paginationManager.currentPage, 1)
        XCTAssertEqual(paginationManager.totalPages, 5)
        XCTAssertEqual(paginationManager.totalItems, 50)
        XCTAssertTrue(paginationManager.hasNext)
        XCTAssertFalse(paginationManager.hasPrevious)
        XCTAssertEqual(paginationManager.state, .idle)
    }
    
    func testLoadNextPage() async {
        // Given
        await paginationManager.loadInitialPage()
        
        // Wait for initial load
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let expectation = XCTestExpectation(description: "Next page loaded")
        
        paginationManager.$items
            .dropFirst()
            .sink { items in
                if items.count == 20 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await paginationManager.loadNextPage()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertEqual(paginationManager.items.count, 20)
        XCTAssertEqual(paginationManager.currentPage, 2)
        XCTAssertTrue(paginationManager.hasNext)
        XCTAssertTrue(paginationManager.hasPrevious)
    }
    
    func testLoadPreviousPage() async {
        // Given
        await paginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await paginationManager.loadNextPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let expectation = XCTestExpectation(description: "Previous page loaded")
        
        paginationManager.$items
            .dropFirst()
            .sink { items in
                if items.count == 10 && items.first?.id == "0" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await paginationManager.loadPreviousPage()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertEqual(paginationManager.items.count, 10)
        XCTAssertEqual(paginationManager.currentPage, 1)
        XCTAssertTrue(paginationManager.hasNext)
        XCTAssertFalse(paginationManager.hasPrevious)
    }
    
    func testRefresh() async {
        // Given
        await paginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await paginationManager.loadNextPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(paginationManager.items.count, 20)
        XCTAssertEqual(paginationManager.currentPage, 2)
        
        let expectation = XCTestExpectation(description: "Refresh completed")
        
        paginationManager.$items
            .dropFirst()
            .sink { items in
                if items.count == 10 && items.first?.id == "0" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await paginationManager.refresh()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertEqual(paginationManager.items.count, 10)
        XCTAssertEqual(paginationManager.currentPage, 1)
        XCTAssertTrue(paginationManager.hasNext)
        XCTAssertFalse(paginationManager.hasPrevious)
    }
    
    // MARK: - Filter Tests
    
    func testUpdateFilters() async {
        // Given
        await paginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let expectation = XCTestExpectation(description: "Filters updated")
        
        paginationManager.$items
            .dropFirst()
            .sink { items in
                if items.first?.id == "0" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        let filters = ["minValue": 0, "maxValue": 100]
        await paginationManager.updateFilters(filters)
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertEqual(paginationManager.currentPage, 1)
        XCTAssertEqual(paginationManager.items.count, 10)
    }
    
    func testUpdateSorting() async {
        // Given
        await paginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let expectation = XCTestExpectation(description: "Sorting updated")
        
        paginationManager.$items
            .dropFirst()
            .sink { items in
                if items.first?.id == "0" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await paginationManager.updateSorting(sortBy: "name", sortOrder: .ascending)
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertEqual(paginationManager.currentPage, 1)
        XCTAssertEqual(paginationManager.items.count, 10)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async {
        // Given
        mockDataSource.shouldFail = true
        
        let expectation = XCTestExpectation(description: "Error handled")
        
        paginationManager.$state
            .sink { state in
                if case .error = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await paginationManager.loadInitialPage()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertTrue(paginationManager.items.isEmpty)
        
        if case .error(let error) = paginationManager.state {
            XCTAssertTrue(error is NetworkError)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testRecoveryFromError() async {
        // Given
        mockDataSource.shouldFail = true
        await paginationManager.loadInitialPage()
        
        // Wait for error state
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        if case .error = paginationManager.state {
            // Expected error state
        } else {
            XCTFail("Expected error state")
        }
        
        // When - Fix the error and retry
        mockDataSource.shouldFail = false
        
        let expectation = XCTestExpectation(description: "Recovery successful")
        
        paginationManager.$items
            .dropFirst()
            .sink { items in
                if !items.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await paginationManager.loadInitialPage()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertEqual(paginationManager.items.count, 10)
        XCTAssertEqual(paginationManager.state, .idle)
    }
    
    // MARK: - State Management Tests
    
    func testLoadingStates() async {
        // Given
        mockDataSource.delay = 0.2 // 200ms delay
        
        let expectation = XCTestExpectation(description: "Loading states observed")
        expectation.expectedFulfillmentCount = 2
        
        var observedStates: [PaginationState] = []
        
        paginationManager.$state
            .sink { state in
                observedStates.append(state)
                if observedStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await paginationManager.loadInitialPage()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertTrue(observedStates.contains { state in
            if case .loading = state { return true }
            return false
        })
        
        XCTAssertTrue(observedStates.contains { state in
            if case .idle = state { return true }
            return false
        })
    }
    
    func testLoadingMoreState() async {
        // Given
        await paginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        mockDataSource.delay = 0.2 // 200ms delay
        
        let expectation = XCTestExpectation(description: "Loading more state observed")
        
        paginationManager.$state
            .sink { state in
                if case .loadingMore = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await paginationManager.loadNextPage()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testReloadingState() async {
        // Given
        await paginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        mockDataSource.delay = 0.2 // 200ms delay
        
        let expectation = XCTestExpectation(description: "Reloading state observed")
        
        paginationManager.$state
            .sink { state in
                if case .reloading = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await paginationManager.refresh()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Pagination Configuration Tests
    
    func testPaginationConfigurationDefault() {
        // Given
        let config = PaginationConfiguration.default
        
        // Then
        XCTAssertEqual(config.pageSize, 20)
        XCTAssertEqual(config.prefetchThreshold, 5)
        XCTAssertEqual(config.maxCacheSize, 100)
        XCTAssertTrue(config.enablePrefetch)
        XCTAssertTrue(config.enableVirtualScrolling)
        XCTAssertEqual(config.preloadDistance, 3)
    }
    
    func testPaginationConfigurationPerformance() {
        // Given
        let config = PaginationConfiguration.performance
        
        // Then
        XCTAssertEqual(config.pageSize, 50)
        XCTAssertEqual(config.prefetchThreshold, 10)
        XCTAssertEqual(config.maxCacheSize, 200)
        XCTAssertTrue(config.enablePrefetch)
        XCTAssertTrue(config.enableVirtualScrolling)
        XCTAssertEqual(config.preloadDistance, 5)
    }
    
    func testPaginationConfigurationMinimal() {
        // Given
        let config = PaginationConfiguration.minimal
        
        // Then
        XCTAssertEqual(config.pageSize, 10)
        XCTAssertEqual(config.prefetchThreshold, 2)
        XCTAssertEqual(config.maxCacheSize, 50)
        XCTAssertFalse(config.enablePrefetch)
        XCTAssertFalse(config.enableVirtualScrolling)
        XCTAssertEqual(config.preloadDistance, 1)
    }
    
    // MARK: - Utility Methods Tests
    
    func testItemIndex() async {
        // Given
        await paginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let firstItem = paginationManager.items.first!
        let index = paginationManager.itemIndex(for: firstItem)
        
        // Then
        XCTAssertEqual(index, 0)
    }
    
    func testShouldLoadMore() async {
        // Given
        let config = PaginationConfiguration(
            pageSize: 10,
            prefetchThreshold: 2,
            maxCacheSize: 50,
            enablePrefetch: true,
            enableVirtualScrolling: false,
            preloadDistance: 1
        )
        
        let customPaginationManager = PaginationManager(
            dataSource: mockDataSource,
            configuration: config,
            initialRequest: PaginationRequest(page: 1, size: 10)
        )
        
        await customPaginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let items = customPaginationManager.items
        let shouldLoadMore = customPaginationManager.shouldLoadMore(for: items[items.count - 2])
        
        // Then
        XCTAssertTrue(shouldLoadMore)
    }
    
    func testCanLoadMore() async {
        // Given
        await paginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let canLoadMore = paginationManager.canLoadMore()
        
        // Then
        XCTAssertTrue(canLoadMore)
    }
    
    func testReset() async {
        // Given
        await paginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await paginationManager.loadNextPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(paginationManager.items.count, 20)
        XCTAssertEqual(paginationManager.currentPage, 2)
        
        // When
        paginationManager.reset()
        
        // Then
        XCTAssertEqual(paginationManager.items.count, 0)
        XCTAssertEqual(paginationManager.currentPage, 1)
        XCTAssertEqual(paginationManager.totalPages, 1)
        XCTAssertEqual(paginationManager.totalItems, 0)
        XCTAssertFalse(paginationManager.hasNext)
        XCTAssertFalse(paginationManager.hasPrevious)
        XCTAssertEqual(paginationManager.state, .idle)
    }
    
    // MARK: - Performance Tests
    
    func testPaginationPerformance() async {
        // Given
        let largeDataSource = MockPaginatedDataSource(totalItems: 1000, pageSize: 100)
        let performancePaginationManager = PaginationManager(
            dataSource: largeDataSource,
            configuration: .performance,
            initialRequest: PaginationRequest(page: 1, size: 100)
        )
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await performancePaginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await performancePaginationManager.loadNextPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await performancePaginationManager.loadNextPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Then
        XCTAssertLessThan(duration, 2.0) // Should complete within 2 seconds
        XCTAssertEqual(performancePaginationManager.items.count, 300)
        XCTAssertEqual(performancePaginationManager.currentPage, 3)
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyDataSource() async {
        // Given
        let emptyDataSource = MockPaginatedDataSource(totalItems: 0, pageSize: 10)
        let emptyPaginationManager = PaginationManager(
            dataSource: emptyDataSource,
            configuration: .default,
            initialRequest: PaginationRequest(page: 1, size: 10)
        )
        
        // When
        await emptyPaginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(emptyPaginationManager.items.count, 0)
        XCTAssertEqual(emptyPaginationManager.currentPage, 1)
        XCTAssertEqual(emptyPaginationManager.totalItems, 0)
        XCTAssertFalse(emptyPaginationManager.hasNext)
        XCTAssertFalse(emptyPaginationManager.hasPrevious)
    }
    
    func testSinglePageDataSource() async {
        // Given
        let singlePageDataSource = MockPaginatedDataSource(totalItems: 5, pageSize: 10)
        let singlePagePaginationManager = PaginationManager(
            dataSource: singlePageDataSource,
            configuration: .default,
            initialRequest: PaginationRequest(page: 1, size: 10)
        )
        
        // When
        await singlePagePaginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(singlePagePaginationManager.items.count, 5)
        XCTAssertEqual(singlePagePaginationManager.currentPage, 1)
        XCTAssertEqual(singlePagePaginationManager.totalPages, 1)
        XCTAssertEqual(singlePagePaginationManager.totalItems, 5)
        XCTAssertFalse(singlePagePaginationManager.hasNext)
        XCTAssertFalse(singlePagePaginationManager.hasPrevious)
    }
    
    func testLoadBeyondLastPage() async {
        // Given
        let smallDataSource = MockPaginatedDataSource(totalItems: 15, pageSize: 10)
        let smallPaginationManager = PaginationManager(
            dataSource: smallDataSource,
            configuration: .default,
            initialRequest: PaginationRequest(page: 1, size: 10)
        )
        
        await smallPaginationManager.loadInitialPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await smallPaginationManager.loadNextPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(smallPaginationManager.items.count, 15)
        XCTAssertEqual(smallPaginationManager.currentPage, 2)
        XCTAssertFalse(smallPaginationManager.hasNext)
        
        // When - Try to load next page when none exists
        await smallPaginationManager.loadNextPage()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then - Should remain unchanged
        XCTAssertEqual(smallPaginationManager.items.count, 15)
        XCTAssertEqual(smallPaginationManager.currentPage, 2)
        XCTAssertFalse(smallPaginationManager.hasNext)
    }
}