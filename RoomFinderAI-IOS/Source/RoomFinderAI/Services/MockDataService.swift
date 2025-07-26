import Foundation

class MockDataService {
    static let shared = MockDataService()
    
    private init() {}
    
    // MARK: - Mock Listings Data
    
    func getSampleListings() -> [Listing] {
        return [
            Listing(
                id: "1",
                title: "Modern Downtown Apartment",
                description: "Beautiful 2-bedroom apartment in the heart of downtown. Features modern amenities, hardwood floors, and stunning city views.",
                price: 2500,
                city: "Toronto",
                street: "123 King Street",
                postalCode: "M5H 2Y7",
                houseType: "apartment",
                bedrooms: 2,
                utilities: "Heat and water included",
                media: [
                    "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800",
                    "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800"
                ],
                userEmail: "landlord1@example.com",
                createdAt: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                updatedAt: Date().addingTimeInterval(-86400 * 1)  // 1 day ago
            ),
            
            Listing(
                id: "2",
                title: "Cozy Studio Near University",
                description: "Perfect for students! Compact studio apartment with all essentials. Close to subway and university campus.",
                price: 1200,
                city: "Toronto",
                street: "456 College Street",
                postalCode: "M5G 1P5",
                houseType: "studio",
                bedrooms: 0,
                utilities: "Electricity included",
                media: [
                    "https://images.unsplash.com/photo-1560185127-6ed189bf02f4?w=800",
                    "https://images.unsplash.com/photo-1560184897-502e3b720fd8?w=800"
                ],
                userEmail: "landlord2@example.com",
                createdAt: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                updatedAt: Date().addingTimeInterval(-86400 * 3)  // 3 days ago
            ),
            
            Listing(
                id: "3",
                title: "Spacious Family House",
                description: "Large 4-bedroom house with backyard, perfect for families. Quiet neighborhood with schools nearby.",
                price: 3800,
                city: "Mississauga",
                street: "789 Elm Drive",
                postalCode: "L5M 3K2",
                houseType: "house",
                bedrooms: 4,
                utilities: "Tenant pays all utilities",
                media: [
                    "https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800",
                    "https://images.unsplash.com/photo-1588880331179-bc9b93a8cb5e?w=800"
                ],
                userEmail: "landlord3@example.com",
                createdAt: Date().addingTimeInterval(-86400 * 7), // 7 days ago
                updatedAt: Date().addingTimeInterval(-86400 * 2)  // 2 days ago
            ),
            
            Listing(
                id: "4",
                title: "Luxury Condo with Amenities",
                description: "High-end condo with gym, pool, and concierge. Floor-to-ceiling windows with lake views.",
                price: 4200,
                city: "Toronto",
                street: "321 Harbourfront",
                postalCode: "M5V 3A8",
                houseType: "condo",
                bedrooms: 3,
                utilities: "Heat, water, and internet included",
                media: [
                    "https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800",
                    "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800"
                ],
                userEmail: "landlord4@example.com",
                createdAt: Date().addingTimeInterval(-86400 * 1), // 1 day ago
                updatedAt: Date()  // Today
            ),
            
            Listing(
                id: "5",
                title: "Affordable Room in Shared House",
                description: "Single room in shared house with friendly roommates. Kitchen and living room access included.",
                price: 800,
                city: "Toronto",
                street: "654 Ossington Avenue",
                postalCode: "M6G 3T4",
                houseType: "room",
                bedrooms: 1,
                utilities: "All utilities included",
                media: [
                    "https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800"
                ],
                userEmail: "landlord5@example.com",
                createdAt: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                updatedAt: Date().addingTimeInterval(-86400 * 1)  // 1 day ago
            ),
            
            Listing(
                id: "6",
                title: "Modern Townhouse",
                description: "Brand new 3-bedroom townhouse with garage and private patio. Perfect for young professionals.",
                price: 3200,
                city: "Markham",
                street: "987 Main Street",
                postalCode: "L3R 5H6",
                houseType: "townhouse",
                bedrooms: 3,
                utilities: "Water included",
                media: [
                    "https://images.unsplash.com/photo-1558618666-fbd51c2cd9c6?w=800",
                    "https://images.unsplash.com/photo-1613977257363-707ba9348227?w=800"
                ],
                userEmail: "landlord6@example.com",
                createdAt: Date().addingTimeInterval(-86400 * 4), // 4 days ago
                updatedAt: Date().addingTimeInterval(-86400 * 2)  // 2 days ago
            )
        ]
    }
    
    // MARK: - Mock User Data
    
    func getSampleUser() -> User {
        return User(
            id: "user123",
            email: "user@example.com",
            firstName: "John",
            lastName: "Doe",
            profileImage: nil,
            createdAt: Date().addingTimeInterval(-86400 * 30), // 30 days ago
            updatedAt: Date()
        )
    }
    
    // MARK: - Filtering Methods
    
    func filterListings(
        _ listings: [Listing],
        searchQuery: String = "",
        location: String = "",
        propertyType: PropertyType? = nil,
        minPrice: Double = 0,
        maxPrice: Double = 10000,
        bedrooms: Int? = nil
    ) -> [Listing] {
        return listings.filter { listing in
            // Search query filter
            let matchesSearch = searchQuery.isEmpty ||
                listing.title.localizedCaseInsensitiveContains(searchQuery) ||
                listing.description?.localizedCaseInsensitiveContains(searchQuery) == true ||
                listing.city.localizedCaseInsensitiveContains(searchQuery)
            
            // Location filter
            let matchesLocation = location.isEmpty ||
                listing.city.localizedCaseInsensitiveContains(location) ||
                listing.street.localizedCaseInsensitiveContains(location)
            
            // Property type filter
            let matchesPropertyType = propertyType == nil ||
                listing.propertyType == propertyType
            
            // Price range filter
            let matchesPrice = Double(listing.price) >= minPrice && Double(listing.price) <= maxPrice
            
            // Bedrooms filter
            let matchesBedrooms = bedrooms == nil || listing.bedrooms == bedrooms
            
            return matchesSearch && matchesLocation && matchesPropertyType && matchesPrice && matchesBedrooms
        }
    }
    
    func sortListings(_ listings: [Listing], by sortOption: SortOption) -> [Listing] {
        switch sortOption {
        case .date:
            return listings.sorted { $0.createdAt > $1.createdAt }
        case .price:
            return listings.sorted { $0.price < $1.price }
        case .priceHigh:
            return listings.sorted { $0.price > $1.price }
        case .bedrooms:
            return listings.sorted { $0.bedrooms > $1.bedrooms }
        case .location:
            return listings.sorted { $0.city < $1.city }
        case .distance:
            // For now, just return as-is since we don't have location services
            return listings
        }
    }
}