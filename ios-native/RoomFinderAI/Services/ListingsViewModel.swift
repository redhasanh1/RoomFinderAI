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
            await loadListings()
            await loadFeaturedListings()
            await loadFavoriteListings()
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
            let request = createSearchRequest()
            let response = try await supabaseService.fetchListings(request: request)
            
            if append {
                listings.append(contentsOf: response.listings)
            } else {
                listings = response.listings
            }
            
            hasNextPage = response.hasNextPage
            hasPreviousPage = response.hasPreviousPage
            totalPages = response.totalPages
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    @MainActor
    private func loadFeaturedListings() async {
        do {
            let request = ListingSearchRequest(
                query: nil,
                location: nil,
                minPrice: nil,
                maxPrice: nil,
                bedrooms: nil,
                bathrooms: nil,
                propertyType: nil,
                petFriendly: nil,
                smokingAllowed: nil,
                availableDate: nil,
                radius: nil,
                latitude: nil,
                longitude: nil,
                sortBy: .popularity,
                page: 1,
                limit: 10
            )
            
            let response = try await supabaseService.fetchListings(request: request)
            featuredListings = response.listings
        } catch {
            print("Error loading featured listings: \(error)")
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
        guard let userId = getCurrentUserId() else { return }
        
        do {
            try await supabaseService.toggleFavorite(listingId: listing.id, userId: userId)
            
            // Update local state
            if let index = listings.firstIndex(where: { $0.id == listing.id }) {
                listings[index] = Listing(
                    id: listing.id,
                    title: listing.title,
                    description: listing.description,
                    price: listing.price,
                    location: listing.location,
                    bedrooms: listing.bedrooms,
                    bathrooms: listing.bathrooms,
                    squareFootage: listing.squareFootage,
                    propertyType: listing.propertyType,
                    amenities: listing.amenities,
                    images: listing.images,
                    availableDate: listing.availableDate,
                    leaseTerm: listing.leaseTerm,
                    petPolicy: listing.petPolicy,
                    smokingPolicy: listing.smokingPolicy,
                    utilities: listing.utilities,
                    contactInfo: listing.contactInfo,
                    landlordId: listing.landlordId,
                    status: listing.status,
                    features: listing.features,
                    createdAt: listing.createdAt,
                    updatedAt: listing.updatedAt,
                    viewCount: listing.viewCount,
                    favoriteCount: listing.favoriteCount,
                    isFavorited: !listing.isFavorited
                )
            }
            
            // Update favorites list
            if listing.isFavorited {
                favoriteListings.removeAll { $0.id == listing.id }
            } else {
                favoriteListings.append(listing)
            }
            
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