import SwiftUI
import Supabase

// MARK: - Optimized Home Screen with Pagination
struct OptimizedHomeScreen: View {
    @StateObject private var listingsService: HomeListingsService
    @State private var filteredListings: [HomePageListing] = []
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedFilters: Set<String> = []
    @State private var selectedSort = "Recent"
    @State private var showingSortOptions = false
    @State private var searchDebounceTask: Task<Void, Never>?
    
    let filterOptions = ["Studio", "1 Bed", "2 Bed", "3+ Bed", "Apartment", "House", "Furnished"]
    let sortOptions = ["Recent", "Price: Low to High", "Price: High to Low", "Alphabetical"]
    
    init() {
        let supabaseClient = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey
        )
        self._listingsService = StateObject(wrappedValue: HomeListingsService(client: supabaseClient))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Enhanced Header with Search
                    headerSection
                    
                    // Content Section with Infinite Scroll
                    contentSection
                    
                    // Load More Indicator
                    if listingsService.isLoadingMore {
                        loadMoreIndicator
                    }
                }
                .padding(.horizontal, 8)
            }
            .navigationBarHidden(true)
            .refreshable {
                await refreshListings()
            }
            .onAppear {
                Task {
                    await loadInitialData()
                }
            }
            .onChange(of: searchText) { newValue in
                debounceSearch(newValue)
            }
            .onChange(of: selectedFilters) { _ in
                applyFiltersAndSort()
            }
            .onChange(of: selectedSort) { _ in
                applyFiltersAndSort()
            }
            .confirmationDialog("Sort By", isPresented: $showingSortOptions, titleVisibility: .visible) {
                ForEach(sortOptions, id: \.self) { option in
                    Button(option) {
                        selectedSort = option
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Title and Sort Button
            HStack {
                Text("Find Your Room")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                
                Button(action: { showingSortOptions = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("Sort")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal)
            
            // Search Bar with Debouncing
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search by location, title...", text: $searchText)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        debouncedSearchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Filter Chips
            if !filterOptions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filterOptions, id: \.self) { filter in
                            FilterChipView(
                                title: filter,
                                isSelected: selectedFilters.contains(filter)
                            ) {
                                toggleFilter(filter)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Results Count with Load Time
            if !filteredListings.isEmpty {
                HStack {
                    Text("\(filteredListings.count) properties • Updated \(formatLastUpdate())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        Group {
            if listingsService.isLoading && listingsService.listings.isEmpty {
                // Initial Loading with Skeleton
                skeletonLoadingView
            } else if let error = listingsService.error {
                // Error State
                errorView(error: error)
            } else if filteredListings.isEmpty {
                // Empty State
                emptyStateView
            } else {
                // Listings Grid with Infinite Scroll
                listingsGridView
            }
        }
    }
    
    // MARK: - Skeleton Loading View
    private var skeletonLoadingView: some View {
        VStack(spacing: 16) {
            // Section Header Skeleton
            HStack {
                Text("Featured Properties")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
                .opacity(0.3)
                .padding(.horizontal, 20)
            
            // Skeleton Cards
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonListingCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Listings Grid with Infinite Scroll
    private var listingsGridView: some View {
        VStack(spacing: 16) {
            // Section Header
            HStack {
                Text("Featured Properties")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { showingSortOptions = true }) {
                    HStack(spacing: 4) {
                        Text("Sort")
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
                .opacity(0.3)
                .padding(.horizontal, 20)
            
            // Optimized Grid with Infinite Scroll
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredListings) { listing in
                    OptimizedListingCard(listing: listing)
                        .onAppear {
                            // Infinite scroll trigger
                            if listingsService.shouldLoadMore(for: listing) {
                                Task {
                                    await listingsService.loadNextPage()
                                    applyFiltersAndSort()
                                }
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Error View
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("Oops! Something went wrong")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await listingsService.refreshListings()
                    applyFiltersAndSort()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No rooms found")
                .font(.headline)
            Text("Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Clear Filters") {
                searchText = ""
                debouncedSearchText = ""
                selectedFilters.removeAll()
                applyFiltersAndSort()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Load More Indicator
    private var loadMoreIndicator: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading more listings...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Functions
    
    private func loadInitialData() async {
        await listingsService.loadFirstPage()
        applyFiltersAndSort()
    }
    
    private func refreshListings() async {
        await listingsService.refreshListings()
        applyFiltersAndSort()
    }
    
    private func debounceSearch(_ searchText: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if !Task.isCancelled {
                debouncedSearchText = searchText
                applyFiltersAndSort()
            }
        }
    }
    
    private func toggleFilter(_ filter: String) {
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }
    }
    
    private func applyFiltersAndSort() {
        var filtered = listingsService.listings
        
        // Apply search filter with debounced text
        if !debouncedSearchText.isEmpty {
            filtered = filtered.filter { listing in
                let titleMatch = listing.title?.lowercased().contains(debouncedSearchText.lowercased()) ?? false
                let cityMatch = listing.city?.lowercased().contains(debouncedSearchText.lowercased()) ?? false
                let descriptionMatch = listing.description?.lowercased().contains(debouncedSearchText.lowercased()) ?? false
                return titleMatch || cityMatch || descriptionMatch
            }
        }
        
        // Apply category filters
        if !selectedFilters.isEmpty {
            filtered = filtered.filter { listing in
                for filter in selectedFilters {
                    switch filter {
                    case "Studio":
                        if listing.bedrooms == 0 { return true }
                    case "1 Bed":
                        if listing.bedrooms == 1 { return true }
                    case "2 Bed":
                        if listing.bedrooms == 2 { return true }
                    case "3+ Bed":
                        if (listing.bedrooms ?? 0) >= 3 { return true }
                    case "Apartment":
                        if listing.house_type?.lowercased().contains("apartment") == true { return true }
                    case "House":
                        if listing.house_type?.lowercased().contains("house") == true { return true }
                    case "Furnished":
                        if listing.description?.lowercased().contains("furnished") == true { return true }
                    default:
                        break
                    }
                }
                return false
            }
        }
        
        // Apply sorting
        switch selectedSort {
        case "Recent":
            filtered.sort { ($0.created_at ?? "") > ($1.created_at ?? "") }
        case "Price: Low to High":
            filtered.sort { ($0.price ?? 0) < ($1.price ?? 0) }
        case "Price: High to Low":
            filtered.sort { ($0.price ?? 0) > ($1.price ?? 0) }
        case "Alphabetical":
            filtered.sort { ($0.title ?? "") < ($1.title ?? "") }
        default:
            break
        }
        
        filteredListings = filtered
    }
    
    private func formatLastUpdate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}