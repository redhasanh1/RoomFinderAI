import SwiftUI

struct ProfileView: View {
    @State private var user: User?
    @State private var subscriptionStatus: SubscriptionStatus?
    @State private var isLoading = true
    @State private var showingSettings = false
    @State private var showingSubscription = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Subscription Status
                    subscriptionSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Menu Items
                    menuSection
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadProfileData()
            }
            .task {
                await loadProfileData()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                if let user = user, let imageUrl = user.profileImage, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Text(user?.displayName.prefix(1).uppercased() ?? "U")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Edit button
                Button(action: {
                    // Edit profile image
                }) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .offset(x: 35, y: 35)
            }
            
            // User Info
            VStack(spacing: 4) {
                Text(user?.displayName ?? "User")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(user?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Subscription Section
    
    private var subscriptionSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subscription")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: subscriptionStatus?.isPremium == true ? "crown.fill" : "person.fill")
                            .foregroundColor(subscriptionStatus?.isPremium == true ? .orange : .blue)
                        
                        Text(subscriptionStatus?.type.capitalized ?? "Free")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(subscriptionStatus?.isActive == true ? "Active" : "Inactive")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingSubscription = true
                }) {
                    Text(subscriptionStatus?.isPremium == true ? "Manage" : "Upgrade")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 12) {
                QuickActionCard(
                    icon: "heart.fill",
                    title: "Favorites",
                    color: .red
                ) {
                    // Navigate to favorites
                }
                
                QuickActionCard(
                    icon: "clock.fill",
                    title: "History",
                    color: .orange
                ) {
                    // Navigate to search history
                }
                
                QuickActionCard(
                    icon: "brain.head.profile",
                    title: "AI Assistant",
                    color: .purple
                ) {
                    // Navigate to AI chat
                }
                
                QuickActionCard(
                    icon: "bell.fill",
                    title: "Alerts",
                    color: .blue
                ) {
                    // Navigate to saved searches/alerts
                }
            }
        }
    }
    
    // MARK: - Menu Section
    
    private var menuSection: some View {
        VStack(spacing: 0) {
            MenuRow(icon: "gearshape.fill", title: "Settings", color: .gray) {
                showingSettings = true
            }
            
            Divider().padding(.leading, 50)
            
            MenuRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .blue) {
                // Navigate to help
            }
            
            Divider().padding(.leading, 50)
            
            MenuRow(icon: "doc.text.fill", title: "Terms & Privacy", color: .green) {
                // Navigate to legal
            }
            
            Divider().padding(.leading, 50)
            
            MenuRow(icon: "star.fill", title: "Rate App", color: .orange) {
                // Request app review
            }
            
            Divider().padding(.leading, 50)
            
            MenuRow(icon: "arrow.right.square.fill", title: "Sign Out", color: .red) {
                signOut()
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Functions
    
    @MainActor
    private func loadProfileData() async {
        isLoading = true
        
        do {
            // Load user profile
            async let userResult = WebBridge.shared.callWebFunction("iosAuthManager.getCurrentUser")
            async let subscriptionResult = WebBridge.shared.callWebFunction("iosPaymentAPI.getSubscriptionStatus")
            
            let (userData, subData) = try await (userResult, subscriptionResult)
            
            // Parse user data
            if let userDict = userData as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: userDict),
               let user = try? JSONDecoder().decode(User.self, from: data) {
                self.user = user
            }
            
            // Parse subscription data
            if let subResult = subData as? [String: Any],
               let subDict = subResult["data"] as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: subDict),
               let subscription = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
                self.subscriptionStatus = subscription
            }
            
        } catch {
            print("Error loading profile data: \(error)")
        }
        
        isLoading = false
    }
    
    private func signOut() {
        Task {
            do {
                _ = try await WebBridge.shared.callWebFunction("iosAuthManager.signOut")
                // Navigate to login screen or handle sign out
            } catch {
                print("Sign out error: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    ProfileView()
}