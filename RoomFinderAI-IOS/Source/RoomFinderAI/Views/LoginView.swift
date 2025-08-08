import SwiftUI

struct LoginView: View {
    @StateObject private var authViewModel = SimpleAuthViewModel()
    @State private var showingSignUp = false
    @State private var showPassword = false
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
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
                .padding(.top, 40)
                
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
                                    .textContentType(.password)
                            } else {
                                SecureField("Enter your password", text: $password)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .textContentType(.password)
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
                            // Reset password functionality not implemented in SimpleAuthViewModel
                        }
                        .font(.caption)
                        .foregroundColor(.primaryBlue)
                    }
                }
                .padding(.horizontal)
                
                // Error Message
                if authViewModel.hasError {
                    Text(authViewModel.errorMessage ?? "")
                        .font(.caption)
                        .foregroundColor((authViewModel.errorMessage ?? "").contains("sent") ? .green : .red)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                
                // Login Button
                Button(action: {
                    authViewModel.signIn(email: email, password: password)
                }) {
                    HStack {
                        if authViewModel.isLoading {
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
                .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                .opacity(email.isEmpty || password.isEmpty || authViewModel.isLoading ? 0.6 : 1.0)
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
                
                // Guest Mode Button
                Button(action: {
                    // Continue as guest - no authentication needed
                    authViewModel.isAuthenticated = false
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
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSignUp) {
            SignUpView(authViewModel: authViewModel)
        }
        .alert("Authentication", isPresented: .constant(authViewModel.hasError)) {
            Button("OK", role: .cancel) {
                authViewModel.clearError()
            }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
}

// Note: hideKeyboard() extension is defined in Extensions.swift

#Preview {
    LoginView()
}