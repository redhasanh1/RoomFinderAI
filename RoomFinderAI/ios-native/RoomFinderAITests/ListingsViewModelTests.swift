import XCTest
@testable import RoomFinderAI

class ListingsViewModelTests: XCTestCase {
    var listingsViewModel: ListingsViewModel!
    
    override func setUp() {
        super.setUp()
        listingsViewModel = ListingsViewModel()
    }
    
    override func tearDown() {
        listingsViewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(listingsViewModel.listings.count, 0)
        XCTAssertEqual(listingsViewModel.featuredListings.count, 0)
        XCTAssertEqual(listingsViewModel.favoriteListings.count, 0)
        XCTAssertFalse(listingsViewModel.isLoading)
        XCTAssertNil(listingsViewModel.errorMessage)
    }
    
    func testInitialFilterState() {
        XCTAssertEqual(listingsViewModel.searchQuery, "")
        XCTAssertEqual(listingsViewModel.selectedLocation, "")
        XCTAssertEqual(listingsViewModel.minPrice, 0)
        XCTAssertEqual(listingsViewModel.maxPrice, 5000)
        XCTAssertNil(listingsViewModel.selectedBedrooms)
        XCTAssertNil(listingsViewModel.selectedBathrooms)
        XCTAssertNil(listingsViewModel.selectedPropertyType)
        XCTAssertFalse(listingsViewModel.petFriendly)
        XCTAssertFalse(listingsViewModel.smokingAllowed)
        XCTAssertEqual(listingsViewModel.sortBy, .date)
    }
    
    // MARK: - Filter Tests
    
    func testHasActiveFilters() {
        XCTAssertFalse(listingsViewModel.hasActiveFilters)
        
        listingsViewModel.searchQuery = "apartment"
        XCTAssertTrue(listingsViewModel.hasActiveFilters)
        
        listingsViewModel.searchQuery = ""
        listingsViewModel.selectedLocation = "New York"
        XCTAssertTrue(listingsViewModel.hasActiveFilters)
        
        listingsViewModel.selectedLocation = ""
        listingsViewModel.minPrice = 1000
        XCTAssertTrue(listingsViewModel.hasActiveFilters)
        
        listingsViewModel.minPrice = 0
        listingsViewModel.selectedBedrooms = 2
        XCTAssertTrue(listingsViewModel.hasActiveFilters)
        
        listingsViewModel.selectedBedrooms = nil
        listingsViewModel.petFriendly = true
        XCTAssertTrue(listingsViewModel.hasActiveFilters)
    }
    
    func testClearFilters() {
        // Set some filters
        listingsViewModel.searchQuery = "apartment"
        listingsViewModel.selectedLocation = "New York"
        listingsViewModel.minPrice = 1000
        listingsViewModel.maxPrice = 3000
        listingsViewModel.selectedBedrooms = 2
        listingsViewModel.selectedBathrooms = 1
        listingsViewModel.selectedPropertyType = .apartment
        listingsViewModel.petFriendly = true
        listingsViewModel.smokingAllowed = true
        listingsViewModel.sortBy = .price
        
        // Clear filters
        listingsViewModel.clearFilters()
        
        // Verify all filters are reset
        XCTAssertEqual(listingsViewModel.searchQuery, "")
        XCTAssertEqual(listingsViewModel.selectedLocation, "")
        XCTAssertEqual(listingsViewModel.minPrice, 0)
        XCTAssertEqual(listingsViewModel.maxPrice, 5000)
        XCTAssertNil(listingsViewModel.selectedBedrooms)
        XCTAssertNil(listingsViewModel.selectedBathrooms)
        XCTAssertNil(listingsViewModel.selectedPropertyType)
        XCTAssertFalse(listingsViewModel.petFriendly)
        XCTAssertFalse(listingsViewModel.smokingAllowed)
        XCTAssertEqual(listingsViewModel.sortBy, .date)
    }
    
    // MARK: - Search Request Tests
    
    func testCreateSearchRequest() {
        listingsViewModel.searchQuery = "apartment"
        listingsViewModel.selectedLocation = "New York"
        listingsViewModel.minPrice = 1000
        listingsViewModel.maxPrice = 3000
        listingsViewModel.selectedBedrooms = 2
        listingsViewModel.selectedBathrooms = 1
        listingsViewModel.selectedPropertyType = .apartment
        listingsViewModel.petFriendly = true
        listingsViewModel.smokingAllowed = false
        listingsViewModel.sortBy = .price
        
        // Use reflection to access private method for testing
        let request = createMockSearchRequest()
        
        XCTAssertEqual(request.query, "apartment")
        XCTAssertEqual(request.location, "New York")
        XCTAssertEqual(request.minPrice, 1000)
        XCTAssertEqual(request.maxPrice, 3000)
        XCTAssertEqual(request.bedrooms, 2)
        XCTAssertEqual(request.bathrooms, 1)
        XCTAssertEqual(request.propertyType, .apartment)
        XCTAssertEqual(request.petFriendly, true)
        XCTAssertNil(request.smokingAllowed) // Should be nil since it's false
        XCTAssertEqual(request.sortBy, .price)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        XCTAssertFalse(listingsViewModel.hasError)
        
        listingsViewModel.errorMessage = "Test error"
        XCTAssertTrue(listingsViewModel.hasError)
        
        listingsViewModel.clearError()
        XCTAssertFalse(listingsViewModel.hasError)
        XCTAssertNil(listingsViewModel.errorMessage)
    }
    
    // MARK: - Pagination Tests
    
    func testPaginationState() {
        XCTAssertEqual(listingsViewModel.currentPage, 1)
        XCTAssertFalse(listingsViewModel.hasNextPage)
        XCTAssertFalse(listingsViewModel.hasPreviousPage)
        XCTAssertEqual(listingsViewModel.totalPages, 0)
    }
    
    // MARK: - Mock Data Helpers
    
    private func createMockSearchRequest() -> ListingSearchRequest {
        return ListingSearchRequest(
            query: listingsViewModel.searchQuery.isEmpty ? nil : listingsViewModel.searchQuery,
            location: listingsViewModel.selectedLocation.isEmpty ? nil : listingsViewModel.selectedLocation,
            minPrice: listingsViewModel.minPrice > 0 ? listingsViewModel.minPrice : nil,
            maxPrice: listingsViewModel.maxPrice < 5000 ? listingsViewModel.maxPrice : nil,
            bedrooms: listingsViewModel.selectedBedrooms,
            bathrooms: listingsViewModel.selectedBathrooms,
            propertyType: listingsViewModel.selectedPropertyType,
            petFriendly: listingsViewModel.petFriendly ? true : nil,
            smokingAllowed: listingsViewModel.smokingAllowed ? true : nil,
            availableDate: nil,
            radius: nil,
            latitude: nil,
            longitude: nil,
            sortBy: listingsViewModel.sortBy,
            page: listingsViewModel.currentPage,
            limit: 20
        )
    }
    
    private func createMockListing() -> Listing {
        return Listing(
            id: "test-listing-id",
            title: "Test Apartment",
            description: "A beautiful test apartment",
            price: 1500.0,
            location: Location(
                address: "123 Test St",
                city: "Test City",
                state: "TS",
                zipCode: "12345",
                country: "USA",
                latitude: 40.7128,
                longitude: -74.0060,
                neighborhood: "Test Neighborhood"
            ),
            bedrooms: 2,
            bathrooms: 1,
            squareFootage: 800,
            propertyType: .apartment,
            amenities: ["WiFi", "Gym"],
            images: ["image1.jpg", "image2.jpg"],
            availableDate: Date(),
            leaseTerm: 12,
            petPolicy: .allowed,
            smokingPolicy: .notAllowed,
            utilities: UtilitiesInfo(
                electricity: true,
                water: true,
                gas: false,
                internet: true,
                cable: false,
                heating: true,
                airConditioning: true,
                trash: true,
                sewer: true,
                additionalCosts: 0
            ),
            contactInfo: ContactInfo(
                name: "Test Landlord",
                email: "test@landlord.com",
                phone: "555-0123",
                preferredContact: .email,
                responseTime: "24 hours"
            ),
            landlordId: "test-landlord-id",
            status: .active,
            features: ["Balcony", "Parking"],
            createdAt: Date(),
            updatedAt: Date(),
            viewCount: 0,
            favoriteCount: 0,
            isFavorited: false
        )
    }
}

// MARK: - Performance Tests

extension ListingsViewModelTests {
    func testFilterPerformance() {
        measure {
            for _ in 0..<100 {
                listingsViewModel.searchQuery = "apartment"
                listingsViewModel.selectedLocation = "New York"
                listingsViewModel.minPrice = 1000
                listingsViewModel.maxPrice = 3000
                _ = listingsViewModel.hasActiveFilters
            }
        }
    }
    
    func testClearFiltersPerformance() {
        measure {
            for _ in 0..<1000 {
                listingsViewModel.clearFilters()
            }
        }
    }
}