import Foundation
import SwiftUI
import Combine
import Supabase

class SimpleListingsViewModel: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    
    // Debug info visible in UI
    @Published var debugInfo: String = "Starting..."
    @Published var connectionStatus: String = "Not tested"
    @Published var listingsCount: Int = 0
    @Published var lastFetchTime: String = "Never"
    @Published var rawSupabaseResponse: String = "No response yet"
    @Published var httpStatusCode: Int = 0
    @Published var responseHeaders: String = "No headers"
    
    // Filter properties
    @Published var selectedLocation = ""
    @Published var selectedPropertyType: PropertyType?
    @Published var selectedBedrooms: Int?
    @Published var selectedBathrooms: Int?
    @Published var minPrice: Double = 0
    @Published var maxPrice: Double = 5000
    @Published var petFriendly = false
    @Published var smokingAllowed = false
    @Published var sortBy: SortOption = .date
    
    // Real-time connection status
    @Published var realtimeConnectionStatus: String = "Disconnected"
    @Published var realtimeConnectionError: String?
    @Published var realtimeRetryCount: Int = 0
    @Published var isRealtimeRetrying: Bool = false
    @Published var lastUpdateTime: Date?
    @Published var realtimeEnabled = true
    
    // Featured listings - use the SAME real query as main listings
    @Published var featuredListings: [Listing] = []
    
    // Pagination
    @Published var hasNextPage = false
    private var currentOffset = 0
    private let pageSize = 20
    
    let supabaseService: RealSupabaseService
    private var favoriteListingIds: Set<String> = []
    
    // Combine subscriptions for real-time updates
    private var cancellables = Set<AnyCancellable>()
    
    init(supabaseClient: SupabaseClient) {
        self.supabaseService = RealSupabaseService(supabaseClient: supabaseClient)
        print("📱 SimpleListingsViewModel initialized with real-time support")
        setupRealtimeSubscriptions()
        loadInitialData()
    }
    
    deinit {
        // Clean up subscriptions
        supabaseService.disconnectRealtime()
        cancellables.forEach { $0.cancel() }
    }
    
    func loadInitialData() {
        Task {
            await MainActor.run {
                self.debugInfo = "🚀 Starting comprehensive debugging..."
                self.connectionStatus = "Testing..."
            }
            // Load featured listings first
            await loadFeaturedListings()
            
            // Get UI-visible debug information
            await MainActor.run {
                self.debugInfo = "🔄 Getting UI-visible debug info..."
            }
            
            let debugResult = await supabaseService.getUIVisibleDebugInfo()
            
            await MainActor.run {
                self.debugInfo = debugResult.debugInfo
                self.rawSupabaseResponse = debugResult.response
                self.httpStatusCode = debugResult.statusCode
                self.responseHeaders = debugResult.headers
                
                // Parse response to get count
                if debugResult.response.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
                    self.listingsCount = 0
                    self.connectionStatus = "✅ Connected (Empty Result)"
                } else if debugResult.response.contains("Error:") {
                    self.connectionStatus = "❌ Error"
                } else {
                    // Try to count items in response
                    if let data = debugResult.response.data(using: .utf8),
                       let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                        self.listingsCount = jsonArray.count
                        self.connectionStatus = "✅ Connected (Has Data)"
                    } else {
                        self.connectionStatus = "✅ Connected"
                    }
                }
            }
            
            // Test connection
            do {
                _ = try await supabaseService.testConnection()
                await MainActor.run {
                    self.connectionStatus = "✅ Connected"
                    self.debugInfo = "🔗 Connection verified, loading data..."
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = "❌ Failed: \(error.localizedDescription)"
                    self.debugInfo = "⚠️ Connection failed but continuing..."
                }
            }
            
            await loadListings(reset: true)
        }
    }
    
    // MARK: - Real-time Subscriptions Setup
    
    /// Set up real-time subscriptions to listen for database changes
    private func setupRealtimeSubscriptions() {
        print("📡 Setting up real-time subscriptions...")
        
        // Subscribe to connection status changes
        supabaseService.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.realtimeConnectionStatus, on: self)
            .store(in: &cancellables)
        
        // Subscribe to connection error changes
        supabaseService.$connectionError
            .receive(on: DispatchQueue.main)
            .assign(to: \.realtimeConnectionError, on: self)
            .store(in: &cancellables)
        
        // Subscribe to retry count changes
        supabaseService.$retryCount
            .receive(on: DispatchQueue.main)
            .assign(to: \.realtimeRetryCount, on: self)
            .store(in: &cancellables)
        
        // Subscribe to retry status changes
        supabaseService.$isRetrying
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRealtimeRetrying, on: self)
            .store(in: &cancellables)
        
        // Subscribe to real-time listing events
        supabaseService.realtimeEventsSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleRealtimeEvent(event)
            }
            .store(in: &cancellables)
        
        // Start real-time subscription when enabled
        if realtimeEnabled {
            enableRealtime()
        }
    }
    
    /// Enable real-time updates
    func enableRealtime() {
        print("🔄 Enabling real-time updates...")
        realtimeEnabled = true
        supabaseService.subscribeToListingsRealtime()
    }
    
    /// Disable real-time updates
    func disableRealtime() {
        print("🔴 Disabling real-time updates...")
        realtimeEnabled = false
        supabaseService.disconnectRealtime()
    }
    
    /// Manually retry real-time connection
    func retryRealtimeConnection() {
        print("🔄 Manual real-time connection retry requested")
        supabaseService.retryConnection()
    }
    
    /// Handle real-time events from the service
    private func handleRealtimeEvent(_ event: ListingRealtimeEvent) {
        print("📨 Handling real-time event...")
        lastUpdateTime = Date()
        
        switch event {
        case .insert(let newListing):
            handleNewListing(newListing)
            
        case .update(let updatedListing):
            handleUpdatedListing(updatedListing)
            
        case .delete(let listingId):
            handleDeletedListing(listingId)
        }
    }
    
    /// Handle new listing insertion
    private func handleNewListing(_ newListing: Listing) {
        print("➕ Adding new listing: \(newListing.title)")
        
        // Check if listing passes current filters
        if listingMatchesCurrentFilters(newListing) {
            // Add to beginning of list (newest first)
            if !listings.contains(where: { $0.id == newListing.id }) {
                listings.insert(newListing, at: 0)
                debugInfo = "✅ Added new listing: \(newListing.title ?? "Unknown")"
                
                // Update UI to show new listing indicator
                showRealtimeNotification("New listing: \(newListing.title ?? "Unknown")")
            }
        }
    }
    
    /// Handle listing update
    private func handleUpdatedListing(_ updatedListing: Listing) {
        print("📝 Updating listing: \(updatedListing.title)")
        
        if let index = listings.firstIndex(where: { $0.id == updatedListing.id }) {
            // Check if updated listing still matches filters
            if listingMatchesCurrentFilters(updatedListing) {
                listings[index] = updatedListing
                debugInfo = "✅ Updated listing: \(updatedListing.title ?? "Unknown")"
            } else {
                // Remove if it no longer matches filters
                listings.remove(at: index)
                debugInfo = "🔄 Removed listing (no longer matches filters): \(updatedListing.title ?? "Unknown")"
            }
        } else if listingMatchesCurrentFilters(updatedListing) {
            // Add if it now matches filters and wasn't in list before
            listings.insert(updatedListing, at: 0)
            debugInfo = "✅ Added updated listing: \(updatedListing.title ?? "Unknown")"
        }
    }
    
    /// Handle listing deletion
    private func handleDeletedListing(_ listingId: String) {
        print("🗑️ Removing listing: \(listingId)")
        
        if let index = listings.firstIndex(where: { $0.id == listingId }) {
            let deletedTitle = listings[index].title ?? "Unknown"
            listings.remove(at: index)
            debugInfo = "✅ Removed listing: \(deletedTitle)"
            
            showRealtimeNotification("Listing removed: \(deletedTitle)")
        }
    }
    
    /// Check if a listing matches current filters
    private func listingMatchesCurrentFilters(_ listing: Listing) -> Bool {
        // Search query filter
        if !searchQuery.isEmpty {
            let searchLower = searchQuery.lowercased()
            let matchesTitle = listing.title?.lowercased().contains(searchLower) ?? false
            let matchesDescription = listing.description?.lowercased().contains(searchLower) ?? false
            if !matchesTitle && !matchesDescription {
                return false
            }
        }
        
        // Location filter
        if !selectedLocation.isEmpty {
            let locationLower = selectedLocation.lowercased()
            if !(listing.city?.lowercased().contains(locationLower) ?? false) {
                return false
            }
        }
        
        // Property type filter
        if let selectedType = selectedPropertyType {
            if listing.propertyType != selectedType {
                return false
            }
        }
        
        // Bedrooms filter
        if let minBedrooms = selectedBedrooms {
            if (listing.bedrooms ?? 0) < minBedrooms {
                return false
            }
        }
        
        // Price range filter
        let listingPrice = listing.price ?? 0
        if minPrice > 0 && listingPrice < minPrice {
            return false
        }
        if maxPrice < 5000 && listingPrice > maxPrice {
            return false
        }
        
        return true
    }
    
    /// Show a temporary notification for real-time events
    private func showRealtimeNotification(_ message: String) {
        // This could trigger a toast notification or temporary banner in the UI
        print("🔔 Real-time notification: \(message)")
        
        // Update debug info with timestamp
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        debugInfo = "🔔 \(formatter.string(from: Date())): \(message)"
    }
    
    func loadListings(reset: Bool = true) {
        if reset {
            currentOffset = 0
            listings = []
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            await MainActor.run {
                self.debugInfo = "🔄 Fetching listings with filters..."
                self.lastFetchTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            }
            
            do {
                // Use the new filtered method
                let minPriceInt = minPrice > 0 ? Int(minPrice) : nil
                let maxPriceInt = maxPrice < 5000 ? Int(maxPrice) : nil
                let houseTypeString = selectedPropertyType?.displayName
                
                let fetchedListings = try await supabaseService.fetchListingsWithFilters(
                    searchQuery: searchQuery.isEmpty ? nil : searchQuery,
                    city: selectedLocation.isEmpty ? nil : selectedLocation,
                    minPrice: minPriceInt,
                    maxPrice: maxPriceInt,
                    houseType: houseTypeString,
                    bedrooms: selectedBedrooms,
                    sortBy: sortBy == .price ? "price" : (sortBy == .priceHigh ? "price" : "created_at"),
                    ascending: sortBy == .price ? true : (sortBy == .priceHigh ? false : false),
                    offset: currentOffset,
                    limit: pageSize
                )
                
                await MainActor.run {
                    if reset {
                        self.listings = fetchedListings
                    } else {
                        self.listings.append(contentsOf: fetchedListings)
                    }
                    
                    self.hasNextPage = fetchedListings.count == pageSize
                    self.currentOffset += fetchedListings.count
                    self.isLoading = false
                    
                    // Update debug info
                    self.debugInfo = "✅ Loaded \(fetchedListings.count) listings with filters"
                    self.listingsCount = fetchedListings.count
                    
                    if !fetchedListings.isEmpty {
                        self.debugInfo += "\n📍 First: \(fetchedListings[0].title ?? "Unknown") - $\(fetchedListings[0].price ?? 0)"
                    }
                    
                    // Update favorites status
                    for i in 0..<self.listings.count {
                        if self.favoriteListingIds.contains(self.listings[i].id) {
                            // This would need to be done via a computed property or separate state
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load listings: \(error.localizedDescription)"
                    self.isLoading = false
                    self.debugInfo = "❌ Fetch failed: \(error.localizedDescription)"
                    // No mock data fallback - show real error
                }
            }
        }
    }
    
    // Load featured listings using the SAME real query as main listings
    func loadFeaturedListings() async {
        do {
            let fetchedListings = try await supabaseService.fetchListingsWithPagination(
                page: 0,
                limit: 3
            )
            
            await MainActor.run {
                self.featuredListings = fetchedListings
            }
        } catch {
            print("❌ Failed to load featured listings: \(error.localizedDescription)")
        }
    }
    
    func refreshListings() {
        loadListings(reset: true)
        // Also refresh featured listings
        Task {
            await loadFeaturedListings()
        }
    }
    
    func loadNextPage() {
        guard !isLoading && hasNextPage else { return }
        loadListings(reset: false)
    }
    
    func toggleFavorite(listing: Listing) {
        // Simple local toggle for now - implement Supabase favorites later
        if favoriteListingIds.contains(listing.id) {
            favoriteListingIds.remove(listing.id)
        } else {
            favoriteListingIds.insert(listing.id)
        }
    }
    
    func clearFilters() {
        selectedLocation = ""
        selectedPropertyType = nil
        selectedBedrooms = nil
        selectedBathrooms = nil
        minPrice = 0
        maxPrice = 5000
        petFriendly = false
        smokingAllowed = false
        refreshListings()
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    var hasError: Bool {
        return errorMessage != nil
    }
    
    var hasActiveFilters: Bool {
        return !selectedLocation.isEmpty ||
               selectedPropertyType != nil ||
               selectedBedrooms != nil ||
               selectedBathrooms != nil ||
               minPrice > 0 ||
               maxPrice < 5000 ||
               petFriendly ||
               smokingAllowed
    }
    
    var filteredListingsCount: Int {
        return listings.count
    }
}

// MARK: - Search and Filter Updates

extension SimpleListingsViewModel {
    func updateSearchQuery(_ query: String) {
        searchQuery = query
        refreshListings()
    }
    
    func updateLocation(_ location: String) {
        selectedLocation = location
        refreshListings()
    }
    
    func updatePropertyType(_ type: PropertyType?) {
        selectedPropertyType = type
        refreshListings()
    }
    
    func updateBedrooms(_ bedrooms: Int?) {
        selectedBedrooms = bedrooms
        refreshListings()
    }
    
    func updatePriceRange(min: Double, max: Double) {
        minPrice = min
        maxPrice = max
        refreshListings()
    }
    
    func updateSortOption(_ option: SortOption) {
        sortBy = option
        refreshListings()
    }
    
    // Load user's favorite listings - simplified for now
    func loadFavoriteListings() {
        // Filter favorites from current listings
        self.listings = self.listings.filter { favoriteListingIds.contains($0.id) }
    }
    
    // Favorite listings based on local state
    var favoriteListings: [Listing] {
        return listings.filter { favoriteListingIds.contains($0.id) }
    }
    
    // MARK: - Database Setup Functions
    
    func enablePublicAccess() {
        Task {
            await MainActor.run {
                self.debugInfo = "🔐 Enabling public access to listings..."
                self.isLoading = true
            }
            
            do {
                try await supabaseService.enablePublicReadAccess()
                await MainActor.run {
                    self.debugInfo = "✅ Public access enabled! Refreshing listings..."
                }
                await loadListings(reset: true)
            } catch {
                await MainActor.run {
                    self.debugInfo = "❌ Failed to enable public access: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Debug Functions
    
    func createSampleData() {
        Task {
            await MainActor.run {
                self.debugInfo = "🏠 Creating sample listings..."
                self.isLoading = true
            }
            
            do {
                let createdCount = try await supabaseService.createSampleListings()
                await MainActor.run {
                    self.debugInfo = "✅ Created \(createdCount) sample listings"
                }
                
                // Refresh to show new data
                await loadListings(reset: true)
            } catch {
                await MainActor.run {
                    self.debugInfo = "❌ Failed to create samples: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}