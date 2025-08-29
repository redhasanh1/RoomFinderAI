import SwiftUI
import Supabase

struct DashboardView: View {
    @EnvironmentObject var authViewModel: SimpleAuthViewModel
    @EnvironmentObject var listingsViewModel: SimpleListingsViewModel
    @State private var showingProfile = false
    @State private var showingAIChat = false
    @State private var showingMarketAnalytics = false
    @State private var showingMortgageCalculator = false
    @State private var showingSubleaseView = false
    @State private var showingPaymentView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authViewModel.isAuthenticated ? "Welcome back," : "Welcome,")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(authViewModel.isAuthenticated ? (authViewModel.currentUser?.name ?? "User") : "Guest")
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
                            subtitle: "Coming soon",
                            icon: "message.fill",
                            color: .purple
                        ) {
                            // Navigate to messages - Coming soon
                        }
                        
                        QuickActionCard(
                            title: "Favorites",
                            subtitle: "Your saved listings",
                            icon: "heart.fill",
                            color: .red
                        ) {
                            // Navigate to favorites
                        }
                    }
                    .padding(.horizontal)
                    
                    // Premium Features
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Premium Features")
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            PremiumFeatureCard(
                                title: "Market Analytics",
                                subtitle: "Track market trends",
                                icon: "chart.line.uptrend.xyaxis",
                                color: .blue,
                                isPremium: true
                            ) {
                                showingMarketAnalytics = true
                            }
                            
                            PremiumFeatureCard(
                                title: "Mortgage Calculator",
                                subtitle: "Calculate affordability",
                                icon: "calculator",
                                color: .green,
                                isPremium: false
                            ) {
                                showingMortgageCalculator = true
                            }
                            
                            PremiumFeatureCard(
                                title: "Sublease",
                                subtitle: "Find sublease options",
                                icon: "house.and.flag",
                                color: .orange,
                                isPremium: false
                            ) {
                                showingSubleaseView = true
                            }
                            
                            PremiumFeatureCard(
                                title: "Subscription",
                                subtitle: "Manage your plan",
                                icon: "creditcard",
                                color: .purple,
                                isPremium: true
                            ) {
                                showingPaymentView = true
                            }
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
                            StatCard(title: "Messages", value: "0", icon: "message.fill")
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
        .sheet(isPresented: $showingMarketAnalytics) {
            SimpleFeatureView(title: "Market Analytics", subtitle: "Coming soon...")
        }
        .sheet(isPresented: $showingMortgageCalculator) {
            SimpleFeatureView(title: "Mortgage Calculator", subtitle: "Coming soon...")
        }
        .sheet(isPresented: $showingSubleaseView) {
            SubleaseView()
        }
        .sheet(isPresented: $showingPaymentView) {
            SimpleFeatureView(title: "Payment & Subscription", subtitle: "Coming soon...")
        }
        .onAppear {
            loadDashboardData()
        }
    }
    
    private func loadDashboardData() {
        // Load dashboard data - simplified for demo
        listingsViewModel.loadListings()
    }
    
    private func refreshDashboard() async {
        // Refresh dashboard data - simplified for demo
        listingsViewModel.refreshListings()
    }
    
    private var recentActivities: [RecentActivity] {
        // TODO: Replace with real recent activities from database
        return []
    }
}

// Component definitions moved to SharedComponents.swift

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

// FeaturedListingCard moved to RoomFinderAIApp.swift to avoid duplication

// Duplicate components removed - using SharedComponents.swift

struct AIChatsView: View {
    @Environment(\.dismiss) private var dismiss
    // Chat functionality removed for simplified app
    
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
                    // Chat functionality coming soon
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

// Simple feature view for placeholder screens
struct SimpleFeatureView: View {
    let title: String
    let subtitle: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "hammer.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.primaryBlue)
                
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button("Close") {
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

// MARK: - Views are now in separate files

#Preview {
    DashboardView()
        .environmentObject(SimpleAuthViewModel())
        .environmentObject(SimpleListingsViewModel.preview)
}
