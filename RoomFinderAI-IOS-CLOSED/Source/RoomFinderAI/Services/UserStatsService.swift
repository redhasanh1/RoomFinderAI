import Foundation
import Supabase
import Combine

@MainActor
final class UserStatsService: ObservableObject {
    @Published var userStats: UserStats?
    @Published var isLoading = false
    @Published var error: String?
    
    private let client: SupabaseClient
    private let authService: AuthService
    
    init(client: SupabaseClient, authService: AuthService) {
        self.client = client
        self.authService = authService
    }
    
    // MARK: - Fetch User Statistics
    func fetchUserStats() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        error = nil
        
        async let listingsCount = fetchUserListingsCount(userId: userId)
        async let savedListingsCount = fetchSavedListingsCount(userId: userId)
        async let messagesCount = fetchMessagesCount(userId: userId)
        async let reviewsCount = fetchReviewsCount(userId: userId)
        async let averageRating = fetchAverageRating(userId: userId)
        
        let stats = UserStats(
            userId: userId,
            listingsCount: await listingsCount,
            savedListingsCount: await savedListingsCount,
            messagesCount: await messagesCount,
            reviewsCount: await reviewsCount,
            averageRating: await averageRating,
            lastUpdated: Date()
        )
        
        userStats = stats
        
        // Cache the stats in database
        await cacheUserStats(stats)
        
        isLoading = false
    }
    
    // MARK: - Fetch Individual Stats
    private func fetchUserListingsCount(userId: String) async -> Int {
        do {
            let response = try await client
                .from("listings")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .execute()
            
            return response.count ?? 0
        } catch {
            print("Failed to fetch listings count: \(error)")
            return 0
        }
    }
    
    private func fetchSavedListingsCount(userId: String) async -> Int {
        do {
            let response = try await client
                .from("saved_listings")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .execute()
            
            return response.count ?? 0
        } catch {
            print("Failed to fetch saved listings count: \(error)")
            return 0
        }
    }
    
    private func fetchMessagesCount(userId: String) async -> Int {
        do {
            // Count messages where user is either sender or receiver
            let sentResponse = try await client
                .from("messages")
                .select("id", head: true, count: .exact)
                .eq("sender_id", value: userId)
                .execute()
            
            let receivedResponse = try await client
                .from("messages")
                .select("id", head: true, count: .exact)
                .eq("receiver_id", value: userId)
                .execute()
            
            return (sentResponse.count ?? 0) + (receivedResponse.count ?? 0)
        } catch {
            print("Failed to fetch messages count: \(error)")
            return 0
        }
    }
    
    private func fetchReviewsCount(userId: String) async -> Int {
        do {
            let response = try await client
                .from("reviews")
                .select("id", head: true, count: .exact)
                .eq("reviewee_id", value: userId)
                .execute()
            
            return response.count ?? 0
        } catch {
            print("Failed to fetch reviews count: \(error)")
            return 0
        }
    }
    
    private func fetchAverageRating(userId: String) async -> Double? {
        do {
            struct RatingRow: Codable {
                let rating: Double
            }
            
            let response: [RatingRow] = try await client
                .from("reviews")
                .select("rating")
                .eq("reviewee_id", value: userId)
                .execute()
                .value
            
            let ratings = response.map { $0.rating }
            
            if ratings.isEmpty {
                return nil
            }
            
            let sum = ratings.reduce(0, +)
            return sum / Double(ratings.count)
        } catch {
            print("Failed to fetch average rating: \(error)")
            return nil
        }
    }
    
    // MARK: - Cache Stats in Database
    private func cacheUserStats(_ stats: UserStats) async {
        do {
            try await client
                .from("user_stats")
                .upsert(stats)
                .execute()
        } catch {
            print("Failed to cache user stats: \(error)")
        }
    }
    
    // MARK: - Get Cached Stats
    func getCachedStats() async -> UserStats? {
        guard let userId = authService.currentUser?.id else { return nil }
        
        do {
            let response: [UserStats] = try await client
                .from("user_stats")
                .select("*")
                .eq("user_id", value: userId)
                .order("last_updated", ascending: false)
                .limit(1)
                .execute()
                .value
            
            return response.first
        } catch {
            print("Failed to fetch cached stats: \(error)")
            return nil
        }
    }
    
    // MARK: - Refresh Stats
    func refreshStats() async {
        // Always fetch fresh data
        await fetchUserStats()
    }
    
    // MARK: - Update Specific Stat
    func incrementListingsCount() async {
        guard var stats = userStats else { return }
        stats = UserStats(
            userId: stats.userId,
            listingsCount: stats.listingsCount + 1,
            savedListingsCount: stats.savedListingsCount,
            messagesCount: stats.messagesCount,
            reviewsCount: stats.reviewsCount,
            averageRating: stats.averageRating,
            lastUpdated: Date()
        )
        userStats = stats
        await cacheUserStats(stats)
    }
    
    func decrementListingsCount() async {
        guard var stats = userStats else { return }
        stats = UserStats(
            userId: stats.userId,
            listingsCount: max(0, stats.listingsCount - 1),
            savedListingsCount: stats.savedListingsCount,
            messagesCount: stats.messagesCount,
            reviewsCount: stats.reviewsCount,
            averageRating: stats.averageRating,
            lastUpdated: Date()
        )
        userStats = stats
        await cacheUserStats(stats)
    }
    
    func updateSavedListingsCount(_ count: Int) async {
        guard var stats = userStats else { return }
        stats = UserStats(
            userId: stats.userId,
            listingsCount: stats.listingsCount,
            savedListingsCount: count,
            messagesCount: stats.messagesCount,
            reviewsCount: stats.reviewsCount,
            averageRating: stats.averageRating,
            lastUpdated: Date()
        )
        userStats = stats
        await cacheUserStats(stats)
    }
    
    func incrementMessagesCount() async {
        guard var stats = userStats else { return }
        stats = UserStats(
            userId: stats.userId,
            listingsCount: stats.listingsCount,
            savedListingsCount: stats.savedListingsCount,
            messagesCount: stats.messagesCount + 1,
            reviewsCount: stats.reviewsCount,
            averageRating: stats.averageRating,
            lastUpdated: Date()
        )
        userStats = stats
        await cacheUserStats(stats)
    }
    
    // MARK: - Computed Properties
    var hasListings: Bool {
        return (userStats?.listingsCount ?? 0) > 0
    }
    
    var hasSavedListings: Bool {
        return (userStats?.savedListingsCount ?? 0) > 0
    }
    
    var hasMessages: Bool {
        return (userStats?.messagesCount ?? 0) > 0
    }
    
    var hasReviews: Bool {
        return (userStats?.reviewsCount ?? 0) > 0
    }
    
    var formattedAverageRating: String {
        guard let rating = userStats?.averageRating else { return "N/A" }
        return String(format: "%.1f", rating)
    }
}