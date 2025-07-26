import SwiftUI

struct ListingsView: View {
    @EnvironmentObject var listingsViewModel: SimpleListingsViewModel
    @State private var showingFilters = false
    @State private var selectedListing: Listing?
    @State private var showingPropertyDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Header
                VStack(spacing: 12) {
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search listings...", text: $listingsViewModel.searchQuery)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        Button(action: {
                            showingFilters = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title2)
                                .foregroundColor(.primaryBlue)
                        }
                        .padding(.horizontal, 4)
                        .overlay(
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                                .opacity(listingsViewModel.hasActiveFilters ? 1 : 0)
                        )
                    }
                    
                    // Filter Chips
                    if listingsViewModel.hasActiveFilters {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if !listingsViewModel.selectedLocation.isEmpty {
                                    FilterChip(text: listingsViewModel.selectedLocation) {
                                        listingsViewModel.selectedLocation = ""
                                    }
                                }
                                
                                if listingsViewModel.selectedPropertyType != nil {
                                    FilterChip(text: listingsViewModel.selectedPropertyType?.displayName ?? "") {
                                        listingsViewModel.selectedPropertyType = nil
                                    }
                                }
                                
                                if listingsViewModel.selectedBedrooms != nil {
                                    FilterChip(text: "\(listingsViewModel.selectedBedrooms!)BR") {
                                        listingsViewModel.selectedBedrooms = nil
                                    }
                                }
                                
                                if listingsViewModel.minPrice > 0 || listingsViewModel.maxPrice < 5000 {
                                    FilterChip(text: "\(Int(listingsViewModel.minPrice))-\(Int(listingsViewModel.maxPrice))") {
                                        listingsViewModel.minPrice = 0
                                        listingsViewModel.maxPrice = 5000
                                    }
                                }
                                
                                Button("Clear All") {
                                    listingsViewModel.clearFilters()
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
                
                // Sort Options
                HStack {
                    Text("\(listingsViewModel.filteredListingsCount) listings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: {
                                listingsViewModel.sortBy = option
                            }) {
                                HStack {
                                    Text(option.displayName)
                                    if listingsViewModel.sortBy == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Sort: \(listingsViewModel.sortBy.displayName)")
                            Image(systemName: "chevron.down")
                        }
                        .font(.subheadline)
                        .foregroundColor(.primaryBlue)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Listings List
                if listingsViewModel.isLoading && listingsViewModel.listings.isEmpty {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if listingsViewModel.listings.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        // Debug Information - Simplified
                        DebugInfoView(viewModel: listingsViewModel)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            EmptyStateView(
                                icon: "magnifyingglass",
                                title: "No listings found",
                                subtitle: "Debug info above shows connection details",
                                actionTitle: "Retry",
                                action: {
                                    listingsViewModel.refreshListings()
                                }
                            )
                            
                            // Create Sample Data Button (only show if count is 0)
                            if listingsViewModel.listingsCount == 0 {
                                Button(action: {
                                    listingsViewModel.createSampleData()
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Create Sample Data")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.green)
                                    .cornerRadius(20)
                                }
                                .disabled(listingsViewModel.isLoading)
                            }
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(listingsViewModel.listings) { listing in
                                ListingCard(
                                    listing: listing,
                                    onTap: {
                                        selectedListing = listing
                                        showingPropertyDetail = true
                                    },
                                    onFavorite: {
                                        listingsViewModel.toggleFavorite(listing: listing)
                                    }
                                )
                            }
                            
                            // Load More Button
                            if listingsViewModel.hasNextPage {
                                Button("Load More") {
                                    listingsViewModel.loadNextPage()
                                }
                                .font(.subheadline)
                                .foregroundColor(.primaryBlue)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            // Loading indicator for pagination
                            if listingsViewModel.isLoading && !listingsViewModel.listings.isEmpty {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        listingsViewModel.refreshListings()
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingFilters) {
                FiltersView()
            }
            .sheet(isPresented: $showingPropertyDetail) {
                if let listing = selectedListing {
                    PropertyDetailView(listing: listing)
                }
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { listingsViewModel.hasError },
                set: { _ in listingsViewModel.clearError() }
            )) {
                Button("OK") {
                    listingsViewModel.clearError()
                }
            } message: {
                Text(listingsViewModel.errorMessage ?? "An error occurred")
            }
        }
    }
}

struct ListingCard: View {
    let listing: Listing
    let onTap: () -> Void
    let onFavorite: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Image
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: listing.images.first ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Favorite Button
                    Button(action: onFavorite) {
                        Image(systemName: listing.isFavorited ? "heart.fill" : "heart")
                            .foregroundColor(listing.isFavorited ? .red : .white)
                            .font(.title2)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(12)
                }
                
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
                            .foregroundColor(.primaryBlue)
                    }
                    
                    HStack {
                        Label(listing.location.city, systemImage: "location")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Label("\(listing.bedrooms)", systemImage: "bed.double")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Amenities section removed - no amenities in Listing model
                    
                    // Status and Date section removed - no status/availableDate in Listing model
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

// FilterChip moved to SharedComponents.swift

struct FiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listingsViewModel: SimpleListingsViewModel
    @State private var tempLocation = ""
    @State private var tempMinPrice: Double = 0
    @State private var tempMaxPrice: Double = 5000
    @State private var tempBedrooms: Int?
    @State private var tempBathrooms: Int?
    @State private var tempPropertyType: PropertyType?
    @State private var tempPetFriendly = false
    @State private var tempSmokingAllowed = false
    
    var body: some View {
        NavigationView {
            Form {
                // Location
                Section("Location") {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                        
                        TextField("City, State or ZIP", text: $tempLocation)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                }
                
                // Price Range
                Section("Price Range") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("$\(Int(tempMinPrice))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("$\(Int(tempMaxPrice))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        RangeSlider(
                            minValue: $tempMinPrice,
                            maxValue: $tempMaxPrice,
                            range: 0...5000,
                            step: 50
                        )
                    }
                }
                
                // Bedrooms
                Section("Bedrooms") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<6) { bedroom in
                                Button(action: {
                                    tempBedrooms = bedroom == 0 ? nil : bedroom
                                }) {
                                    Text(bedroom == 0 ? "Any" : "\(bedroom)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(tempBedrooms == bedroom || (bedroom == 0 && tempBedrooms == nil) ? .white : .primaryBlue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(tempBedrooms == bedroom || (bedroom == 0 && tempBedrooms == nil) ? Color.primaryBlue : Color.primaryBlue.opacity(0.1))
                                        .cornerRadius(20)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Bathrooms
                Section("Bathrooms") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<4) { bathroom in
                                Button(action: {
                                    tempBathrooms = bathroom == 0 ? nil : bathroom
                                }) {
                                    Text(bathroom == 0 ? "Any" : "\(bathroom)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(tempBathrooms == bathroom || (bathroom == 0 && tempBathrooms == nil) ? .white : .primaryBlue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(tempBathrooms == bathroom || (bathroom == 0 && tempBathrooms == nil) ? Color.primaryBlue : Color.primaryBlue.opacity(0.1))
                                        .cornerRadius(20)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Property Type
                Section("Property Type") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(PropertyType.allCases, id: \.self) { type in
                            Button(action: {
                                tempPropertyType = tempPropertyType == type ? nil : type
                            }) {
                                HStack {
                                    Image(systemName: type.icon)
                                        .foregroundColor(tempPropertyType == type ? .white : .primaryBlue)
                                    
                                    Text(type.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(tempPropertyType == type ? .white : .primaryBlue)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(tempPropertyType == type ? Color.primaryBlue : Color.primaryBlue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Amenities
                Section("Amenities") {
                    Toggle("Pet Friendly", isOn: $tempPetFriendly)
                    Toggle("Smoking Allowed", isOn: $tempSmokingAllowed)
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
        }
        .onAppear {
            loadCurrentFilters()
        }
    }
    
    private func loadCurrentFilters() {
        tempLocation = listingsViewModel.selectedLocation
        tempMinPrice = listingsViewModel.minPrice
        tempMaxPrice = listingsViewModel.maxPrice
        tempBedrooms = listingsViewModel.selectedBedrooms
        tempBathrooms = listingsViewModel.selectedBathrooms
        tempPropertyType = listingsViewModel.selectedPropertyType
        tempPetFriendly = listingsViewModel.petFriendly
        tempSmokingAllowed = listingsViewModel.smokingAllowed
    }
    
    private func applyFilters() {
        listingsViewModel.selectedLocation = tempLocation
        listingsViewModel.minPrice = tempMinPrice
        listingsViewModel.maxPrice = tempMaxPrice
        listingsViewModel.selectedBedrooms = tempBedrooms
        listingsViewModel.selectedBathrooms = tempBathrooms
        listingsViewModel.selectedPropertyType = tempPropertyType
        listingsViewModel.petFriendly = tempPetFriendly
        listingsViewModel.smokingAllowed = tempSmokingAllowed
    }
    
    private func resetFilters() {
        tempLocation = ""
        tempMinPrice = 0
        tempMaxPrice = 5000
        tempBedrooms = nil
        tempBathrooms = nil
        tempPropertyType = nil
        tempPetFriendly = false
        tempSmokingAllowed = false
    }
}

struct RangeSlider: View {
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Slider(value: $minValue, in: range, step: step)
                    .accentColor(.primaryBlue)
                
                Slider(value: $maxValue, in: range, step: step)
                    .accentColor(.primaryBlue)
            }
        }
        .onChange(of: minValue) { newValue in
            if newValue > maxValue {
                maxValue = newValue
            }
        }
        .onChange(of: maxValue) { newValue in
            if newValue < minValue {
                minValue = newValue
            }
        }
    }
}

// EmptyStateView moved to SharedComponents.swift

#Preview {
    ListingsView()
        .environmentObject(SimpleListingsViewModel())
}