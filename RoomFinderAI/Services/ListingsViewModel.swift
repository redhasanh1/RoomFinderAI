import Foundation
import SwiftUI
import Combine
import CoreLocation

class ListingsViewModel: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var featuredListings: [Listing] = []
    @Published var favoriteListings: [Listing] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Search and Filter Properties
    @Published var searchQuery = ""
    @Published var selectedLocation = ""
    @Published var minPrice: Double = 0
    @Published var maxPrice: Double = 5000
    @Published var selectedBedrooms: Int?
    @Published var selectedBathrooms: Int?
    @Published var selectedPropertyType: PropertyType?
    @Published var petFriendly = false
    @Published var smokingAllowed = false
    @Published var sortBy: SortOption = .date
    
    // Pagination
    @Published var currentPage = 1
    @Published var hasNextPage = false
    @Published var hasPreviousPage = false
    @Published var totalPages = 0
    
    private let supabaseService = SupabaseService.shared
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let itemsPerPage = 20
    
    init() {
        setupBindings()
        loadInitialData()
    }
    
    private func setupBindings() {
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.searchListings()
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest4($selectedLocation, $minPrice, $maxPrice, $selectedBedrooms)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                self?.searchListings()
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest4($selectedBathrooms, $selectedPropertyType, $petFriendly, $smokingAllowed)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                self?.searchListings()
            }
            .store(in: &cancellables)
        
        $sortBy
            .sink { [weak self] _ in
                self?.searchListings()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadInitialData() {
        Task {
            // Test connection first with detailed diagnostics
            print("🚀 Starting initial data load...")
            
            do {
                let connectionSuccess = try await supabaseService.testConnection()
                print("🔗 Connection test result: \(connectionSuccess ? "SUCCESS" : "FAILED")")
            } catch {
                print("⚠️ Connection test failed: \(error.localizedDescription)")
                print("💡 Continuing with data load - may work despite connection test failure")
            }
            
            print("📊 Loading listings data...")
            await loadListings()
            await loadFeaturedListings()
            await loadFavoriteListings()
            
            print("🏁 Initial data load completed")
        }
    }
    
    func searchListings() {
        currentPage = 1
        Task {
            await loadListings()
        }
    }
    
    func loadNextPage() {
        guard hasNextPage else { return }
        
        currentPage += 1
        Task {
            await loadListings(append: true)
        }
    }
    
    func loadPreviousPage() {
        guard hasPreviousPage else { return }
        
        currentPage -= 1
        Task {
            await loadListings()
        }
    }
    
    func refreshListings() {
        currentPage = 1
        Task {
            await loadListings()
        }
    }
    
    func toggleFavorite(listing: Listing) {
        Task {
            await toggleListingFavorite(listing)
        }
    }
    
    func clearFilters() {
        searchQuery = ""
        selectedLocation = ""
        minPrice = 0
        maxPrice = 5000
        selectedBedrooms = nil
        selectedBathrooms = nil
        selectedPropertyType = nil
        petFriendly = false
        smokingAllowed = false
        sortBy = .date
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadListings(append: Bool = false) async {
        if !append {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Use the enhanced method with automatic anonymous access fallback
            let fetchedListings = try await supabaseService.fetchListingsWithAnonymousAccess(
                page: currentPage - 1, // Convert to 0-based page index like web
                limit: itemsPerPage
            )
            
            if append {
                listings.append(contentsOf: fetchedListings)
            } else {
                listings = fetchedListings
            }
            
            // Update pagination info based on returned results
            hasNextPage = fetchedListings.count == itemsPerPage // More pages available if we got a full page
            hasPreviousPage = currentPage > 1
            
            // For total pages, we'll estimate based on current results (this could be improved with a count query)
            if fetchedListings.count < itemsPerPage {
                totalPages = currentPage // This is the last page
            } else {
                totalPages = currentPage + 1 // At least one more page exists
            }
            
            isLoading = false
            print("✅ Successfully loaded \(fetchedListings.count) listings for page \(currentPage)")
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ Error loading listings: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func loadFeaturedListings() async {
        do {
            // Use the enhanced method with anonymous access for featured listings
            let featuredListings = try await supabaseService.fetchListingsWithAnonymousAccess(
                page: 0, // First page
                limit: 10 // Only get 10 featured listings
            )
            self.featuredListings = featuredListings
            print("✅ Successfully loaded \(featuredListings.count) featured listings")
        } catch {
            print("❌ Error loading featured listings: \(error)")
        }
    }
    
    @MainActor
    private func loadFavoriteListings() async {
        // Load user's favorite listings
        // This would typically fetch from the favorites table
        favoriteListings = []
    }
    
    @MainActor
    private func toggleListingFavorite(_ listing: Listing) async {
        guard let userEmail = getCurrentUserEmail() else { return }
        
        do {
            try await supabaseService.toggleFavorite(listingId: listing.id, userEmail: userEmail)
            
            // Refresh the listings to get updated favorite status
            await loadListings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func createSearchRequest() -> ListingSearchRequest {
        return ListingSearchRequest(
            query: searchQuery.isEmpty ? nil : searchQuery,
            location: selectedLocation.isEmpty ? nil : selectedLocation,
            minPrice: minPrice > 0 ? minPrice : nil,
            maxPrice: maxPrice < 5000 ? maxPrice : nil,
            bedrooms: selectedBedrooms,
            bathrooms: selectedBathrooms,
            propertyType: selectedPropertyType,
            petFriendly: petFriendly ? true : nil,
            smokingAllowed: smokingAllowed ? true : nil,
            availableDate: nil,
            radius: nil,
            latitude: nil,
            longitude: nil,
            sortBy: sortBy,
            page: currentPage,
            limit: itemsPerPage
        )
    }
    
    private func getCurrentUserId() -> String? {
        // This would typically get the current user's ID from the auth service
        return "current_user_id"
    }
    
    private func getCurrentUserEmail() -> String? {
        return "test@example.com"
    }
    
    // MARK: - Computed Properties
    
    var hasActiveFilters: Bool {
        return !searchQuery.isEmpty ||
               !selectedLocation.isEmpty ||
               minPrice > 0 ||
               maxPrice < 5000 ||
               selectedBedrooms != nil ||
               selectedBathrooms != nil ||
               selectedPropertyType != nil ||
               petFriendly ||
               smokingAllowed
    }
    
    var filteredListingsCount: Int {
        return listings.count
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    var hasError: Bool {
        return errorMessage != nil
    }
    
    // MARK: - Debugging and Diagnostics
    
    func runSupabaseDiagnostics() {
        Task {
            await supabaseService.runDiagnosticTest()
        }
    }
    
    // MARK: - Location Services
    
    func searchNearby(location: CLLocation, radius: Double = 10.0) {
        selectedLocation = ""
        
        Task {
            await searchListingsNearLocation(location: location, radius: radius)
        }
    }
    
    @MainActor
    private func searchListingsNearLocation(location: CLLocation, radius: Double) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let request = ListingSearchRequest(
                query: searchQuery.isEmpty ? nil : searchQuery,
                location: nil,
                minPrice: minPrice > 0 ? minPrice : nil,
                maxPrice: maxPrice < 5000 ? maxPrice : nil,
                bedrooms: selectedBedrooms,
                bathrooms: selectedBathrooms,
                propertyType: selectedPropertyType,
                petFriendly: petFriendly ? true : nil,
                smokingAllowed: smokingAllowed ? true : nil,
                availableDate: nil,
                radius: radius,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                sortBy: .distance,
                page: 1,
                limit: itemsPerPage
            )
            
            let response = try await supabaseService.fetchListings(request: request)
            listings = response.listings
            hasNextPage = response.hasNextPage
            hasPreviousPage = response.hasPreviousPage
            totalPages = response.totalPages
            currentPage = 1
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}