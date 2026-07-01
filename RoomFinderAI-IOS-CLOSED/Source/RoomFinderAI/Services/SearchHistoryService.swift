import Foundation
import Supabase
import Combine

@MainActor
final class SearchHistoryService: ObservableObject {
    @Published var searchHistory: [SearchHistoryItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let client: SupabaseClient
    private let authService: AuthService
    private let maxHistoryItems = 50
    
    init(client: SupabaseClient, authService: AuthService) {
        self.client = client
        self.authService = authService
    }
    
    // MARK: - Fetch Search History
    func fetchSearchHistory() async {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        error = nil
        
        do {
            let response: [SearchHistoryItem] = try await client
                .from("search_history")
                .select("*")
                .eq("user_id", value: userId)
                .order("searched_at", ascending: false)
                .limit(maxHistoryItems)
                .execute()
                .value
            
            searchHistory = response
        } catch {
            self.error = "Failed to fetch search history: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Add Search Query
    func addSearchQuery(
        query: String,
        filters: SearchFilters? = nil,
        resultsCount: Int = 0
    ) async {
        guard let userId = authService.currentUser?.id else { return }
        
        // Don't save empty queries
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        
        do {
            struct SearchHistoryInsert: Codable {
                let user_id: String
                let query: String
                let filters: String?
                let results_count: Int
                let searched_at: String
            }
            
            let filtersString: String?
            if let filters = filters {
                filtersString = try? String(data: JSONEncoder().encode(filters), encoding: .utf8)
            } else {
                filtersString = nil
            }
            
            let searchItem = SearchHistoryInsert(
                user_id: userId,
                query: query,
                filters: filtersString,
                results_count: resultsCount,
                searched_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client
                .from("search_history")
                .insert(searchItem)
                .execute()
            
            // Refresh history to show the new item
            await fetchSearchHistory()
            
            // Clean up old history if needed
            await cleanupOldHistory()
        } catch {
            self.error = "Failed to save search query: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Delete Search Item
    func deleteSearchItem(id: String) async -> Bool {
        guard authService.currentUser != nil else { return false }
        
        do {
            try await client
                .from("search_history")
                .delete()
                .eq("id", value: id)
                .execute()
            
            // Remove from local array
            searchHistory.removeAll { $0.id == id }
            return true
        } catch {
            self.error = "Failed to delete search item: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Clear All History
    func clearAllHistory() async -> Bool {
        guard let userId = authService.currentUser?.id else { return false }
        
        do {
            try await client
                .from("search_history")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            
            searchHistory.removeAll()
            return true
        } catch {
            self.error = "Failed to clear search history: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Get Search Suggestions
    func getSearchSuggestions(for partialQuery: String) -> [String] {
        let lowercaseQuery = partialQuery.lowercased()
        
        return searchHistory
            .compactMap { $0.query }
            .filter { $0.lowercased().contains(lowercaseQuery) }
            .removingDuplicates()
            .prefix(5)
            .map { $0 }
    }
    
    // MARK: - Get Recent Searches
    func getRecentSearches(limit: Int = 10) -> [SearchHistoryItem] {
        return Array(searchHistory.prefix(limit))
    }
    
    // MARK: - Get Popular Searches
    func getPopularSearches(limit: Int = 5) -> [String] {
        let queryGroups = Dictionary(grouping: searchHistory, by: { $0.query.lowercased() })
        
        return queryGroups
            .map { (query, items) in (query, items.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0.capitalized }
    }
    
    // MARK: - Search by Filters
    func searchWithFilters(_ filters: SearchFilters) -> [SearchHistoryItem] {
        return searchHistory.filter { item in
            guard let itemFilters = item.filters else { return false }
            
            // Check if filters match
            if let propertyType = filters.propertyType,
               let itemPropertyType = itemFilters.propertyType,
               propertyType != itemPropertyType {
                return false
            }
            
            if let location = filters.location,
               let itemLocation = itemFilters.location,
               !itemLocation.localizedCaseInsensitiveContains(location) {
                return false
            }
            
            return true
        }
    }
    
    // MARK: - Private Methods
    private func cleanupOldHistory() async {
        guard authService.currentUser?.id != nil else { return }
        
        // Keep only the most recent items if we exceed the limit
        if searchHistory.count > maxHistoryItems {
            let oldestItems = searchHistory.suffix(searchHistory.count - maxHistoryItems)
            
            for item in oldestItems {
                _ = await deleteSearchItem(id: item.id)
            }
        }
    }
}

// MARK: - Array Extension
extension Array where Element: Equatable {
    func removingDuplicates() -> [Element] {
        var result = [Element]()
        for element in self {
            if !result.contains(element) {
                result.append(element)
            }
        }
        return result
    }
}