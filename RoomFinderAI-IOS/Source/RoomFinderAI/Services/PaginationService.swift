import Foundation
import SwiftUI
import Combine

// MARK: - Pagination Request
struct PaginationRequest {
    let page: Int
    let size: Int
    let sortBy: String?
    let sortOrder: SortOrder
    let filters: [String: Any]
    
    init(page: Int, size: Int, sortBy: String? = nil, sortOrder: SortOrder = .ascending, filters: [String: Any] = [:]) {
        self.page = page
        self.size = size
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.filters = filters
    }
}

enum SortOrder: String, CaseIterable {
    case ascending = "asc"
    case descending = "desc"
}

// MARK: - Pagination Data Source Protocol
protocol PaginationDataSource {
    associatedtype Item
    func loadPage(_ request: PaginationRequest) async throws -> [Item]
}

// MARK: - Pagination Manager
@MainActor
class PaginationManager<T>: ObservableObject {
    @Published var items: [T] = []
    @Published var isLoading = false
    @Published var hasMorePages = true
    @Published var errorMessage: String?
    
    private let dataSource: any PaginationDataSource
    private let configuration: PaginationConfiguration
    private var currentPage = 0
    private var initialRequest: PaginationRequest
    
    init<DataSource: PaginationDataSource>(
        dataSource: DataSource,
        configuration: PaginationConfiguration,
        initialRequest: PaginationRequest
    ) where DataSource.Item == T {
        self.dataSource = dataSource
        self.configuration = configuration
        self.initialRequest = initialRequest
    }
    
    func loadNextPage() async {
        guard !isLoading && hasMorePages else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let request = PaginationRequest(
                page: currentPage + 1,
                size: configuration.pageSize,
                sortBy: initialRequest.sortBy,
                sortOrder: initialRequest.sortOrder,
                filters: initialRequest.filters
            )
            
            let newItems = try await dataSource.loadPage(request) as! [T]
            
            if newItems.isEmpty {
                hasMorePages = false
            } else {
                items.append(contentsOf: newItems)
                currentPage += 1
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refresh() async {
        currentPage = 0
        items.removeAll()
        hasMorePages = true
        await loadNextPage()
    }
}

// MARK: - Pagination Configuration
struct PaginationConfiguration {
    let pageSize: Int
    let prefetchThreshold: Int
    let maxCacheSize: Int
    let enablePrefetch: Bool
    let enableVirtualScrolling: Bool
    let preloadDistance: Int
    
    static let `default` = PaginationConfiguration(
        pageSize: 20,
        prefetchThreshold: 5,
        maxCacheSize: 100,
        enablePrefetch: true,
        enableVirtualScrolling: true,
        preloadDistance: 3
    )
    
    static let performance = PaginationConfiguration(
        pageSize: 50,
        prefetchThreshold: 10,
        maxCacheSize: 200,
        enablePrefetch: true,
        enableVirtualScrolling: true,
        preloadDistance: 5
    )
    
    static let minimal = PaginationConfiguration(
        pageSize: 10,
        prefetchThreshold: 2,
        maxCacheSize: 50,
        enablePrefetch: false,
        enableVirtualScrolling: false,
        preloadDistance: 1
    )
}

// MARK: - Pagination State
enum PaginationState {
    case idle
    case loading
    case loadingMore
    case error(Error)
    case reloading
    case complete
}

// MARK: - Pagination Response
struct PaginationResponse<T: Codable> {
    let items: [T]
    let currentPage: Int
    let totalPages: Int
    let totalItems: Int
    let hasNext: Bool
    let hasPrevious: Bool
    let pageSize: Int
    
    var isFirstPage: Bool { currentPage == 1 }
    var isLastPage: Bool { currentPage == totalPages }
    var isEmpty: Bool { items.isEmpty }
}

// MARK: - Pagination Request
struct PaginationRequest {
    let page: Int
    let size: Int
    let sortBy: String?
    let sortOrder: SortOrder
    let filters: [String: Any]
    
    enum SortOrder: String, CaseIterable {
        case ascending = "asc"
        case descending = "desc"
    }
    
    init(page: Int = 1, size: Int = 20, sortBy: String? = nil, sortOrder: SortOrder = .descending, filters: [String: Any] = [:]) {
        self.page = page
        self.size = size
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.filters = filters
    }
}

// MARK: - Paginated Data Source
protocol PaginatedDataSource {
    associatedtype Item: Codable & Identifiable
    
    func fetchPage(request: PaginationRequest) async throws -> PaginationResponse<Item>
    func refresh() async throws -> PaginationResponse<Item>
}

// MARK: - Pagination Manager
class PaginationManager<T: Codable & Identifiable>: ObservableObject {
    @Published var items: [T] = []
    @Published var state: PaginationState = .idle
    @Published var currentPage = 1
    @Published var totalPages = 1
    @Published var totalItems = 0
    @Published var hasNext = false
    @Published var hasPrevious = false
    @Published var isRefreshing = false
    
    private let configuration: PaginationConfiguration
    private let dataSource: any PaginatedDataSource
    private var currentRequest: PaginationRequest
    private var cancellables = Set<AnyCancellable>()
    private let logger = LoggingService.shared
    private let cache = ListingCache.shared
    private var loadingTask: Task<Void, Never>?
    
    // Prefetch management
    private var prefetchedPages: Set<Int> = []
    private var prefetchQueue = DispatchQueue(label: "com.roomfinder.pagination.prefetch", qos: .utility)
    
    init<DataSource: PaginatedDataSource>(
        dataSource: DataSource,
        configuration: PaginationConfiguration = .default,
        initialRequest: PaginationRequest = PaginationRequest()
    ) where DataSource.Item == T {
        self.dataSource = dataSource
        self.configuration = configuration
        self.currentRequest = initialRequest
        
        setupPrefetchObserver()
    }
    
    deinit {
        loadingTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func loadInitialPage() async {
        await loadPage(page: 1, isRefresh: false)
    }
    
    func loadNextPage() async {
        guard hasNext, state != .loading, state != .loadingMore else { return }
        await loadPage(page: currentPage + 1, isRefresh: false)
    }
    
    func loadPreviousPage() async {
        guard hasPrevious, state != .loading, state != .loadingMore else { return }
        await loadPage(page: currentPage - 1, isRefresh: false)
    }
    
    func refresh() async {
        await MainActor.run {
            isRefreshing = true
            state = .reloading
        }
        
        // Clear cache for fresh data
        cache.remove(key: getCacheKey(page: 1))
        
        await loadPage(page: 1, isRefresh: true)
        
        await MainActor.run {
            isRefreshing = false
        }
    }
    
    func loadPage(page: Int, isRefresh: Bool = false) async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        loadingTask = Task {
            await performLoadPage(page: page, isRefresh: isRefresh)
        }
        
        await loadingTask?.value
    }
    
    func updateFilters(_ filters: [String: Any]) async {
        currentRequest = PaginationRequest(
            page: 1,
            size: currentRequest.size,
            sortBy: currentRequest.sortBy,
            sortOrder: currentRequest.sortOrder,
            filters: filters
        )
        
        await loadInitialPage()
    }
    
    func updateSorting(sortBy: String, sortOrder: PaginationRequest.SortOrder) async {
        currentRequest = PaginationRequest(
            page: 1,
            size: currentRequest.size,
            sortBy: sortBy,
            sortOrder: sortOrder,
            filters: currentRequest.filters
        )
        
        await loadInitialPage()
    }
    
    // MARK: - Private Methods
    
    private func performLoadPage(page: Int, isRefresh: Bool) async {
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            if page == 1 || isRefresh {
                state = .loading
            } else {
                state = .loadingMore
            }
        }
        
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Try cache first (unless refreshing)
            if !isRefresh, let cachedResponse = await getCachedResponse(page: page) {
                await handleSuccessfulResponse(cachedResponse, page: page, isRefresh: isRefresh, fromCache: true)
                return
            }
            
            // Create request
            let request = PaginationRequest(
                page: page,
                size: configuration.pageSize,
                sortBy: currentRequest.sortBy,
                sortOrder: currentRequest.sortOrder,
                filters: currentRequest.filters
            )
            
            // Fetch from network
            let response = try await dataSource.fetchPage(request: request)
            
            // Cache the response
            await cacheResponse(response, page: page)
            
            await handleSuccessfulResponse(response, page: page, isRefresh: isRefresh, fromCache: false)
            
            // Log performance
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logger.logPerformance(
                operation: "pagination_load_page",
                duration: duration,
                category: .performance,
                metadata: [
                    "page": page,
                    "page_size": configuration.pageSize,
                    "from_cache": false,
                    "is_refresh": isRefresh
                ]
            )
            
            // Start prefetching if enabled
            if configuration.enablePrefetch && !isRefresh {
                prefetchNextPages(currentPage: page)
            }
            
        } catch {
            await handleError(error, page: page)
        }
    }
    
    private func handleSuccessfulResponse(_ response: PaginationResponse<T>, page: Int, isRefresh: Bool, fromCache: Bool) async {
        await MainActor.run {
            if page == 1 || isRefresh {
                // Replace all items for first page or refresh
                items = response.items
            } else {
                // Append items for subsequent pages
                items.append(contentsOf: response.items)
            }
            
            currentPage = response.currentPage
            totalPages = response.totalPages
            totalItems = response.totalItems
            hasNext = response.hasNext
            hasPrevious = response.hasPrevious
            
            if response.items.isEmpty && response.currentPage == response.totalPages {
                state = .complete
            } else {
                state = .idle
            }
        }
        
        logger.info(
            "Loaded page \(page) with \(response.items.count) items",
            category: .database,
            metadata: [
                "page": page,
                "total_items": response.totalItems,
                "from_cache": fromCache,
                "is_refresh": isRefresh
            ]
        )
    }
    
    private func handleError(_ error: Error, page: Int) async {
        await MainActor.run {
            state = .error(error)
        }
        
        logger.error(
            "Failed to load page \(page): \(error.localizedDescription)",
            category: .database,
            metadata: [
                "page": page,
                "error": error.localizedDescription
            ]
        )
        
        // Handle error through ErrorHandler
        let context = ErrorContext(
            additionalInfo: [
                "operation": "pagination_load_page",
                "page": page,
                "page_size": configuration.pageSize
            ]
        )
        ErrorHandler.shared.handle(error, context: context)
    }
    
    // MARK: - Prefetching
    
    private func setupPrefetchObserver() {
        guard configuration.enablePrefetch else { return }
        
        // Observe items array changes to trigger prefetch
        $items
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.checkPrefetchConditions()
            }
            .store(in: &cancellables)
    }
    
    private func checkPrefetchConditions() {
        guard configuration.enablePrefetch,
              hasNext,
              state == .idle else { return }
        
        // Calculate if we should prefetch based on current position
        let remainingItems = items.count - (currentPage * configuration.pageSize)
        
        if remainingItems <= configuration.prefetchThreshold {
            prefetchNextPages(currentPage: currentPage)
        }
    }
    
    private func prefetchNextPages(currentPage: Int) {
        prefetchQueue.async { [weak self] in
            guard let self = self else { return }
            
            let pagesToPrefetch = min(self.configuration.preloadDistance, self.totalPages - currentPage)
            
            for i in 1...pagesToPrefetch {
                let pageNumber = currentPage + i
                
                // Skip if already prefetched or beyond total pages
                if pageNumber > self.totalPages || self.prefetchedPages.contains(pageNumber) {
                    continue
                }
                
                self.prefetchedPages.insert(pageNumber)
                
                Task {
                    await self.prefetchPage(pageNumber)
                }
            }
        }
    }
    
    private func prefetchPage(_ page: Int) async {
        do {
            let request = PaginationRequest(
                page: page,
                size: configuration.pageSize,
                sortBy: currentRequest.sortBy,
                sortOrder: currentRequest.sortOrder,
                filters: currentRequest.filters
            )
            
            let response = try await dataSource.fetchPage(request: request)
            await cacheResponse(response, page: page)
            
            logger.debug(
                "Prefetched page \(page) with \(response.items.count) items",
                category: .performance,
                metadata: ["page": page, "prefetch": true]
            )
            
        } catch {
            logger.warning(
                "Failed to prefetch page \(page): \(error.localizedDescription)",
                category: .performance,
                metadata: ["page": page, "error": error.localizedDescription]
            )
        }
    }
    
    // MARK: - Caching
    
    private func getCacheKey(page: Int) -> String {
        let filtersString = currentRequest.filters.description
        return "pagination_\(page)_\(configuration.pageSize)_\(currentRequest.sortBy ?? "default")_\(currentRequest.sortOrder.rawValue)_\(filtersString.hashValue)"
    }
    
    private func cacheResponse(_ response: PaginationResponse<T>, page: Int) async {
        let cacheKey = getCacheKey(page: page)
        cache.set(key: cacheKey, value: response, maxAge: 300, metadata: ["page": "\(page)", "type": "pagination"])
    }
    
    private func getCachedResponse(page: Int) async -> PaginationResponse<T>? {
        let cacheKey = getCacheKey(page: page)
        return await cache.get(key: cacheKey, type: PaginationResponse<T>.self)
    }
    
    // MARK: - Utility Methods
    
    func itemIndex(for item: T) -> Int? {
        return items.firstIndex { $0.id == item.id }
    }
    
    func shouldLoadMore(for item: T) -> Bool {
        guard let index = itemIndex(for: item) else { return false }
        
        let threshold = items.count - configuration.prefetchThreshold
        return index >= threshold && hasNext && state == .idle
    }
    
    func reset() {
        items.removeAll()
        currentPage = 1
        totalPages = 1
        totalItems = 0
        hasNext = false
        hasPrevious = false
        state = .idle
        prefetchedPages.removeAll()
    }
}

// MARK: - SwiftUI Integration

struct PaginatedListView<Item: Codable & Identifiable, Content: View>: View {
    @StateObject private var paginationManager: PaginationManager<Item>
    private let content: (Item) -> Content
    private let onAppear: () -> Void
    private let onRefresh: () async -> Void
    
    init(
        paginationManager: PaginationManager<Item>,
        onAppear: @escaping () -> Void = {},
        onRefresh: @escaping () async -> Void = {},
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._paginationManager = StateObject(wrappedValue: paginationManager)
        self.content = content
        self.onAppear = onAppear
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(paginationManager.items) { item in
                    content(item)
                        .onAppear {
                            if paginationManager.shouldLoadMore(for: item) {
                                Task {
                                    await paginationManager.loadNextPage()
                                }
                            }
                        }
                }
                
                // Loading indicator
                if paginationManager.state == .loadingMore {
                    ProgressView()
                        .padding()
                }
                
                // Error view
                if case .error(let error) = paginationManager.state {
                    ErrorView(error: error) {
                        Task {
                            await paginationManager.loadNextPage()
                        }
                    }
                }
                
                // End of results indicator
                if paginationManager.state == .complete {
                    Text("No more results")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .padding()
        }
        .refreshable {
            await paginationManager.refresh()
            await onRefresh()
        }
        .onAppear {
            onAppear()
            if paginationManager.items.isEmpty {
                Task {
                    await paginationManager.loadInitialPage()
                }
            }
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let error: Error
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Listing Data Source Implementation
class ListingDataSource: PaginatedDataSource {
    typealias Item = Listing
    
    private let supabaseService = SupabaseService.shared
    private let databaseOptimization = DatabaseOptimizationService.shared
    
    func fetchPage(request: PaginationRequest) async throws -> PaginationResponse<Listing> {
        let searchRequest = ListingSearchRequest(
            query: request.filters["query"] as? String,
            location: request.filters["location"] as? String,
            minPrice: request.filters["minPrice"] as? Int,
            maxPrice: request.filters["maxPrice"] as? Int,
            bedrooms: request.filters["bedrooms"] as? Int,
            bathrooms: request.filters["bathrooms"] as? Int,
            propertyType: request.filters["propertyType"] as? PropertyType,
            petFriendly: request.filters["petFriendly"] as? Bool,
            smokingAllowed: request.filters["smokingAllowed"] as? Bool,
            availableDate: request.filters["availableDate"] as? Date,
            sortBy: SortOption(rawValue: request.sortBy ?? "date") ?? .date,
            page: request.page,
            limit: request.size,
            latitude: request.filters["latitude"] as? Double,
            longitude: request.filters["longitude"] as? Double
        )
        
        let response = try await supabaseService.fetchListings(request: searchRequest)
        
        return PaginationResponse(
            items: response.listings,
            currentPage: response.page,
            totalPages: response.totalPages,
            totalItems: response.totalCount,
            hasNext: response.hasNextPage,
            hasPrevious: response.hasPreviousPage,
            pageSize: request.size
        )
    }
    
    func refresh() async throws -> PaginationResponse<Listing> {
        let request = PaginationRequest(page: 1, size: 20)
        return try await fetchPage(request: request)
    }
}

// MARK: - Pagination Extensions

extension PaginationManager {
    func loadMore() async {
        if hasNext && state == .idle {
            await loadNextPage()
        }
    }
    
    func canLoadMore() -> Bool {
        return hasNext && state == .idle
    }
    
    func getLoadingState() -> String {
        switch state {
        case .idle:
            return "Ready"
        case .loading:
            return "Loading..."
        case .loadingMore:
            return "Loading more..."
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        case .reloading:
            return "Refreshing..."
        case .complete:
            return "Complete"
        }
    }
}

// MARK: - Virtual Scrolling Support
class VirtualScrollingManager<T: Identifiable> {
    private let itemHeight: CGFloat
    private let containerHeight: CGFloat
    private let bufferSize: Int
    
    init(itemHeight: CGFloat, containerHeight: CGFloat, bufferSize: Int = 5) {
        self.itemHeight = itemHeight
        self.containerHeight = containerHeight
        self.bufferSize = bufferSize
    }
    
    func visibleRange(for scrollOffset: CGFloat, totalItems: Int) -> Range<Int> {
        let visibleCount = Int(ceil(containerHeight / itemHeight))
        let startIndex = max(0, Int(scrollOffset / itemHeight) - bufferSize)
        let endIndex = min(totalItems, startIndex + visibleCount + (bufferSize * 2))
        
        return startIndex..<endIndex
    }
    
    func totalContentHeight(for itemCount: Int) -> CGFloat {
        return CGFloat(itemCount) * itemHeight
    }
}

// MARK: - Pagination Statistics
struct PaginationStatistics {
    let totalRequests: Int
    let cacheHits: Int
    let cacheMisses: Int
    let averageLoadTime: TimeInterval
    let prefetchedPages: Int
    let errorCount: Int
    
    var cacheHitRate: Double {
        let total = cacheHits + cacheMisses
        return total > 0 ? Double(cacheHits) / Double(total) : 0.0
    }
}

// MARK: - Pagination Metrics Collector
class PaginationMetricsCollector {
    static let shared = PaginationMetricsCollector()
    
    private var metrics: [String: PaginationStatistics] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    func recordRequest(for key: String, fromCache: Bool, loadTime: TimeInterval, success: Bool) {
        lock.lock()
        defer { lock.unlock() }
        
        let currentStats = metrics[key] ?? PaginationStatistics(
            totalRequests: 0,
            cacheHits: 0,
            cacheMisses: 0,
            averageLoadTime: 0,
            prefetchedPages: 0,
            errorCount: 0
        )
        
        let newStats = PaginationStatistics(
            totalRequests: currentStats.totalRequests + 1,
            cacheHits: currentStats.cacheHits + (fromCache ? 1 : 0),
            cacheMisses: currentStats.cacheMisses + (fromCache ? 0 : 1),
            averageLoadTime: (currentStats.averageLoadTime * Double(currentStats.totalRequests) + loadTime) / Double(currentStats.totalRequests + 1),
            prefetchedPages: currentStats.prefetchedPages,
            errorCount: currentStats.errorCount + (success ? 0 : 1)
        )
        
        metrics[key] = newStats
    }
    
    func getStatistics(for key: String) -> PaginationStatistics? {
        lock.lock()
        defer { lock.unlock() }
        return metrics[key]
    }
    
    func getAllStatistics() -> [String: PaginationStatistics] {
        lock.lock()
        defer { lock.unlock() }
        return metrics
    }
}