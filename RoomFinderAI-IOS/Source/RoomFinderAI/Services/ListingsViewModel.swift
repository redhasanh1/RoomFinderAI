import Foundation
import SwiftUI
import Combine
import CoreLocation

// MARK: - Listing Data Source
class ListingDataSource: PaginationDataSource {
    typealias Item = Listing
    
    private let supabaseService = SupabaseService.shared
    
    func loadPage(_ request: PaginationRequest) async throws -> [Listing] {
        // Mock implementation - replace with actual Supabase query
        let mockListings = [
            Listing(
                id: UUID().uuidString,
                title: "Modern Apartment",
                description: "Beautiful modern apartment in the city center",
                price: 1500,
                city: "San Francisco",
                street: "123 Main St",
                postalCode: "94101",
                houseType: "apartment",
                bedrooms: 2,
                utilities: "included",
                media: [],
                userEmail: "test@example.com",
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return mockListings
    }
}

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
    
    // Pagination Manager
    @Published var paginationManager: PaginationManager<Listing>
    
    private let supabaseService = SupabaseService.shared
    private let networkManager = NetworkManager.shared
    private let offlineDataService = OfflineDataService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let itemsPerPage = 20
    private let listingDataSource = ListingDataSource()
    
    init() {
        // Initialize pagination manager
        self.paginationManager = PaginationManager(
            dataSource: listingDataSource,
            configuration: .default,
            initialRequest: PaginationRequest(page: 1, size: itemsPerPage)
        )
        
        setupBindings()
        loadInitialData()
    }
    
    private func setupBindings() {
        // Sync pagination manager items with listings
        paginationManager.$items
            .assign(to: \.listings, on: self)
            .store(in: &cancellables)
        
        // Sync pagination manager state with loading state
        paginationManager.$state
            .map { state in
                switch state {
                case .loading, .loadingMore, .reloading:
                    return true
                default:
                    return false
                }
            }
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        // Handle pagination errors
        paginationManager.$state
            .compactMap { state in
                if case .error(let error) = state {
                    return error.localizedDescription
                }
                return nil
            }
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        // Search query changes
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.searchListings()
            }
            .store(in: &cancellables)
        
        // Filter changes
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
        
        // Sort changes
        $sortBy
            .sink { [weak self] _ in
                self?.searchListings()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadInitialData() {
        Task {
            await paginationManager.loadInitialPage()
            await loadFeaturedListings()
            await loadFavoriteListings()
        }
    }
    
    func searchListings() {
        let filters = createFilters()
        
        Task {
            await paginationManager.updateFilters(filters)
        }
    }
    
    func loadNextPage() {
        Task {
            await paginationManager.loadNextPage()
        }
    }
    
    func loadPreviousPage() {
        Task {
            await paginationManager.loadPreviousPage()
        }
    }
    
    func refreshListings() {
        Task {
            await paginationManager.refresh()
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
            var fetchedListings: [Listing] = []
            
            if offlineDataService.isOnline {
                // Try to fetch from remote first
                fetchedListings = try await supabaseService.fetchAllListings()
                
                // Save to offline storage
                offlineDataService.saveListings(fetchedListings, isInitialLoad: true)
            } else {
                // Load from offline storage
                fetchedListings = offlineDataService.getOfflineListings(limit: itemsPerPage)
            }
            
            if append {
                listings.append(contentsOf: fetchedListings)
            } else {
                listings = fetchedListings
            }
            
            isLoading = false
            print("✅ Successfully loaded \(fetchedListings.count) listings \(offlineDataService.isOnline ? "from server" : "from offline storage")")
        } catch {
            // Fall back to offline data if online request fails
            let offlineListings = offlineDataService.getOfflineListings(limit: itemsPerPage)
            if !offlineListings.isEmpty {
                if append {
                    listings.append(contentsOf: offlineListings)
                } else {
                    listings = offlineListings
                }
                print("✅ Loaded \(offlineListings.count) listings from offline storage as fallback")
            } else {
                errorMessage = error.localizedDescription
                print("❌ Error loading listings: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
    
    @MainActor
    private func loadFeaturedListings() async {
        do {
            // For now, just use the first 10 listings as featured
            let allListings = try await supabaseService.fetchAllListings()
            featuredListings = Array(allListings.prefix(10))
            print("✅ Successfully loaded \(featuredListings.count) featured listings")
        } catch {
            print("❌ Error loading featured listings: \(error)")
        }
    }
    
    @MainActor
    private func loadFavoriteListings() async {
        // Load user's favorite listings from offline storage
        favoriteListings = offlineDataService.getFavoriteListings()
    }
    
    @MainActor
    private func toggleListingFavorite(_ listing: Listing) async {
        // Toggle favorite in offline storage immediately
        offlineDataService.toggleFavorite(listingId: listing.id)
        
        // Refresh favorite listings
        await loadFavoriteListings()
        
        // If online, try to sync with server
        if offlineDataService.isOnline {
            guard let userEmail = getCurrentUserEmail() else { return }
            
            do {
                try await supabaseService.toggleFavorite(listingId: listing.id, userEmail: userEmail)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func createFilters() -> [String: Any] {
        var filters: [String: Any] = [:]
        
        if !searchQuery.isEmpty {
            filters["query"] = searchQuery
        }
        
        if !selectedLocation.isEmpty {
            filters["location"] = selectedLocation
        }
        
        if minPrice > 0 {
            filters["minPrice"] = Int(minPrice)
        }
        
        if maxPrice < 5000 {
            filters["maxPrice"] = Int(maxPrice)
        }
        
        if let bedrooms = selectedBedrooms {
            filters["bedrooms"] = bedrooms
        }
        
        if let bathrooms = selectedBathrooms {
            filters["bathrooms"] = bathrooms
        }
        
        if let propertyType = selectedPropertyType {
            filters["propertyType"] = propertyType
        }
        
        if petFriendly {
            filters["petFriendly"] = true
        }
        
        if smokingAllowed {
            filters["smokingAllowed"] = true
        }
        
        return filters
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
            page: 1,
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
        return paginationManager.totalItems
    }
    
    var currentPage: Int {
        return paginationManager.currentPage
    }
    
    var totalPages: Int {
        return paginationManager.totalPages
    }
    
    var hasNextPage: Bool {
        return paginationManager.hasNext
    }
    
    var hasPreviousPage: Bool {
        return paginationManager.hasPrevious
    }
    
    var canLoadMore: Bool {
        return paginationManager.canLoadMore()
    }
    
    var paginationState: String {
        return paginationManager.getLoadingState()
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    var hasError: Bool {
        return errorMessage != nil
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
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}