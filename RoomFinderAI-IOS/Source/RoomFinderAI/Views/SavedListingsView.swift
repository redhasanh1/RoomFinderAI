import SwiftUI
import Supabase

struct SavedListingsView: View {
    @StateObject private var savedListingsService: SavedListingsService
    @StateObject private var userStatsService: UserStatsService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingRemoveAlert = false
    @State private var listingToRemove: SavedListing?
    
    init(authService: AuthService, supabaseClient: SupabaseClient) {
        self._savedListingsService = StateObject(wrappedValue: SavedListingsService(client: supabaseClient, authService: authService))
        self._userStatsService = StateObject(wrappedValue: UserStatsService(client: supabaseClient, authService: authService))
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            NavigationView {
                ZStack {
                    if savedListingsService.isLoading {
                        LoadingView(message: "Loading saved listings...")
                    } else if savedListingsService.savedListings.isEmpty {
                        EmptyStateView(
                            icon: "heart.slash",
                            title: "No Saved Listings",
                            subtitle: "You haven't saved any properties yet. Start exploring and save your favorites!",
                            actionTitle: "Browse Listings",
                            action: {
                                dismiss()
                            }
                        )
                    } else {
                        SavedListingsContentView(
                            savedListings: savedListingsService.savedListings,
                            onRemove: { listing in
                                listingToRemove = listing
                                showingRemoveAlert = true
                            }
                        )
                    }
                }
                .navigationTitle("Saved Listings")
                .navigationBarTitleDisplayMode(.large)
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
                                    await savedListingsService.fetchSavedListings()
                                }
                            }
                            
                            if !savedListingsService.savedListings.isEmpty {
                                Button("Clear All", role: .destructive) {
                                    Task {
                                        _ = await savedListingsService.clearAllSavedListings()
                                        await userStatsService.updateSavedListingsCount(0)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
                .refreshable {
                    await savedListingsService.fetchSavedListings()
                }
            }
        }
        .alert("Remove Saved Listing", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let listing = listingToRemove {
                    Task {
                        let success = await savedListingsService.removeFromSaved(listingId: listing.listingId)
                        if success {
                            await userStatsService.updateSavedListingsCount(savedListingsService.savedListingsCount)
                        }
                    }
                }
                listingToRemove = nil
            }
        } message: {
            Text("Are you sure you want to remove this property from your saved listings?")
        }
        .task {
            await savedListingsService.fetchSavedListings()
        }
    }
}

struct SavedListingsContentView: View {
    let savedListings: [SavedListing]
    let onRemove: (SavedListing) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(savedListings) { savedListing in
                    if let listing = savedListing.listing {
                        SavedListingCard(
                            savedListing: savedListing,
                            listing: listing,
                            onRemove: {
                                onRemove(savedListing)
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }
}

struct SavedListingCard: View {
    let savedListing: SavedListing
    let listing: Listing
    let onRemove: () -> Void
    
    @State private var showingListingDetail = false
    
    var body: some View {
        GlassmorphismCard {
            VStack(spacing: 0) {
                // Property Image
                AsyncImage(url: URL(string: listing.images?.first ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        )
                }
                .frame(height: 200)
                .clipped()
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            
                            Button(action: onRemove) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                    .padding(8)
                                    .background(Circle().fill(.ultraThinMaterial))
                            }
                        }
                        .padding()
                        
                        Spacer()
                    }
                )
                
                // Property Details
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(listing.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                            
                            Text(listing.city)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("$\(listing.price, specifier: "%.0f")")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("per month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Property Features
                    HStack(spacing: 16) {
                        Label("\(listing.bedrooms)", systemImage: "bed.double")
                        Label("\(listing.utilities)", systemImage: "lightbulb")
                        Label(listing.propertyType.rawValue, systemImage: "house")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    // Saved Date
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        Text("Saved \(savedListing.savedAt, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(16)
            }
        }
        .onTapGesture {
            showingListingDetail = true
        }
        .sheet(isPresented: $showingListingDetail) {
            PropertyDetailView(listing: listing)
        }
    }
}


#Preview {
    SavedListingsView(
        authService: AuthService(supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "key")),
        supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "key")
    )
}