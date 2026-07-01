import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if authViewModel.isAuthenticated {
                    authenticatedContent
                } else {
                    unauthenticatedContent
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .environmentObject(authViewModel)
            }
        }
    }
    
    private var authenticatedContent: some View {
        VStack(spacing: 25) {
            // Profile header
            VStack(spacing: 15) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                if let user = authViewModel.currentUser {
                    VStack(spacing: 5) {
                        Text(user.name ?? "User")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Edit Profile") {
                    showingEditProfile = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.top)
            
            // Profile options
            VStack(spacing: 0) {
                ProfileOptionRow(
                    icon: "heart",
                    title: "Saved Listings",
                    action: { /* TODO */ }
                )
                
                Divider()
                
                ProfileOptionRow(
                    icon: "clock",
                    title: "Recent Activity",
                    action: { /* TODO */ }
                )
                
                Divider()
                
                ProfileOptionRow(
                    icon: "gearshape",
                    title: "Settings",
                    action: { showingSettings = true }
                )
                
                Divider()
                
                ProfileOptionRow(
                    icon: "questionmark.circle",
                    title: "Help & Support",
                    action: { /* TODO */ }
                )
            }
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Spacer()
            
            // Sign out button
            Button(action: {
                authViewModel.signOut()
            }) {
                Text("Sign Out")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private var unauthenticatedContent: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "person.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                Text("Sign In Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Sign in to access your profile and saved preferences")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Sign In") {
                authViewModel.signIn()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            
            Spacer()
        }
        .padding()
    }
}

struct ProfileOptionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Settings")
                    .font(.title2)
                    .padding()
                
                Text("Settings options coming soon...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var fullName = ""
    @State private var email = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top)
                
                VStack(spacing: 15) {
                    TextField("Full Name", text: $fullName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                }
                .padding(.horizontal)
                
                Button("Save Changes") {
                    // TODO: Save profile changes
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            if let user = authViewModel.currentUser {
                fullName = user.name ?? ""
                email = user.email
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}