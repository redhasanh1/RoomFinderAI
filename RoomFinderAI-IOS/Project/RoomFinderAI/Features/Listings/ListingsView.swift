import SwiftUI

struct ListingsView: View {
    @EnvironmentObject var listingsViewModel: ListingsViewModel
    @State private var showingFilters = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    TextField("Search listings...", text: $listingsViewModel.searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        showingFilters.toggle()
                    }) {
                        Image(systemName: "line.horizontal.3.decrease.circle")
                            .font(.title2)
                    }
                }
                .padding()
                
                // Listings list
                if listingsViewModel.isLoading {
                    Spacer()
                    ProgressView("Loading listings...")
                    Spacer()
                } else if listingsViewModel.listings.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "house.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No listings found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try adjusting your search criteria")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(listingsViewModel.listings, id: \.id) { listing in
                        NavigationLink(destination: PropertyDetailView(listing: listing)) {
                            ListingCardView(listing: listing)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                if let errorMessage = listingsViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Listings")
            .onAppear {
                listingsViewModel.loadListings()
            }
            .onChange(of: listingsViewModel.searchQuery) { query in
                listingsViewModel.searchListings(query: query)
            }
            .sheet(isPresented: $showingFilters) {
                FiltersView()
            }
        }
    }
}

struct ListingCardView: View {
    let listing: RoomListing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Image placeholder
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 200)
                .cornerRadius(10)
                .overlay(
                    Image(systemName: "house")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(listing.title)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("$\(Int(listing.price))/month")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text(listing.location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(listing.description)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.secondary)
                
                // Amenities
                if !listing.amenities.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(listing.amenities, id: \.self) { amenity in
                                Text(amenity)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}

struct FiltersView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Filters")
                    .font(.title2)
                    .padding()
                
                Text("Filter options coming soon...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    ListingsView()
        .environmentObject(ListingsViewModel())
}