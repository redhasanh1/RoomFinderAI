import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var showingSignUp = false
    @State private var showPassword = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "house.lodge.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.primaryBlue)
                        
                        Text("RoomFinderAI")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Find your perfect room with AI-powered search")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Login Form
                    VStack(spacing: 16) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
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
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Forgot Password Link
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                Task {
                                    await resetPassword()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.primaryBlue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(errorMessage.contains("sent") ? .green : .red)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }
                    
                    // Login Button
                    Button(action: {
                        Task {
                            await signIn()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text("Sign In")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.primaryBlue, .secondaryPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    .opacity(email.isEmpty || password.isEmpty || isLoading ? 0.6 : 1.0)
                    .padding(.horizontal)
                    
                    // Or Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color(.systemGray5))
                        
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color(.systemGray5))
                    }
                    .padding(.horizontal)
                    
                    // Google OAuth Button
                    Button(action: {
                        Task {
                            await signInWithGoogle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "globe")
                                .font(.headline)
                            
                            Text("Continue with Google")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    // Guest Mode Button
                    Button(action: {
                        // Continue as guest - dismiss the modal
                        dismiss()
                    }) {
                        Text("Continue as Guest")
                            .font(.headline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Sign Up Link
                    HStack {
                        Text("Don't have an account?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Sign Up") {
                            showingSignUp = true
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryBlue)
                    }
                    .padding(.bottom, 40)
                }
                .padding(.top)
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
        .alert("Authentication", isPresented: .constant(errorMessage != nil)) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signIn(email: email, password: password)
            // Login successful - dismiss the modal
            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func signInWithGoogle() async {
        do {
            try await authService.signInWithGoogle()
            // Google OAuth initiated - dismiss on success
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func resetPassword() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address first"
            return
        }
        
        do {
            try await authService.resetPassword(email: email)
            errorMessage = "Password reset email sent to \(email)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Extension for hiding keyboard
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService(supabaseClient: SupabaseClient(supabaseURL: URL(string: "https://example.supabase.co")!, supabaseKey: "test")))
}