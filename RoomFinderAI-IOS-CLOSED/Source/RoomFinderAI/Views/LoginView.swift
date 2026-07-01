import SwiftUI
import Supabase

struct LoginView: View {
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showPassword = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer(minLength: 40)
                    
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .opacity(0.9)
                        
                        Text("Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Sign in to continue to RoomFinder AI")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Login Form
                    GlassmorphismCard {
                        VStack(spacing: 24) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    
                                    TextField("Enter your email", text: $email)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                )
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(.secondary)
                                        .frame(width: 20)
                                    
                                    if showPassword {
                                        TextField("Enter your password", text: $password)
                                            .textFieldStyle(PlainTextFieldStyle())
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                            .textFieldStyle(PlainTextFieldStyle())
                                    }
                                    
                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                )
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
                            
                            // Sign In Button
                            Button(action: {
                                signIn()
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "arrow.right")
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: isFormValid ? [.blue, .purple] : [.gray, .gray],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || isLoading)
                            
                            // Forgot Password
                            Button(action: {
                                // TODO: Implement forgot password
                            }) {
                                Text("Forgot Password?")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
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
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && !password.isEmpty && password.count >= 6
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Invalid email or password. Please try again."
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        LoginView(authService: AuthService(supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "key")))
    }
}