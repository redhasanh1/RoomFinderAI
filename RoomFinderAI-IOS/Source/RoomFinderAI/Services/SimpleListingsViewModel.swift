import Foundation
import SwiftUI

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
    
    // Pagination
    @Published var hasNextPage = false
    private var currentOffset = 0
    private let pageSize = 20
    
    private let supabaseService = RealSupabaseService()
    private let mockDataService = MockDataService.shared // Fallback for development
    private var favoriteListingIds: Set<String> = []
    
    init() {
        print("📱 SimpleListingsViewModel initialized")
        loadInitialData()
    }
    
    func loadInitialData() {
        Task {
            await MainActor.run {
                self.debugInfo = "🚀 Starting comprehensive debugging..."
                self.connectionStatus = "Testing..."
            }
            
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
                        self.debugInfo += "\n📍 First: \(fetchedListings[0].title) - $\(fetchedListings[0].price)"
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
                    
                    // Show mock data as fallback only if there's no data
                    if self.listings.isEmpty {
                        self.debugInfo += "\n🔄 Loading mock data as fallback"
                        self.listings = self.mockDataService.getSampleListings()
                        self.listingsCount = self.listings.count
                    }
                }
            }
        }
    }
    
    func refreshListings() {
        loadListings(reset: true)
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
        let allListings = mockDataService.getSampleListings()
        self.listings = allListings.filter { favoriteListingIds.contains($0.id) }
    }
    
    // Featured listings are just the first 3 listings
    var featuredListings: [Listing] {
        return Array(listings.prefix(3))
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