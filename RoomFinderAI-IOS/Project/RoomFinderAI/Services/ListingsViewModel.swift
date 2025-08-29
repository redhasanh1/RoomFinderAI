import Foundation
import SwiftUI

class ListingsViewModel: ObservableObject {
    @Published var listings: [RoomListing] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    
    init() {
        loadSampleListings()
    }
    
    func loadListings() {
        isLoading = true
        errorMessage = nil
        
        // TODO: Implement Supabase data loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadSampleListings()
            self.isLoading = false
            print("Listings loaded: \(self.listings.count) items")
        }
    }
    
    func searchListings(query: String) {
        searchQuery = query
        // TODO: Implement search functionality
        print("Searching for: \(query)")
    }
    
    private func loadSampleListings() {
        listings = [
            RoomListing(
                id: "1",
                title: "Cozy Studio in Downtown",
                description: "Perfect for students and young professionals",
                price: 1200,
                location: "Downtown",
                imageURL: nil,
                amenities: ["WiFi", "Laundry", "Kitchen"]
            ),
            RoomListing(
                id: "2",
                title: "Shared Room near University",
                description: "Great location, friendly roommates",
                price: 800,
                location: "University District",
                imageURL: nil,
                amenities: ["WiFi", "Parking", "Study Area"]
            )
        ]
    }
}

