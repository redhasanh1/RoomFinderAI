import SwiftUI
import Supabase

struct SearchHistoryView: View {
    @StateObject private var searchHistoryService: SearchHistoryService
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: SearchHistoryItem?
    @State private var showingClearAllAlert = false
    
    let onSearchSelected: ((String, SearchFilters?) -> Void)?
    
    init(authService: AuthService, supabaseClient: SupabaseClient, onSearchSelected: ((String, SearchFilters?) -> Void)? = nil) {
        self._searchHistoryService = StateObject(wrappedValue: SearchHistoryService(client: supabaseClient, authService: authService))
        self.onSearchSelected = onSearchSelected
    }
    
    var filteredHistory: [SearchHistoryItem] {
        if searchText.isEmpty {
            return searchHistoryService.searchHistory
        } else {
            return searchHistoryService.searchHistory.filter { item in
                item.query.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            NavigationView {
                ZStack {
                    if searchHistoryService.isLoading {
                        LoadingView(message: "Loading search history...")
                    } else if filteredHistory.isEmpty {
                        if searchText.isEmpty {
                            EmptySearchHistoryView {
                                dismiss()
                            }
                        } else {
                            NoResultsView(searchText: searchText)
                        }
                    } else {
                        SearchHistoryContentView(
                            searchHistory: filteredHistory,
                            onItemTap: { item in
                                onSearchSelected?(item.query, item.filters)
                                dismiss()
                            },
                            onDeleteItem: { item in
                                itemToDelete = item
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .navigationTitle("Search History")
                .navigationBarTitleDisplayMode(.large)
                .searchable(
                    text: $searchText,
                    prompt: "Search your history..."
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Refresh") {
                                Task {
                                    await searchHistoryService.fetchSearchHistory()
                                }
                            }
                            
                            if !searchHistoryService.searchHistory.isEmpty {
                                Button("Clear All", role: .destructive) {
                                    showingClearAllAlert = true
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
                .refreshable {
                    await searchHistoryService.fetchSearchHistory()
                }
            }
        }
        .alert("Delete Search Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    Task {
                        _ = await searchHistoryService.deleteSearchItem(id: item.id)
                    }
                }
                itemToDelete = nil
            }
        } message: {
            if let item = itemToDelete {
                Text("Are you sure you want to remove \"\(item.query)\" from your search history?")
            }
        }
        .alert("Clear All History", isPresented: $showingClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                Task {
                    _ = await searchHistoryService.clearAllHistory()
                }
            }
        } message: {
            Text("Are you sure you want to clear all your search history? This action cannot be undone.")
        }
        .task {
            await searchHistoryService.fetchSearchHistory()
        }
    }
}

struct SearchHistoryContentView: View {
    let searchHistory: [SearchHistoryItem]
    let onItemTap: (SearchHistoryItem) -> Void
    let onDeleteItem: (SearchHistoryItem) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Recent searches section
                if !searchHistory.isEmpty {
                    SectionHeaderView(title: "Recent Searches", icon: "clock.arrow.circlepath")
                    
                    ForEach(searchHistory.prefix(10)) { item in
                        SearchHistoryItemCard(
                            item: item,
                            onTap: {
                                onItemTap(item)
                            },
                            onDelete: {
                                onDeleteItem(item)
                            }
                        )
                    }
                }
                
                // Popular searches section if we have enough history
                let popularSearches = getPopularSearches()
                if !popularSearches.isEmpty {
                    SectionHeaderView(title: "Popular Searches", icon: "chart.line.uptrend.xyaxis")
                    
                    ForEach(popularSearches, id: \.self) { query in
                        PopularSearchCard(query: query) {
                            // Find the most recent item with this query for re-search
                            if let item = searchHistory.first(where: { $0.query.lowercased() == query.lowercased() }) {
                                onItemTap(item)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func getPopularSearches() -> [String] {
        let queryGroups = Dictionary(grouping: searchHistory, by: { $0.query.lowercased() })
        
        return queryGroups
            .filter { $1.count > 1 } // Only show queries that appear multiple times
            .map { (query, items) in (query, items.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0.0.capitalized }
    }
}

struct SearchHistoryItemCard: View {
    let item: SearchHistoryItem
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        GlassmorphismCard {
            HStack(spacing: 12) {
                // Search icon
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.query)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label("\(item.resultsCount) results", systemImage: "list.bullet")
                        
                        Text(item.searchedAt, style: .relative) + Text(" ago")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    
                    // Show filters if they exist
                    if let filters = item.filters {
                        SearchFiltersPreview(filters: filters)
                    }
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 8) {
                    Button(action: onTap) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                            .font(.title3)
                    }
                }
            }
            .padding()
        }
        .onTapGesture {
            onTap()
        }
    }
}

struct PopularSearchCard: View {
    let query: String
    let onTap: () -> Void
    
    var body: some View {
        GlassmorphismCard {
            HStack {
                Image(systemName: "flame")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text(query)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onTap) {
                    HStack(spacing: 4) {
                        Text("Search")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                }
            }
            .padding()
        }
        .onTapGesture {
            onTap()
        }
    }
}

struct SearchFiltersPreview: View {
    let filters: SearchFilters
    
    var body: some View {
        HStack(spacing: 8) {
            if let propertyType = filters.propertyType {
                FilterPreviewChip(text: propertyType.rawValue.capitalized, icon: "house")
            }
            
            if let location = filters.location, !location.isEmpty {
                FilterPreviewChip(text: location, icon: "location")
            }
            
            if let minPrice = filters.minPrice {
                FilterPreviewChip(text: "$\(Int(minPrice))+", icon: "dollarsign.circle")
            }
            
            if let maxPrice = filters.maxPrice {
                FilterPreviewChip(text: "Under $\(Int(maxPrice))", icon: "dollarsign.circle")
            }
            
            Spacer()
        }
    }
}

struct FilterPreviewChip: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.2))
        )
    }
}


struct SectionHeaderView: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.8))
                .font(.title3)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct EmptySearchHistoryView: View {
    let onBrowse: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Search History")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Start searching for properties to see your search history here. Your recent searches will help you find similar listings faster.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: onBrowse) {
                Text("Start Searching")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
            }
        }
        .padding()
    }
}

struct NoResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("No search history matches \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    SearchHistoryView(
        authService: AuthService(supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "key")),
        supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "key")
    )
}