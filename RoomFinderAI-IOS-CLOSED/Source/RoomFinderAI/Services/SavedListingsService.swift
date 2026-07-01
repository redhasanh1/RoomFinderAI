import Foundation
import Supabase
import Combine

@MainActor
final class SavedListingsService: ObservableObject {
    @Published var savedListings: [SavedListing] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let client: SupabaseClient
    private let authService: AuthService
    
    init(client: SupabaseClient, authService: AuthService) {
        self.client = client
        self.authService = authService
    }
    
    // MARK: - Fetch Saved Listings
    func fetchSavedListings() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        error = nil
        
        do {
            let response: [SavedListing] = try await client
                .from("saved_listings")
                .select("""
                    id,
                    user_id,
                    listing_id,
                    saved_at,
                    listing:listings(*)
                """)
                .eq("user_id", value: userId)
                .order("saved_at", ascending: false)
                .execute()
                .value
            
            savedListings = response
        } catch {
            self.error = "Failed to fetch saved listings: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Add to Saved
    func addToSaved(listingId: String) async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }
        
        // Check if already saved
        if isListingSaved(listingId: listingId) {
            return true
        }
        
        do {
            let savedListing = [
                "user_id": userId,
                "listing_id": listingId,
                "saved_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            try await client
                .from("saved_listings")
                .insert(savedListing)
                .execute()
            
            // Refresh the list
            await fetchSavedListings()
            return true
        } catch {
            self.error = "Failed to save listing: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Remove from Saved
    func removeFromSaved(listingId: String) async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }
        
        do {
            try await client
                .from("saved_listings")
                .delete()
                .eq("user_id", value: userId)
                .eq("listing_id", value: listingId)
                .execute()
            
            // Remove from local array
            savedListings.removeAll { $0.listingId == listingId }
            return true
        } catch {
            self.error = "Failed to remove saved listing: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Toggle Saved Status
    func toggleSaved(listingId: String) async -> Bool {
        if isListingSaved(listingId: listingId) {
            return await removeFromSaved(listingId: listingId)
        } else {
            return await addToSaved(listingId: listingId)
        }
    }
    
    // MARK: - Check if Listing is Saved
    func isListingSaved(listingId: String) -> Bool {
        return savedListings.contains { $0.listingId == listingId }
    }
    
    // MARK: - Get Saved Listings Count
    var savedListingsCount: Int {
        return savedListings.count
    }
    
    // MARK: - Clear All Saved Listings
    func clearAllSavedListings() async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }
        
        do {
            try await client
                .from("saved_listings")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            
            savedListings.removeAll()
            return true
        } catch {
            self.error = "Failed to clear saved listings: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Get Saved Listing by ID
    func getSavedListing(listingId: String) -> SavedListing? {
        return savedListings.first { $0.listingId == listingId }
    }
}