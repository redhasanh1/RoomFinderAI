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
    
    func loadInitialPage() async {
        await refresh()
    }
    
    func updateFilters(_ filters: [String: Any]) async {
        initialRequest = PaginationRequest(
            page: initialRequest.page,
            size: initialRequest.size,
            sortBy: initialRequest.sortBy,
            sortOrder: initialRequest.sortOrder,
            filters: filters
        )
        await refresh()
    }
    
    func loadPreviousPage() async {
        // Previous page functionality would need to be implemented based on your data source
        // For now, this is a no-op since most pagination goes forward only
    }
    
    var totalItems: Int {
        return items.count // Simple implementation
    }
    
    var totalPages: Int {
        let pageSize = configuration.pageSize
        return max(1, (totalItems + pageSize - 1) / pageSize)
    }
    
    var hasNext: Bool {
        return hasMorePages
    }
    
    var hasPrevious: Bool {
        return currentPage > 1
    }
    
    func canLoadMore() -> Bool {
        return hasMorePages && !isLoading
    }
    
    func getLoadingState() -> PaginationState {
        if isLoading {
            return currentPage == 0 ? .loading : .loadingMore
        } else if let error = errorMessage {
            return .error(NSError(domain: "PaginationError", code: 0, userInfo: [NSLocalizedDescriptionKey: error]))
        } else if !hasMorePages {
            return .complete
        } else {
            return .idle
        }
    }
    
    @Published var state: PaginationState = .idle
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
