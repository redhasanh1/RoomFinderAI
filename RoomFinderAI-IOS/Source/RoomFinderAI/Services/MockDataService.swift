import Foundation

class MockDataService {
    static let shared = MockDataService()
    
    private init() {}
    
    // MARK: - Mock Listings Data
    
    func getSampleListings() -> [Listing] {
        // Create listings using JSON encoding/decoding to match new Listing model
        let sampleData = [
            [
                "id": "1",
                "title": "Modern Downtown Apartment",
                "description": "Beautiful 2-bedroom apartment in the heart of downtown. Features modern amenities, hardwood floors, and stunning city views.",
                "price": 2500,
                "city": "Toronto",
                "street": "123 King Street",
                "postal_code": "M5H 2Y7",
                "house_type": "apartment",
                "bedrooms": 2,
                "utilities": "Heat and water included",
                "media": [
                    "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800",
                    "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800"
                ],
                "user_email": "landlord1@example.com",
                "created_at": "2025-08-12T00:00:00Z", // 2 days ago
                "updated_at": "2025-08-13T00:00:00Z"  // 1 day ago
            ],
            [
                "id": "2",
                "title": "Cozy Studio Near University",
                "description": "Perfect for students! Compact studio apartment with all essentials. Close to subway and university campus.",
                "price": 1200,
                "city": "Toronto",
                "street": "456 College Street",
                "postal_code": "M5G 1P5",
                "house_type": "studio",
                "bedrooms": 0,
                "utilities": "Electricity included",
                "media": [
                    "https://images.unsplash.com/photo-1560185127-6ed189bf02f4?w=800",
                    "https://images.unsplash.com/photo-1560184897-502e3b720fd8?w=800"
                ],
                "user_email": "landlord2@example.com",
                "created_at": "2025-08-09T00:00:00Z", // 5 days ago
                "updated_at": "2025-08-11T00:00:00Z"  // 3 days ago
            ],
            [
                "id": "3",
                "title": "Spacious Family House",
                "description": "Large 4-bedroom house with backyard, perfect for families. Quiet neighborhood with schools nearby.",
                "price": 3800,
                "city": "Mississauga",
                "street": "789 Elm Drive",
                "postal_code": "L5M 3K2",
                "house_type": "house",
                "bedrooms": 4,
                "utilities": "Tenant pays all utilities",
                "media": [
                    "https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800",
                    "https://images.unsplash.com/photo-1588880331179-bc9b93a8cb5e?w=800"
                ],
                "user_email": "landlord3@example.com",
                "created_at": "2025-08-07T00:00:00Z", // 7 days ago
                "updated_at": "2025-08-12T00:00:00Z"  // 2 days ago
            ],
            [
                "id": "4",
                "title": "Luxury Condo with Amenities",
                "description": "High-end condo with gym, pool, and concierge. Floor-to-ceiling windows with lake views.",
                "price": 4200,
                "city": "Toronto",
                "street": "321 Harbourfront",
                "postal_code": "M5V 3A8",
                "house_type": "condo",
                "bedrooms": 3,
                "utilities": "Heat, water, and internet included",
                "media": [
                    "https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800",
                    "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800"
                ],
                "user_email": "landlord4@example.com",
                "created_at": "2025-08-13T00:00:00Z", // 1 day ago
                "updated_at": "2025-08-14T00:00:00Z"  // Today
            ],
            [
                "id": "5",
                "title": "Affordable Room in Shared House",
                "description": "Single room in shared house with friendly roommates. Kitchen and living room access included.",
                "price": 800,
                "city": "Toronto",
                "street": "654 Ossington Avenue",
                "postal_code": "M6G 3T4",
                "house_type": "room",
                "bedrooms": 1,
                "utilities": "All utilities included",
                "media": [
                    "https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800"
                ],
                "user_email": "landlord5@example.com",
                "created_at": "2025-08-11T00:00:00Z", // 3 days ago
                "updated_at": "2025-08-13T00:00:00Z"  // 1 day ago
            ],
            [
                "id": "6",
                "title": "Modern Townhouse",
                "description": "Brand new 3-bedroom townhouse with garage and private patio. Perfect for young professionals.",
                "price": 3200,
                "city": "Markham",
                "street": "987 Main Street",
                "postal_code": "L3R 5H6",
                "house_type": "townhouse",
                "bedrooms": 3,
                "utilities": "Water included",
                "media": [
                    "https://images.unsplash.com/photo-1558618666-fbd51c2cd9c6?w=800",
                    "https://images.unsplash.com/photo-1613977257363-707ba9348227?w=800"
                ],
                "user_email": "landlord6@example.com",
                "created_at": "2025-08-10T00:00:00Z", // 4 days ago
                "updated_at": "2025-08-12T00:00:00Z"  // 2 days ago
            ]
        ]
        
        // Convert to Listing objects using JSON encoding/decoding
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sampleData)
            return try JSONDecoder().decode([Listing].self, from: jsonData)
        } catch {
            print("Failed to create mock listings: \(error)")
            return []
        }
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
                (listing.title?.localizedCaseInsensitiveContains(searchQuery) == true) ||
                (listing.description?.localizedCaseInsensitiveContains(searchQuery) == true) ||
                (listing.city?.localizedCaseInsensitiveContains(searchQuery) == true)
            
            // Location filter
            let matchesLocation = location.isEmpty ||
                (listing.city?.localizedCaseInsensitiveContains(location) == true) ||
                (listing.street?.localizedCaseInsensitiveContains(location) == true)
            
            // Property type filter
            let matchesPropertyType = propertyType == nil ||
                listing.propertyType == propertyType
            
            // Price range filter
            let listingPrice = listing.price ?? 0
            let matchesPrice = listingPrice >= minPrice && listingPrice <= maxPrice
            
            // Bedrooms filter
            let matchesBedrooms = bedrooms == nil || listing.bedrooms == bedrooms
            
            return matchesSearch && matchesLocation && matchesPropertyType && matchesPrice && matchesBedrooms
        }
    }
    
    func sortListings(_ listings: [Listing], by sortOption: SortOption) -> [Listing] {
        switch sortOption {
        case .date:
            return listings.sorted { ($0.created_at ?? "") > ($1.created_at ?? "") }
        case .price:
            return listings.sorted { ($0.price ?? 0) < ($1.price ?? 0) }
        case .priceHigh:
            return listings.sorted { ($0.price ?? 0) > ($1.price ?? 0) }
        case .bedrooms:
            return listings.sorted { ($0.bedrooms ?? 0) > ($1.bedrooms ?? 0) }
        case .location:
            return listings.sorted { ($0.city ?? "") < ($1.city ?? "") }
        case .distance:
            // For now, just return as-is since we don't have location services
            return listings
        }
    }
}