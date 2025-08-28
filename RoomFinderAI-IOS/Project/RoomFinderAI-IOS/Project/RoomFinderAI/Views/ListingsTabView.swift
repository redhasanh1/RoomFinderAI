import SwiftUI

struct ListingsTabView: View {
    @EnvironmentObject private var listingsViewModel: ListingsViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status Bar
                if listingsViewModel.isRealtimeConnected {
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Real-time connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                }
                
                // Main Content
                if listingsViewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading listings...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = listingsViewModel.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Connection Error")
                            .font(.headline)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            Task {
                                await listingsViewModel.testConnection()
                                await listingsViewModel.loadListings()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if listingsViewModel.listings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "house")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Listings Found")
                            .font(.headline)
                        
                        Text("There are no listings available at the moment.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Refresh") {
                            Task {
                                await listingsViewModel.loadListings()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Listings List
                    List(listingsViewModel.listings) { listing in
                        ListingRowView(listing: listing)
                    }
                    .refreshable {
                        await listingsViewModel.loadListings()
                    }
                }
            }
            .navigationTitle("Listings (\(listingsViewModel.listings.count))")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh") {
                            Task {
                                await listingsViewModel.loadListings()
                            }
                        }
                        
                        Button("Test Connection") {
                            Task {
                                await listingsViewModel.testConnection()
                            }
                        }
                        
                        if listingsViewModel.isRealtimeConnected {
                            Button("Disconnect Realtime") {
                                Task {
                                    await listingsViewModel.disconnectRealtime()
                                }
                            }
                        } else {
                            Button("Connect Realtime") {
                                Task {
                                    await listingsViewModel.connectRealtime()
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

struct ListingRowView: View {
    let listing: Listing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("$\(Int(listing.price))/month")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(listing.houseType)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    
                    Text("\(listing.bedrooms) bed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Image(systemName: "location")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(listing.city), \(listing.street)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("Utilities: \(listing.utilities)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let description = listing.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        ListingsTabView()
    }
    .environmentObject(ListingsViewModel(supabaseClient: .preview))
}