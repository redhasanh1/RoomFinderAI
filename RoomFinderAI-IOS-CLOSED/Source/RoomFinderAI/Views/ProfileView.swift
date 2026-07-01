import SwiftUI
import Supabase

struct ProfileView: View {
    @Environment(\.supabase) private var supabase
    @StateObject private var authService: AuthService
    @State private var showingLogin = false
    @State private var showingSignUp = false
    @State private var showingEditProfile = false
    
    init() {
        // We'll get the supabase client from environment in the body
        self._authService = StateObject(wrappedValue: AuthService(supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://fkktwhjybuflxqzopaex.supabase.co")!, supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs")))
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    if authService.isAuthenticated {
                        AuthenticatedProfileView(authService: authService, showingEditProfile: $showingEditProfile)
                    } else {
                        UnauthenticatedProfileView(
                            showingLogin: $showingLogin,
                            showingSignUp: $showingSignUp
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showingLogin) {
            LoginView(authService: authService)
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView(authService: authService)
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(authService: authService)
        }
        .onAppear {
            // Update auth service with the environment supabase client
            authService.updateClient(supabase)
        }
    }
}

// MARK: - Animated Background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.4, green: 0.5, blue: 0.92),  // #667eea
                Color(red: 0.46, green: 0.29, blue: 0.64), // #764ba2
                Color(red: 0.56, green: 0.27, blue: 0.68), // #8e44ad
                Color(red: 0.23, green: 0.65, blue: 0.84)  // #3498db
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 8)
                    .repeatForever(autoreverses: true)
            ) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Authenticated Profile View
struct AuthenticatedProfileView: View {
    @ObservedObject var authService: AuthService
    @Binding var showingEditProfile: Bool
    @State private var isRotating = false
    @StateObject private var userStatsService: UserStatsService
    @State private var showingSavedListings = false
    @State private var showingSearchHistory = false
    @State private var showingNotifications = false
    @State private var showingSettings = false
    
    init(authService: AuthService, showingEditProfile: Binding<Bool>) {
        self.authService = authService
        self._showingEditProfile = showingEditProfile
        
        // Create UserStatsService with proper Supabase client
        let supabaseClient = SupabaseClient(
            supabaseURL: URL(string: "https://fkktwhjybuflxqzopaex.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"
        )
        self._userStatsService = StateObject(wrappedValue: UserStatsService(client: supabaseClient, authService: authService))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Profile Header Card
            GlassmorphismCard {
                VStack(spacing: 20) {
                    // Profile Image with Rotating Border
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.purple, .pink, .blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 154, height: 154)
                            .rotationEffect(.degrees(isRotating ? 360 : 0))
                            .animation(
                                Animation.linear(duration: 3)
                                    .repeatForever(autoreverses: false),
                                value: isRotating
                            )
                        
                        AsyncImage(url: URL(string: authService.currentUser?.profileImage ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                    }
                    .onAppear {
                        isRotating = true
                    }
                    
                    // User Info
                    VStack(spacing: 8) {
                        Text(authService.currentUser?.fullName ?? "User")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(authService.currentUser?.email ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Verified Account")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Edit Profile Button
                    Button(action: {
                        showingEditProfile = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Profile")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                    }
                }
                .padding(24)
            }
            
            // Stats Cards - Now showing real data
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ProfileStatCard(
                    title: "Listings", 
                    value: "\(userStatsService.userStats?.listingsCount ?? 0)", 
                    icon: "house.fill", 
                    color: .blue
                )
                ProfileStatCard(
                    title: "Favorites", 
                    value: "\(userStatsService.userStats?.savedListingsCount ?? 0)", 
                    icon: "heart.fill", 
                    color: .red
                )
                ProfileStatCard(
                    title: "Messages", 
                    value: "\(userStatsService.userStats?.messagesCount ?? 0)", 
                    icon: "message.fill", 
                    color: .green
                )
                ProfileStatCard(
                    title: "Reviews", 
                    value: "\(userStatsService.userStats?.reviewsCount ?? 0)", 
                    icon: "star.fill", 
                    color: .orange
                )
            }
            
            // Menu Items - Now with real navigation
            GlassmorphismCard {
                VStack(spacing: 0) {
                    ProfileMenuItem(
                        icon: "heart.fill",
                        title: "Saved Listings",
                        subtitle: "Your favorite properties",
                        action: { 
                            showingSavedListings = true
                        }
                    )
                    
                    Divider().padding(.horizontal, 20)
                    
                    ProfileMenuItem(
                        icon: "clock.fill",
                        title: "Search History",
                        subtitle: "Recent searches",
                        action: { 
                            showingSearchHistory = true
                        }
                    )
                    
                    Divider().padding(.horizontal, 20)
                    
                    ProfileMenuItem(
                        icon: "bell.fill",
                        title: "Notifications",
                        subtitle: "Manage alerts",
                        action: { 
                            showingNotifications = true
                        }
                    )
                    
                    Divider().padding(.horizontal, 20)
                    
                    ProfileMenuItem(
                        icon: "gearshape.fill",
                        title: "Settings",
                        subtitle: "App preferences",
                        action: { 
                            showingSettings = true
                        }
                    )
                }
                .padding(.vertical, 12)
            }
            
            // Sign Out Button
            Button(action: {
                Task {
                    try? await authService.signOut()
                }
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            Spacer(minLength: 40)
        }
        .sheet(isPresented: $showingSavedListings) {
            SavedListingsView(
                authService: authService,
                supabaseClient: SupabaseClient(
                    supabaseURL: URL(string: "https://fkktwhjybuflxqzopaex.supabase.co")!,
                    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"
                )
            )
        }
        .sheet(isPresented: $showingSearchHistory) {
            SearchHistoryView(
                authService: authService,
                supabaseClient: SupabaseClient(
                    supabaseURL: URL(string: "https://fkktwhjybuflxqzopaex.supabase.co")!,
                    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"
                )
            )
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView(
                authService: authService,
                supabaseClient: SupabaseClient(
                    supabaseURL: URL(string: "https://fkktwhjybuflxqzopaex.supabase.co")!,
                    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"
                )
            )
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                authService: authService,
                supabaseClient: SupabaseClient(
                    supabaseURL: URL(string: "https://fkktwhjybuflxqzopaex.supabase.co")!,
                    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"
                )
            )
        }
        .task {
            // Load user statistics when the profile view appears
            await userStatsService.fetchUserStats()
        }
        .refreshable {
            // Allow pull-to-refresh to update statistics
            await userStatsService.refreshStats()
        }
    }
}

// MARK: - Unauthenticated Profile View
struct UnauthenticatedProfileView: View {
    @Binding var showingLogin: Bool
    @Binding var showingSignUp: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Welcome Card
            GlassmorphismCard {
                VStack(spacing: 24) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        Text("Welcome to RoomFinder AI")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Sign in to access your profile, save favorites, and get personalized recommendations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 16) {
                        // Sign In Button
                        Button(action: {
                            showingLogin = true
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        
                        // Sign Up Button
                        Button(action: {
                            showingSignUp = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Create Account")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                                    .background(Color.clear)
                            )
                        }
                    }
                }
                .padding(24)
            }
            
            Spacer()
        }
    }
}

// MARK: - Supporting Views
struct GlassmorphismCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        GlassmorphismCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
    }
}

struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Extensions
extension AuthService {
    func updateClient(_ newClient: SupabaseClient) {
        // This would need to be implemented in AuthService to update the client
        // For now, we'll work with the initialization approach
    }
}

extension User {
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        if first.isEmpty && last.isEmpty {
            return "User"
        }
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    ProfileView()
}