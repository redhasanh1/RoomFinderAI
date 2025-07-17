import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var listingsViewModel: ListingsViewModel
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var showingProfile = false
    @State private var showingAIChat = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back,")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(authViewModel.currentUser?.name ?? "User")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingProfile = true
                        }) {
                            AsyncImage(url: URL(string: authViewModel.currentUser?.avatar ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Quick Actions
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        QuickActionCard(
                            title: "AI Assistant",
                            subtitle: "Get personalized help",
                            icon: "brain.head.profile",
                            color: .primaryBlue
                        ) {
                            showingAIChat = true
                        }
                        
                        QuickActionCard(
                            title: "Search Rooms",
                            subtitle: "Find your perfect match",
                            icon: "magnifyingglass",
                            color: .accentGreen
                        ) {
                            // Navigate to search
                        }
                        
                        QuickActionCard(
                            title: "Messages",
                            subtitle: "\(chatViewModel.totalUnreadCount) unread",
                            icon: "message.fill",
                            color: .secondaryPurple
                        ) {
                            // Navigate to messages
                        }
                        
                        QuickActionCard(
                            title: "Favorites",
                            subtitle: "\(listingsViewModel.favoriteListings.count) saved",
                            icon: "heart.fill",
                            color: .red
                        ) {
                            // Navigate to favorites
                        }
                    }
                    .padding(.horizontal)
                    
                    // Recent Activity
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Recent Activity")
                        
                        if listingsViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(recentActivities, id: \.id) { activity in
                                    ActivityCard(activity: activity)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Featured Listings
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Featured Listings")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: [GridItem(.flexible())], spacing: 16) {
                                ForEach(listingsViewModel.featuredListings) { listing in
                                    FeaturedListingCard(listing: listing)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Stats Overview
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Your Stats")
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            StatCard(title: "Searches", value: "24", icon: "magnifyingglass")
                            StatCard(title: "Favorites", value: "\(listingsViewModel.favoriteListings.count)", icon: "heart.fill")
                            StatCard(title: "Messages", value: "\(chatViewModel.chats.count)", icon: "message.fill")
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            .navigationBarHidden(true)
            .refreshable {
                await refreshDashboard()
            }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showingAIChat) {
            AIChatsView()
        }
        .onAppear {
            loadDashboardData()
        }
    }
    
    private func loadDashboardData() {
        Task {
            await listingsViewModel.loadInitialData()
            await chatViewModel.loadInitialData()
        }
    }
    
    private func refreshDashboard() async {
        await listingsViewModel.loadInitialData()
        await chatViewModel.refreshChats()
    }
    
    private var recentActivities: [RecentActivity] {
        // Mock recent activities - in a real app, this would come from the backend
        return [
            RecentActivity(
                id: "1",
                type: .search,
                title: "Searched for apartments in Downtown",
                subtitle: "Found 15 matches",
                timestamp: Date().addingTimeInterval(-3600),
                icon: "magnifyingglass"
            ),
            RecentActivity(
                id: "2",
                type: .favorite,
                title: "Saved Modern Studio Apartment",
                subtitle: "$1,200/month",
                timestamp: Date().addingTimeInterval(-7200),
                icon: "heart.fill"
            ),
            RecentActivity(
                id: "3",
                type: .message,
                title: "New message from John Doe",
                subtitle: "About 2BR apartment inquiry",
                timestamp: Date().addingTimeInterval(-10800),
                icon: "message.fill"
            )
        ]
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button("See All") {
                // Navigate to full view
            }
            .font(.subheadline)
            .foregroundColor(.primaryBlue)
        }
    }
}

struct ActivityCard: View {
    let activity: RecentActivity
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .foregroundColor(.primaryBlue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(activity.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(activity.timestamp.timeAgoDisplay())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FeaturedListingCard: View {
    let listing: Listing
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: listing.images.first ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .foregroundColor(.secondary.opacity(0.3))
            }
            .frame(width: 200, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text(listing.price.currencyFormatted())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBlue)
                
                HStack {
                    Label("\(listing.bedrooms)", systemImage: "bed.double")
                    Label("\(listing.bathrooms)", systemImage: "drop")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 200)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.primaryBlue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AIChatsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                Text("AI Assistant")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Start a conversation with our AI assistant to get personalized help finding your perfect room.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button("Start New Chat") {
                    chatViewModel.createNewAIChat()
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.primaryBlue)
                .cornerRadius(12)
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

struct RecentActivity: Identifiable {
    let id: String
    let type: ActivityType
    let title: String
    let subtitle: String
    let timestamp: Date
    let icon: String
}

enum ActivityType {
    case search
    case favorite
    case message
    case viewListing
}

#Preview {
    DashboardView()
        .environmentObject(AuthViewModel())
        .environmentObject(ListingsViewModel())
        .environmentObject(ChatViewModel())
}