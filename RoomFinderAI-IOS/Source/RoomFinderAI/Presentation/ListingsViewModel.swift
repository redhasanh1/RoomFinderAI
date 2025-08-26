import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class ListingsViewModel: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var filters = ListingsFilter()
    @Published var hasMorePages = true
    
    // Real-time connection status
    @Published var realtimeStatus: RealtimeConnectionStatus = .disconnected
    @Published var lastRealtimeUpdate: Date?
    @Published var realtimeUpdateCount: Int = 0
    
    private let listingsService: ListingsService
    private let realtimeService: ListingsRealtime
    private var currentPage = 0
    private let pageSize = 20
    
    private var debounceTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(supabaseClient: SupabaseClient) {
        self.listingsService = ListingsService(supabaseClient: supabaseClient)
        self.realtimeService = ListingsRealtime(supabaseClient: supabaseClient)
        startRealtime()
        setupRealtimeStatusBinding()
    }
    
    deinit {
        Task { @MainActor in
            stopRealtime()
        }
        cancellables.removeAll()
    }
    
    private func setupRealtimeStatusBinding() {
        // Bind real-time service status to our published properties
        realtimeService.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.realtimeStatus, on: self)
            .store(in: &cancellables)
        
        realtimeService.$lastUpdateTime
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastRealtimeUpdate, on: self)
            .store(in: &cancellables)
    }
    
    func loadInitial() async {
        currentPage = 0
        hasMorePages = true
        await loadListings(resetList: true)
    }
    
    func loadMore() async {
        guard !isLoadingMore && hasMorePages else { return }
        currentPage += 1
        await loadListings(resetList: false)
    }
    
    func apply(filters: ListingsFilter) async {
        self.filters = filters
        await loadInitial()
    }
    
    func refresh() async {
        await loadInitial()
    }
    
    private func loadListings(resetList: Bool) async {
        if resetList {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        
        error = nil
        
        do {
            let fetchedListings = try await listingsService.fetchListings(
                page: currentPage,
                pageSize: pageSize,
                filters: filters
            )
            
            if resetList {
                listings = fetchedListings
            } else {
                listings.append(contentsOf: fetchedListings)
            }
            
            hasMorePages = fetchedListings.count == pageSize
            
        } catch {
            self.error = error.localizedDescription
            print("Error loading listings: \(error)")
            
            await retryAfterDelay()
        }
        
        isLoading = false
        isLoadingMore = false
    }
    
    private func retryAfterDelay() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        do {
            let retryListings = try await listingsService.fetchListings(
                page: currentPage,
                pageSize: pageSize,
                filters: filters
            )
            
            if currentPage == 0 {
                listings = retryListings
            } else {
                listings.append(contentsOf: retryListings)
            }
            
            error = nil
        } catch {
            print("Retry failed: \(error)")
        }
    }
    
    private func startRealtime() {
        realtimeService.start { [weak self] change in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.debounceTimer?.invalidate()
                self.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                    Task { @MainActor in
                        self.handleRealtimeChange(change)
                    }
                }
            }
        }
    }
    
    private func stopRealtime() {
        realtimeService.stop()
        debounceTimer?.invalidate()
    }
    
    private func handleRealtimeChange(_ change: RealtimeChange<Listing>) {
        print("🔄 Processing real-time change: \(change)")
        
        // Update counter for UI feedback
        realtimeUpdateCount += 1
        
        switch change {
        case .insert(let listing):
            print("📥 Processing INSERT for listing: \(listing.title ?? "Untitled")")
            
            // Check if already exists to avoid duplicates
            if !listings.contains(where: { $0.id == listing.id }) {
                if matchesCurrentFilters(listing) {
                    print("✅ INSERT matches filters, adding to top of list")
                    listings.insert(listing, at: 0)
                    
                    // Show user feedback for new listings - UI updates automatically due to @Published
                } else {
                    print("⚠️ INSERT doesn't match current filters, skipping")
                }
            } else {
                print("⚠️ INSERT: Listing already exists, skipping duplicate")
            }
            
        case .update(let listing):
            print("📝 Processing UPDATE for listing: \(listing.title ?? "Untitled")")
            
            if let index = listings.firstIndex(where: { $0.id == listing.id }) {
                if matchesCurrentFilters(listing) {
                    print("✅ UPDATE matches filters, updating existing listing")
                    listings[index] = listing
                } else {
                    print("⚠️ UPDATE no longer matches filters, removing from list")
                    listings.remove(at: index)
                }
            } else if matchesCurrentFilters(listing) {
                print("✅ UPDATE for new listing that matches filters, adding to top")
                listings.insert(listing, at: 0)
            } else {
                print("⚠️ UPDATE for listing not in current view and doesn't match filters")
            }
            
        case .delete(let listing):
            print("🗑️ Processing DELETE for listing: \(listing.title ?? "Untitled")")
            let initialCount = listings.count
            listings.removeAll { $0.id == listing.id }
            let removedCount = initialCount - listings.count
            print("✅ DELETE removed \(removedCount) listing(s)")
        }
        
        // Update last update time
        lastRealtimeUpdate = Date()
        
        print("📊 Current listings count: \(listings.count)")
    }
    
    private func matchesCurrentFilters(_ listing: Listing) -> Bool {
        if let city = filters.city, !city.isEmpty {
            if !(listing.city?.localizedCaseInsensitiveContains(city) ?? false) {
                return false
            }
        }
        
        if let minPrice = filters.minPrice {
            if Int(listing.price ?? 0) < minPrice {
                return false
            }
        }
        
        if let maxPrice = filters.maxPrice {
            if Int(listing.price ?? 0) > maxPrice {
                return false
            }
        }
        
        if let houseType = filters.houseType, !houseType.isEmpty {
            if listing.houseType != houseType {
                return false
            }
        }
        
        if let bedrooms = filters.bedrooms {
            if listing.bedrooms != bedrooms {
                return false
            }
        }
        
        if let search = filters.search, !search.isEmpty {
            if !(listing.title?.localizedCaseInsensitiveContains(search) ?? false) {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Real-time Management
    
    /// Force reconnect the real-time subscription
    func reconnectRealtime() {
        print("🔄 Manual real-time reconnection requested")
        realtimeService.forceReconnect()
    }
    
    /// Get real-time connection status for UI display
    func getConnectionStatusText() -> String {
        switch realtimeStatus {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Live Updates Active"
        case .reconnecting:
            return "Reconnecting..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    /// Get connection status color for UI
    func getConnectionStatusColor() -> Color {
        switch realtimeStatus {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected, .error:
            return .red
        }
    }
    
    /// Check if real-time is working properly
    var isRealtimeHealthy: Bool {
        switch realtimeStatus {
        case .connected:
            return true
        default:
            return false
        }
    }
    
    /// Get formatted last update time
    func getLastUpdateText() -> String {
        guard let lastUpdate = lastRealtimeUpdate else {
            return "No updates yet"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastUpdate, relativeTo: Date()))"
    }
}