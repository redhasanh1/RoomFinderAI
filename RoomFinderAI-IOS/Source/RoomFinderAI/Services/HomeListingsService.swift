import Foundation
import Supabase
import SwiftUI

@MainActor
class HomeListingsService: ObservableObject {
    @Published var listings: [HomePageListing] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMorePages = true
    @Published var error: String?
    
    private let supabaseClient: SupabaseClient
    private let pageSize = 20
    private var currentOffset = 0
    private var isInitialLoad = true
    
    // Caching mechanism
    private var cachedListings: [HomePageListing] = []
    private var lastRefreshTime: Date?
    private let cacheExpirationMinutes: Double = 5 // Cache expires after 5 minutes
    
    init(client: SupabaseClient) {
        self.supabaseClient = client
    }
    
    // MARK: - Public Methods
    
    func loadFirstPage() async {
        // Check cache first for initial load
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < cacheExpirationMinutes * 60,
           !cachedListings.isEmpty {
            self.listings = Array(cachedListings.prefix(pageSize))
            self.isLoading = false
            return
        }
        
        isLoading = true
        error = nil
        currentOffset = 0
        hasMorePages = true
        isInitialLoad = true
        
        await loadListings()
    }
    
    func loadNextPage() async {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        isInitialLoad = false
        await loadListings()
    }
    
    func refreshListings() async {
        // Clear cache and reload
        cachedListings.removeAll()
        lastRefreshTime = nil
        currentOffset = 0
        hasMorePages = true
        
        isLoading = true
        error = nil
        
        await loadListings()
    }
    
    // MARK: - Private Methods
    
    private func loadListings() async {
        do {
            // Optimized query - only essential fields, ordered by newest first
            let response: [HomePageListing] = try await supabaseClient
                .from("listings")
                .select("id, title, price, city, house_type, bedrooms, description, created_at, media")
                .order("created_at", ascending: false)
                .range(from: currentOffset, to: currentOffset + pageSize - 1)
                .execute()
                .value
            
            // Process response
            if isInitialLoad {
                // First page - replace all listings
                listings = response
                cachedListings = response
                lastRefreshTime = Date()
            } else {
                // Additional pages - append to existing
                listings.append(contentsOf: response)
                cachedListings.append(contentsOf: response)
            }
            
            // Update pagination state
            hasMorePages = response.count == pageSize
            currentOffset += response.count
            
            // Update loading states
            isLoading = false
            isLoadingMore = false
            error = nil
            
        } catch {
            // Handle errors
            self.error = error.localizedDescription
            isLoading = false
            isLoadingMore = false
            
            print("HomeListingsService Error: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    func shouldLoadMore(for item: HomePageListing) -> Bool {
        // Trigger loading when user is 5 items from the end
        guard let index = listings.firstIndex(where: { $0.id == item.id }) else { return false }
        return index >= listings.count - 5 && hasMorePages && !isLoadingMore
    }
    
    func getTotalCount() -> Int {
        return listings.count
    }
    
    func clearCache() {
        cachedListings.removeAll()
        lastRefreshTime = nil
    }
}

// MARK: - HomePageListing Extensions for Performance
extension HomePageListing {
    var displayPrice: String {
        guard let price = price else { return "Contact for Price" }
        return "$\(price)/mo"
    }
    
    var displayLocation: String {
        return city ?? "Unknown Location"
    }
    
    var displayTitle: String {
        return title ?? "Property Available"
    }
    
    var displayBedrooms: String {
        guard let bedrooms = bedrooms else { return "Studio" }
        if bedrooms == 0 { return "Studio" }
        return "\(bedrooms) Bed"
    }
}