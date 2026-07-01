import SwiftUI
import Supabase

struct NewListingsView: View {
    @StateObject private var viewModel: ListingsViewModel
    @State private var showingFilters = false
    @State private var selectedListing: Listing?
    @State private var showingPropertyDetail = false
    @State private var searchText = ""
    
    init(supabaseClient: SupabaseClient) {
        _viewModel = StateObject(wrappedValue: ListingsViewModel(supabaseClient: supabaseClient))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Header
                VStack(spacing: 12) {
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search listings...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .onSubmit {
                                    Task {
                                        var newFilters = viewModel.filters
                                        newFilters.search = searchText.isEmpty ? nil : searchText
                                        await viewModel.apply(filters: newFilters)
                                    }
                                }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        Button(action: {
                            showingFilters = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .overlay(
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                                .opacity(!viewModel.filters.isEmpty ? 1 : 0)
                        )
                    }
                    
                    // Active Filter Chips
                    if !viewModel.filters.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if let city = viewModel.filters.city, !city.isEmpty {
                                    FilterChip(text: city) {
                                        Task {
                                            var newFilters = viewModel.filters
                                            newFilters.city = nil
                                            await viewModel.apply(filters: newFilters)
                                        }
                                    }
                                }
                                
                                if let houseType = viewModel.filters.houseType {
                                    FilterChip(text: houseType) {
                                        Task {
                                            var newFilters = viewModel.filters
                                            newFilters.houseType = nil
                                            await viewModel.apply(filters: newFilters)
                                        }
                                    }
                                }
                                
                                if let bedrooms = viewModel.filters.bedrooms {
                                    FilterChip(text: "\(bedrooms) BR") {
                                        Task {
                                            var newFilters = viewModel.filters
                                            newFilters.bedrooms = nil
                                            await viewModel.apply(filters: newFilters)
                                        }
                                    }
                                }
                                
                                if viewModel.filters.minPrice != nil || viewModel.filters.maxPrice != nil {
                                    let minPrice = viewModel.filters.minPrice ?? 0
                                    let maxPrice = viewModel.filters.maxPrice ?? 5000
                                    FilterChip(text: "$\(minPrice)-$\(maxPrice)") {
                                        Task {
                                            var newFilters = viewModel.filters
                                            newFilters.minPrice = nil
                                            newFilters.maxPrice = nil
                                            await viewModel.apply(filters: newFilters)
                                        }
                                    }
                                }
                                
                                Button("Clear All") {
                                    Task {
                                        await viewModel.apply(filters: .empty)
                                        searchText = ""
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Results Count
                HStack {
                    Text("\(viewModel.listings.count) listings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Content
                if viewModel.isLoading && viewModel.listings.isEmpty {
                    Spacer()
                    ProgressView("Loading listings...")
                        .scaleEffect(1.2)
                    Spacer()
                } else if viewModel.listings.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("No listings found")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Try adjusting your filters or search terms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Refresh") {
                            Task {
                                await viewModel.refresh()
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.listings) { listing in
                                ListingCardNew(
                                    listing: listing,
                                    onTap: {
                                        selectedListing = listing
                                        showingPropertyDetail = true
                                    }
                                )
                                .onAppear {
                                    // Load more when approaching the end
                                    if listing.id == viewModel.listings.last?.id && viewModel.hasMorePages {
                                        Task {
                                            await viewModel.loadMore()
                                        }
                                    }
                                }
                            }
                            
                            // Loading More Indicator
                            if viewModel.isLoadingMore {
                                ProgressView("Loading more...")
                                    .padding()
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                }
            }
            .navigationTitle("Listings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingFilters) {
                NewFiltersView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingPropertyDetail) {
                if let listing = selectedListing {
                    PropertyDetailView(listing: listing)
                }
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { viewModel.error != nil },
                set: { _ in viewModel.error = nil }
            )) {
                Button("OK") {
                    viewModel.error = nil
                }
                Button("Retry") {
                    Task {
                        await viewModel.refresh()
                    }
                }
            } message: {
                Text(viewModel.error ?? "An error occurred")
            }
            .task {
                await viewModel.loadInitial()
            }
        }
    }
}

struct ListingCardNew: View {
    let listing: Listing
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Image
                AsyncImage(url: URL(string: listing.images?.first ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(.secondary.opacity(0.3))
                        .overlay(
                            Image(systemName: "house")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        )
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(listing.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Text("$\(listing.price)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Label(listing.city, systemImage: "location")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Label("\(listing.bedrooms)", systemImage: "bed.double")
                            Label(listing.houseType, systemImage: "house")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    if let description = listing.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NewFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ListingsViewModel
    
    @State private var tempCity = ""
    @State private var tempMinPrice: Int?
    @State private var tempMaxPrice: Int?
    @State private var tempBedrooms: Int?
    @State private var tempHouseType = ""
    
    private let houseTypes = ["", "House", "Apartment", "Condo", "Townhouse"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Location") {
                    TextField("City", text: $tempCity)
                }
                
                Section("Price Range") {
                    HStack {
                        TextField("Min Price", value: $tempMinPrice, format: .number)
                            .keyboardType(.numberPad)
                        Text("-")
                        TextField("Max Price", value: $tempMaxPrice, format: .number)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section("Property Type") {
                    Picker("House Type", selection: $tempHouseType) {
                        Text("Any").tag("")
                        ForEach(houseTypes.dropFirst(), id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Bedrooms") {
                    Picker("Bedrooms", selection: $tempBedrooms) {
                        Text("Any").tag(nil as Int?)
                        ForEach(1...5, id: \.self) { bedroom in
                            Text("\(bedroom)").tag(bedroom as Int?)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        resetFilters()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentFilters()
            }
        }
    }
    
    private func loadCurrentFilters() {
        tempCity = viewModel.filters.city ?? ""
        tempMinPrice = viewModel.filters.minPrice
        tempMaxPrice = viewModel.filters.maxPrice
        tempBedrooms = viewModel.filters.bedrooms
        tempHouseType = viewModel.filters.houseType ?? ""
    }
    
    private func applyFilters() {
        Task {
            let newFilters = ListingsFilter(
                city: tempCity.isEmpty ? nil : tempCity,
                maxPrice: tempMaxPrice,
                minPrice: tempMinPrice,
                houseType: tempHouseType.isEmpty ? nil : tempHouseType,
                bedrooms: tempBedrooms
            )
            await viewModel.apply(filters: newFilters)
        }
    }
    
    private func resetFilters() {
        tempCity = ""
        tempMinPrice = nil
        tempMaxPrice = nil
        tempBedrooms = nil
        tempHouseType = ""
    }
}

struct FilterChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    NewListingsView(supabaseClient: .preview)
}