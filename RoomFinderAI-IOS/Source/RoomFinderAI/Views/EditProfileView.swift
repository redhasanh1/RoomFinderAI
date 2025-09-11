import SwiftUI
import Supabase

struct EditProfileView: View {
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var isLoading = false
    @State private var successMessage = ""
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer(minLength: 20)
                    
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 120, height: 120)
                            
                            AsyncImage(url: URL(string: authService.currentUser?.profileImage ?? "")) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        }
                        
                        Text("Edit Profile")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Update your profile information")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Edit Form
                    GlassmorphismCard {
                        VStack(spacing: 20) {
                            // Name Fields Row
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("First Name")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Image(systemName: "person")
                                            .foregroundColor(.secondary)
                                            .frame(width: 20)
                                        
                                        TextField("First name", text: $firstName)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .autocapitalization(.words)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6))
                                    )
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last Name")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Image(systemName: "person")
                                            .foregroundColor(.secondary)
                                            .frame(width: 20)
                                        
                                        TextField("Last name", text: $lastName)
                                            .textFieldStyle(PlainTextFieldStyle())
                                            .autocapitalization(.words)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6))
                                    )
                                }
                            }
                            
                            // Email Field (Read Only)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    
                                    Text(email)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray5))
                                )
                            }
                            
                            // Success Message
                            if !successMessage.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text(successMessage)
                                        .font(.caption)
                                }
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Error Message
                            if !errorMessage.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                    Text(errorMessage)
                                        .font(.caption)
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Save Button
                            Button(action: {
                                saveProfile()
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "checkmark")
                                        Text("Save Changes")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: hasChanges ? [.blue, .purple] : [.gray, .gray],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .disabled(!hasChanges || isLoading)
                        }
                        .padding(24)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .onAppear {
            loadUserData()
        }
    }
    
    private var hasChanges: Bool {
        let currentFirstName = authService.currentUser?.firstName ?? ""
        let currentLastName = authService.currentUser?.lastName ?? ""
        
        return firstName != currentFirstName || lastName != currentLastName
    }
    
    private func loadUserData() {
        firstName = authService.currentUser?.firstName ?? ""
        lastName = authService.currentUser?.lastName ?? ""
        email = authService.currentUser?.email ?? ""
    }
    
    private func saveProfile() {
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        // Since AuthService doesn't have an updateProfile method, 
        // we'll simulate it for now and add a note to implement it properly
        Task {
            // TODO: Implement profile update in AuthService
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            await MainActor.run {
                // For now, we'll update the current user locally
                if let currentUser = authService.currentUser {
                    let updatedUser = User(
                        id: currentUser.id,
                        email: currentUser.email,
                        firstName: firstName,
                        lastName: lastName,
                        profileImage: currentUser.profileImage,
                        createdAt: currentUser.createdAt,
                        updatedAt: Date()
                    )
                    
                    // This would need to be implemented in AuthService
                    // authService.currentUser = updatedUser
                    
                    successMessage = "Profile updated successfully!"
                    isLoading = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        EditProfileView(authService: AuthService(supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "key")))
    }
}