import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedFilters: Set<String> = []
    @State private var showingFilters = false
    
    let availableFilters = ["Studio", "1 Bed", "2 Bed", "3+ Bed", "Furnished", "Pet-Friendly"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Search Header
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Advanced Search")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Find your perfect room with advanced filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // Search Bar
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.headline)
                    .fontWeight(.medium)
                
                TextField("Enter city, neighborhood, or address", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Quick Filters
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Quick Filters")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        selectedFilters.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(availableFilters, id: \.self) { filter in
                        FilterChip(
                            title: filter,
                            isSelected: selectedFilters.contains(filter)
                        ) {
                            if selectedFilters.contains(filter) {
                                selectedFilters.remove(filter)
                            } else {
                                selectedFilters.insert(filter)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Search Button
            VStack(spacing: 12) {
                Button(action: {
                    // TODO: Implement search functionality
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search Properties")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button("More Filters") {
                    showingFilters = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFilters) {
            AdvancedFiltersSheet()
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
                .cornerRadius(20)
        }
    }
}

struct AdvancedFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var minPrice = 500.0
    @State private var maxPrice = 3000.0
    @State private var selectedAmenities: Set<String> = []
    
    let amenities = ["WiFi", "Parking", "Laundry", "Gym", "Pool", "Balcony", "Air Conditioning", "Dishwasher"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Advanced Filters")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Price Range
                VStack(alignment: .leading, spacing: 8) {
                    Text("Price Range")
                        .font(.headline)
                    
                    HStack {
                        Text("$\(Int(minPrice))")
                        Spacer()
                        Text("$\(Int(maxPrice))")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    // Note: RangeSlider would need a custom implementation
                    Text("Price range slider coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Amenities
                VStack(alignment: .leading, spacing: 12) {
                    Text("Amenities")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(amenities, id: \.self) { amenity in
                            FilterChip(
                                title: amenity,
                                isSelected: selectedAmenities.contains(amenity)
                            ) {
                                if selectedAmenities.contains(amenity) {
                                    selectedAmenities.remove(amenity)
                                } else {
                                    selectedAmenities.insert(amenity)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Apply Button
                Button("Apply Filters") {
                    // TODO: Apply filters
                    dismiss()
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SearchView()
    }
}