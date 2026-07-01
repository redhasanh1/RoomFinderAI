import SwiftUI
import Supabase

struct SettingsView: View {
    @ObservedObject var authService: AuthService
    @StateObject private var notificationsService: NotificationsService
    @StateObject private var userStatsService: UserStatsService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingNotificationSettings = false
    @State private var showingPrivacySettings = false
    @State private var showingAbout = false
    @State private var showingSupport = false
    
    init(authService: AuthService, supabaseClient: SupabaseClient) {
        self.authService = authService
        self._notificationsService = StateObject(wrappedValue: NotificationsService(client: supabaseClient, authService: authService))
        self._userStatsService = StateObject(wrappedValue: UserStatsService(client: supabaseClient, authService: authService))
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            NavigationView {
                ScrollView {
                    VStack(spacing: 24) {
                        // User Profile Section
                        if let user = authService.currentUser {
                            UserProfileSection(user: user, userStats: userStatsService.userStats)
                        }
                        
                        // Settings Sections
                        VStack(spacing: 16) {
                            // Account Section
                            SettingsSection(title: "Account", icon: "person.circle") {
                                SettingsRow(
                                    icon: "bell",
                                    title: "Notifications",
                                    subtitle: "Push notifications and preferences",
                                    action: {
                                        showingNotificationSettings = true
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "lock.shield",
                                    title: "Privacy & Security",
                                    subtitle: "Data protection and security settings",
                                    action: {
                                        showingPrivacySettings = true
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "creditcard",
                                    title: "Subscription",
                                    subtitle: "Manage your subscription plan",
                                    action: {
                                        // Navigate to subscription view
                                    }
                                )
                            }
                            
                            // App Preferences Section
                            SettingsSection(title: "App Preferences", icon: "slider.horizontal.3") {
                                SettingsRow(
                                    icon: "paintbrush",
                                    title: "Appearance",
                                    subtitle: "Theme and display settings",
                                    action: {
                                        // Navigate to appearance settings
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "location",
                                    title: "Location Services",
                                    subtitle: "Manage location permissions",
                                    action: {
                                        // Navigate to location settings
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "square.and.arrow.down",
                                    title: "Storage & Cache",
                                    subtitle: "Clear app data and cache",
                                    action: {
                                        // Navigate to storage settings
                                    }
                                )
                            }
                            
                            // Support Section
                            SettingsSection(title: "Support & Info", icon: "questionmark.circle") {
                                SettingsRow(
                                    icon: "headphones",
                                    title: "Help & Support",
                                    subtitle: "Get help or contact support",
                                    action: {
                                        showingSupport = true
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "doc.text",
                                    title: "Terms of Service",
                                    subtitle: "Legal terms and conditions",
                                    action: {
                                        // Navigate to terms
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "hand.raised",
                                    title: "Privacy Policy",
                                    subtitle: "How we handle your data",
                                    action: {
                                        // Navigate to privacy policy
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "info.circle",
                                    title: "About RoomFinderAI",
                                    subtitle: "App version and information",
                                    action: {
                                        showingAbout = true
                                    }
                                )
                            }
                            
                            // Danger Zone Section
                            SettingsSection(title: "Account Actions", icon: "exclamationmark.triangle") {
                                SettingsRow(
                                    icon: "rectangle.portrait.and.arrow.right",
                                    title: "Sign Out",
                                    subtitle: "Sign out of your account",
                                    textColor: .orange,
                                    action: {
                                        showingLogoutAlert = true
                                    }
                                )
                                
                                SettingsRow(
                                    icon: "trash",
                                    title: "Delete Account",
                                    subtitle: "Permanently delete your account",
                                    textColor: .red,
                                    action: {
                                        showingDeleteAccountAlert = true
                                    }
                                )
                            }
                        }
                        
                        // App Version Footer
                        VStack(spacing: 8) {
                            Text("RoomFinderAI")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .padding()
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    try await authService.signOut()
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to sign out of your account?")
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Account", role: .destructive) {
                // Handle account deletion
                dismiss()
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView(notificationsService: notificationsService)
        }
        .sheet(isPresented: $showingPrivacySettings) {
            PrivacySettingsView()
        }
        .sheet(isPresented: $showingSupport) {
            SupportView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .task {
            await userStatsService.fetchUserStats()
            await notificationsService.fetchNotificationSettings()
        }
    }
}

struct UserProfileSection: View {
    let user: User
    let userStats: UserStats?
    
    var body: some View {
        GlassmorphismCard {
            HStack(spacing: 16) {
                // User Avatar
                AsyncImage(url: URL(string: user.profileImage ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 40))
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .background(
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 64, height: 64)
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName ?? "User")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Member since ") + Text(user.createdAt, style: .date)
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                // Quick stats
                if let stats = userStats {
                    VStack(alignment: .trailing, spacing: 4) {
                        QuickStatView(value: "\(stats.listingsCount)", label: "Listings")
                        QuickStatView(value: "\(stats.savedListingsCount)", label: "Saved")
                        QuickStatView(value: "\(stats.messagesCount)", label: "Messages")
                    }
                }
            }
            .padding()
        }
    }
}

struct QuickStatView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.8))
                    .font(.headline)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                content
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var textColor: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GlassmorphismCard {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundColor(textColor.opacity(0.8))
                        .font(.title3)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(textColor)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(textColor.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.caption)
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shareUsageData = false
    @State private var shareLocationData = true
    @State private var allowAnalytics = false
    @State private var dataRetentionPeriod = "1 year"
    
    let dataRetentionOptions = ["6 months", "1 year", "2 years", "Never delete"]
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        SettingsSection(title: "Data Collection", icon: "shield.checkerboard") {
                            SettingsToggleRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Share Usage Data",
                                subtitle: "Help improve the app by sharing anonymous usage data",
                                isOn: $shareUsageData
                            )
                            
                            SettingsToggleRow(
                                icon: "location.circle",
                                title: "Location Data",
                                subtitle: "Allow location-based property recommendations",
                                isOn: $shareLocationData
                            )
                            
                            SettingsToggleRow(
                                icon: "chart.pie",
                                title: "Analytics",
                                subtitle: "Share app performance and crash reports",
                                isOn: $allowAnalytics
                            )
                        }
                        
                        SettingsSection(title: "Data Management", icon: "folder.badge.gearshape") {
                            GlassmorphismCard {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock")
                                        .foregroundColor(.white.opacity(0.8))
                                        .font(.title3)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Data Retention")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("How long to keep your search history")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    
                                    Spacer()
                                    
                                    Picker("Data Retention", selection: $dataRetentionPeriod) {
                                        ForEach(dataRetentionOptions, id: \.self) { option in
                                            Text(option).tag(option)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .foregroundColor(.white)
                                }
                                .padding()
                            }
                            
                            SettingsRow(
                                icon: "trash.circle",
                                title: "Clear All Data",
                                subtitle: "Remove all stored data and preferences",
                                textColor: .red
                            ) {
                                // Handle clear all data
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Privacy & Security")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        SettingsSection(title: "Get Help", icon: "questionmark.circle") {
                            SettingsRow(
                                icon: "book",
                                title: "User Guide",
                                subtitle: "Learn how to use RoomFinderAI"
                            ) {
                                // Open user guide
                            }
                            
                            SettingsRow(
                                icon: "list.bullet.rectangle",
                                title: "FAQ",
                                subtitle: "Frequently asked questions"
                            ) {
                                // Open FAQ
                            }
                            
                            SettingsRow(
                                icon: "video",
                                title: "Video Tutorials",
                                subtitle: "Watch step-by-step guides"
                            ) {
                                // Open tutorials
                            }
                        }
                        
                        SettingsSection(title: "Contact Support", icon: "headphones") {
                            SettingsRow(
                                icon: "message",
                                title: "Live Chat",
                                subtitle: "Chat with our support team"
                            ) {
                                // Open live chat
                            }
                            
                            SettingsRow(
                                icon: "envelope",
                                title: "Email Support",
                                subtitle: "Send us an email"
                            ) {
                                // Open email support
                            }
                            
                            SettingsRow(
                                icon: "phone",
                                title: "Phone Support",
                                subtitle: "Call our support line"
                            ) {
                                // Open phone support
                            }
                        }
                        
                        SettingsSection(title: "Feedback", icon: "star") {
                            SettingsRow(
                                icon: "star.bubble",
                                title: "Rate the App",
                                subtitle: "Leave a review on the App Store"
                            ) {
                                // Open App Store review
                            }
                            
                            SettingsRow(
                                icon: "lightbulb",
                                title: "Send Feedback",
                                subtitle: "Share your ideas and suggestions"
                            ) {
                                // Open feedback form
                            }
                            
                            SettingsRow(
                                icon: "exclamationmark.triangle",
                                title: "Report a Bug",
                                subtitle: "Let us know about issues"
                            ) {
                                // Open bug report
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AnimatedGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // App Icon and Info
                        VStack(spacing: 16) {
                            Image(systemName: "house.and.flag")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .frame(width: 100, height: 100)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(20)
                            
                            VStack(spacing: 8) {
                                Text("RoomFinderAI")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Version 1.0.0 (Build 100)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        // App Description
                        GlassmorphismCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("About RoomFinderAI")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("RoomFinderAI is an intelligent property search platform that helps you find your perfect room or apartment. Using advanced AI technology, we match you with properties that fit your preferences and budget.")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineSpacing(4)
                            }
                            .padding()
                        }
                        
                        // Team Credits
                        GlassmorphismCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Development Team")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("• Lead Developer: Development Team")
                                    Text("• UI/UX Design: Design Team")
                                    Text("• AI Engineering: AI Team")
                                    Text("• Backend Development: Backend Team")
                                }
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                        }
                        
                        // Legal
                        VStack(spacing: 12) {
                            Text("© 2024 RoomFinderAI. All rights reserved.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 20) {
                                Button("Terms of Service") {
                                    // Open terms
                                }
                                .foregroundColor(.blue.opacity(0.8))
                                .font(.caption)
                                
                                Button("Privacy Policy") {
                                    // Open privacy policy
                                }
                                .foregroundColor(.blue.opacity(0.8))
                                .font(.caption)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    SettingsView(
        authService: AuthService(supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "key")),
        supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "key")
    )
}