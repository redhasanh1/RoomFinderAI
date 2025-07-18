import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var listingsViewModel: ListingsViewModel
    @EnvironmentObject var chatViewModel: ChatViewModel
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
                                color: .blue
                            ) {
                                showingMarketAnalytics = true
                            }
                            
                            PremiumFeatureCard(
                                title: "Mortgage Calculator",
                                subtitle: "Calculate affordability",
                                icon: "calculator",
                                color: .green
                            ) {
                                showingMortgageCalculator = true
                            }
                            
                            PremiumFeatureCard(
                                title: "Sublease",
                                subtitle: "Find sublease options",
                                icon: "house.and.flag",
                                color: .orange
                            ) {
                                showingSubleaseView = true
                            }
                            
                            PremiumFeatureCard(
                                title: "Subscription",
                                subtitle: "Manage your plan",
                                icon: "creditcard",
                                color: .purple
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
        .sheet(isPresented: $showingMarketAnalytics) {
            MarketAnalyticsView()
        }
        .sheet(isPresented: $showingMortgageCalculator) {
            MortgageCalculatorView()
        }
        .sheet(isPresented: $showingSubleaseView) {
            SubleaseView()
        }
        .sheet(isPresented: $showingPaymentView) {
            PaymentView()
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
                
                Text("$\(listing.price)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBlue)
                
                HStack {
                    Label("\(listing.bedrooms)", systemImage: "bed.double")
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

struct PremiumFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.1), color.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Temporary Views (Until added to Xcode project)

struct MarketAnalyticsView: View {
    @StateObject private var marketService = MarketAnalyticsService.shared
    @State private var selectedCity = "Toronto"
    @State private var marketOverview: MarketOverview?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Market Analytics")
                    .font(.title)
                    .fontWeight(.bold)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let overview = marketOverview {
                    VStack(spacing: 16) {
                        Text("Average Price: $\(overview.averagePrice)")
                            .font(.headline)
                        
                        Text("Total Listings: \(overview.totalListings)")
                            .font(.subheadline)
                        
                        Text("Market Score: \(overview.marketScore)/100")
                            .font(.subheadline)
                            .foregroundColor(.primaryBlue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else {
                    Text("No market data available")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadMarketData()
        }
    }
    
    private func loadMarketData() {
        Task {
            do {
                let overview = try await marketService.getMarketOverview(for: selectedCity)
                await MainActor.run {
                    marketOverview = overview
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct MortgageCalculatorView: View {
    @StateObject private var mortgageService = MortgageCalculatorService.shared
    @State private var homePrice = ""
    @State private var downPayment = ""
    @State private var interestRate = ""
    @State private var mortgageResult: MortgageResult?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Mortgage Calculator")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 16) {
                        TextField("Home Price", text: $homePrice)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        TextField("Down Payment", text: $downPayment)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        TextField("Interest Rate (%)", text: $interestRate)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                        
                        Button("Calculate") {
                            calculateMortgage()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primaryBlue)
                        .cornerRadius(12)
                        .disabled(!canCalculate)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    if let result = mortgageResult {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Results")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("Monthly Payment: \(result.monthlyPayment.currencyFormatted())")
                            Text("Total Interest: \(result.totalInterest.currencyFormatted())")
                            Text("Total Cost: \(result.totalCost.currencyFormatted())")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var canCalculate: Bool {
        !homePrice.isEmpty && !downPayment.isEmpty && !interestRate.isEmpty
    }
    
    private func calculateMortgage() {
        guard let homePriceValue = Double(homePrice.replacingOccurrences(of: ",", with: "")),
              let downPaymentValue = Double(downPayment.replacingOccurrences(of: ",", with: "")),
              let interestRateValue = Double(interestRate) else {
            return
        }
        
        mortgageResult = mortgageService.calculateMortgage(
            homePrice: homePriceValue,
            downPayment: downPaymentValue,
            interestRate: interestRateValue,
            loanTerm: 30
        )
    }
}

struct SubleaseView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Sublease Marketplace")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Find short-term sublease opportunities")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 16) {
                        FeatureCard(
                            icon: "calendar",
                            title: "Flexible Terms",
                            description: "Find sublets for any duration"
                        )
                        
                        FeatureCard(
                            icon: "dollarsign.circle",
                            title: "Competitive Pricing",
                            description: "Often below market rates"
                        )
                        
                        FeatureCard(
                            icon: "checkmark.shield",
                            title: "Verified Listings",
                            description: "All listings are verified"
                        )
                    }
                    
                    Button("Browse Subleases") {
                        // Action
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primaryBlue)
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PaymentView: View {
    @StateObject private var stripeService = StripeService.shared
    @State private var selectedPlan: SubscriptionPlan?
    
    let plans = StripeService.shared.getSubscriptionPlans()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Choose Your Plan")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Unlock powerful features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 16) {
                        ForEach(plans, id: \.id) { plan in
                            Button(action: {
                                selectedPlan = plan
                            }) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(plan.name)
                                            .font(.headline)
                                            .fontWeight(.bold)
                                        
                                        Spacer()
                                        
                                        Text("$\(plan.price, specifier: "%.2f")/month")
                                            .font(.headline)
                                            .foregroundColor(.primaryBlue)
                                    }
                                    
                                    ForEach(plan.features, id: \.self) { feature in
                                        HStack {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                            Text(feature)
                                                .font(.subheadline)
                                        }
                                    }
                                }
                                .padding()
                                .background(selectedPlan?.id == plan.id ? Color.primaryBlue.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedPlan?.id == plan.id ? Color.primaryBlue : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    if let selectedPlan = selectedPlan {
                        Button("Subscribe to \(selectedPlan.name)") {
                            // Action
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primaryBlue)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.primaryBlue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthViewModel())
        .environmentObject(ListingsViewModel())
        .environmentObject(ChatViewModel())
}