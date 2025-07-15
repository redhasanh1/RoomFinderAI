import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var properties: [Property] = []
    @State private var isLoading = false
    @State private var showingFilters = false
    @State private var filters = SearchFilters()
    @State private var showingAISearch = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Header
                searchHeader
                
                // Results
                if isLoading {
                    loadingView
                } else if properties.isEmpty && !searchText.isEmpty {
                    emptyStateView
                } else {
                    resultsView
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAISearch = true
                    }) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterView(filters: $filters, onApply: {
                    Task {
                        await searchProperties()
                    }
                })
            }
            .sheet(isPresented: $showingAISearch) {
                AISearchView()
            }
        }
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        VStack(spacing: 12) {
            HStack {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search properties...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            Task {
                                await searchProperties()
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            properties = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Filter Button
                Button(action: {
                    showingFilters = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Active Filters
            if hasActiveFilters {
                activeFiltersView
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var hasActiveFilters: Bool {
        filters.category != nil || filters.minPrice != nil || filters.maxPrice != nil ||
        filters.bedrooms != nil || filters.bathrooms != nil || filters.location != nil
    }
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let category = filters.category {
                    FilterChip(title: category, onRemove: { filters.category = nil })
                }
                if let minPrice = filters.minPrice {
                    FilterChip(title: "Min $\(Int(minPrice))", onRemove: { filters.minPrice = nil })
                }
                if let maxPrice = filters.maxPrice {
                    FilterChip(title: "Max $\(Int(maxPrice))", onRemove: { filters.maxPrice = nil })
                }
                if let bedrooms = filters.bedrooms {
                    FilterChip(title: "\(bedrooms) bed", onRemove: { filters.bedrooms = nil })
                }
                if let bathrooms = filters.bathrooms {
                    FilterChip(title: "\(bathrooms) bath", onRemove: { filters.bathrooms = nil })
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching properties...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Properties Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Try adjusting your search criteria or filters")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try AI Search") {
                showingAISearch = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(properties) { property in
                    NavigationLink(destination: PropertyDetailView(property: property)) {
                        PropertySearchCard(property: property)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
    
    // MARK: - Search Function
    
    @MainActor
    private func searchProperties() async {
        guard !searchText.isEmpty || hasActiveFilters else { return }
        
        isLoading = true
        
        do {
            var searchFilters = filters
            if !searchText.isEmpty {
                searchFilters.searchQuery = searchText
            }
            
            // Call your existing web search function
            let result = try await WebBridge.shared.callWebFunction(
                "iosListingsAPI.searchListings",
                with: ["searchQuery": searchText, "filters": searchFilters.asDictionary]
            )
            
            if let searchResult = result as? [String: Any],
               let propertiesArray = searchResult["data"] as? [[String: Any]] {
                self.properties = parseProperties(from: propertiesArray)
            }
            
        } catch {
            print("Search error: \(error)")
        }
        
        isLoading = false
    }
    
    private func parseProperties(from array: [[String: Any]]) -> [Property] {
        return array.compactMap { dict in
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let property = try? JSONDecoder().decode(Property.self, from: data) else {
                return nil
            }
            return property
        }
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .clipShape(Capsule())
    }
}

struct PropertySearchCard: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Property Image
            AsyncImage(url: URL(string: property.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(height: 200)
            .clipped()
            
            // Property Details
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(property.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if property.featured == true {
                        Text("FEATURED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(property.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(property.formattedPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    if let bedrooms = property.bedrooms, let bathrooms = property.bathrooms {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "bed.double")
                                    .font(.caption)
                                Text("\(bedrooms)")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "bathtub")
                                    .font(.caption)
                                Text("\(bathrooms)")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                if !property.description.isEmpty {
                    Text(property.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    SearchView()
}