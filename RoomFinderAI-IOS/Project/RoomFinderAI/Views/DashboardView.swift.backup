import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var listingsViewModel: ListingsViewModel
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Welcome back!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let user = authViewModel.currentUser {
                            Text("Hello, \(user.email)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    
                    // Quick stats
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 15) {
                        StatCard(title: "Available Rooms", value: "\(listingsViewModel.listings.count)", color: .blue)
                        StatCard(title: "AI Conversations", value: "\(chatViewModel.messages.count)", color: .green)
                    }
                    .padding(.horizontal)
                    
                    // Recent listings
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recent Listings")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if listingsViewModel.listings.isEmpty {
                            Text("No listings available")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(listingsViewModel.listings.prefix(3)), id: \.id) { listing in
                                    ListingRowView(listing: listing)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("Dashboard")
            .onAppear {
                listingsViewModel.loadListings()
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ListingRowView: View {
    let listing: RoomListing
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(listing.title)
                    .font(.headline)
                
                Text(listing.location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(Int(listing.price))")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthViewModel())
        .environmentObject(ListingsViewModel())
        .environmentObject(ChatViewModel())
}