import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: authViewModel.currentUser?.avatar ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        
                        VStack(spacing: 4) {
                            Text(authViewModel.currentUser?.name ?? "User")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(authViewModel.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text(authViewModel.currentUser?.verificationStatus.displayName ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Edit Profile") {
                            showingEditProfile = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.primaryBlue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.primaryBlue.opacity(0.1))
                        .cornerRadius(20)
                    }
                    
                    // Stats
                    HStack(spacing: 40) {
                        ProfileStat(title: "Searches", value: "24")
                        ProfileStat(title: "Favorites", value: "12")
                        ProfileStat(title: "Messages", value: "8")
                    }
                    .padding(.horizontal)
                    
                    // Menu Items
                    VStack(spacing: 0) {
                        ProfileMenuItem(
                            icon: "heart.fill",
                            title: "Favorite Listings",
                            subtitle: "View your saved properties",
                            action: { /* Navigate to favorites */ }
                        )
                        
                        ProfileMenuItem(
                            icon: "clock.fill",
                            title: "Search History",
                            subtitle: "View recent searches",
                            action: { /* Navigate to search history */ }
                        )
                        
                        ProfileMenuItem(
                            icon: "bell.fill",
                            title: "Notifications",
                            subtitle: "Manage your alerts",
                            action: { /* Navigate to notifications */ }
                        )
                        
                        ProfileMenuItem(
                            icon: "creditcard.fill",
                            title: "Subscription",
                            subtitle: "\(authViewModel.currentUser?.subscriptionStatus.displayName ?? "Free")",
                            action: { /* Navigate to subscription */ }
                        )
                        
                        ProfileMenuItem(
                            icon: "gear",
                            title: "Settings",
                            subtitle: "App preferences",
                            action: { showingSettings = true }
                        )
                        
                        ProfileMenuItem(
                            icon: "questionmark.circle.fill",
                            title: "Help & Support",
                            subtitle: "Get help or contact us",
                            action: { /* Navigate to help */ }
                        )
                        
                        ProfileMenuItem(
                            icon: "doc.text.fill",
                            title: "Terms & Privacy",
                            subtitle: "Legal information",
                            action: { /* Navigate to terms */ }
                        )
                    }
                    
                    // Sign Out Button
                    Button(action: {
                        Task {
                            await authViewModel.signOut()
                        }
                    }) {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                    .scaleEffect(0.8)
                            }
                            
                            Text("Sign Out")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(authViewModel.isLoading)
                    .padding(.horizontal)
                    
                    // App Version
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 40)
                }
                .padding(.top)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

struct ProfileStat: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
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
                    .font(.title2)
                    .foregroundColor(.primaryBlue)
                    .frame(width: 24, height: 24)
                
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
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var name = ""
    @State private var phone = ""
    @State private var location = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Full Name", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Phone")
                        Spacer()
                        TextField("Phone Number", text: $phone)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Location")
                        Spacer()
                        TextField("City, State", text: $location)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Account") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authViewModel.currentUser?.email ?? "")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Verification Status")
                        Spacer()
                        Text(authViewModel.currentUser?.verificationStatus.displayName ?? "")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    Task {
                        await authViewModel.updateProfile(
                            name: name.isEmpty ? nil : name,
                            phone: phone.isEmpty ? nil : phone,
                            location: location.isEmpty ? nil : location
                        )
                        dismiss()
                    }
                }
                .disabled(authViewModel.isLoading)
            )
        }
        .onAppear {
            name = authViewModel.currentUser?.name ?? ""
            phone = authViewModel.currentUser?.phone ?? ""
            location = authViewModel.currentUser?.location ?? ""
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = false
    @State private var locationEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                    Toggle("Email Notifications", isOn: $notificationsEnabled)
                    Toggle("SMS Notifications", isOn: $notificationsEnabled)
                }
                
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                }
                
                Section("Privacy") {
                    Toggle("Location Services", isOn: $locationEnabled)
                }
                
                Section("Data") {
                    Button("Clear Search History") {
                        // Clear search history
                    }
                    .foregroundColor(.red)
                    
                    Button("Clear Cache") {
                        // Clear cache
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}