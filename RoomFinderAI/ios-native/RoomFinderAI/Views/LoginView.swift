import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    @State private var showPassword = false
    
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(email.isEmpty ? Color.clear : (authViewModel.validateEmail(email) ? Color.green : Color.red), lineWidth: 1)
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(password.isEmpty ? Color.clear : (authViewModel.validatePassword(password) ? Color.green : Color.red), lineWidth: 1)
                        )
                    }
                    
                    // Forgot Password
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            showingForgotPassword = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.primaryBlue)
                    }
                }
                .padding(.horizontal)
                
                // Error Message
                if authViewModel.hasError {
                    Text(authViewModel.errorMessage ?? "An error occurred")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Login Button
                Button(action: {
                    Task {
                        await authViewModel.signIn(email: email, password: password)
                    }
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
                .disabled(!isFormValid || authViewModel.isLoading)
                .opacity(isFormValid && !authViewModel.isLoading ? 1.0 : 0.6)
                .padding(.horizontal)
                
                // Social Login Options
                VStack(spacing: 12) {
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.horizontal)
                    
                    // Sign in with Apple
                    Button(action: {
                        // Implement Sign in with Apple
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                                .font(.headline)
                            
                            Text("Continue with Apple")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
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
            SignUpView()
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private var isFormValid: Bool {
        return authViewModel.validateEmail(email) && authViewModel.validatePassword(password)
    }
}

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 50))
                        .foregroundColor(.primaryBlue)
                    
                    Text("Reset Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(email.isEmpty ? Color.clear : (authViewModel.validateEmail(email) ? Color.green : Color.red), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                if authViewModel.hasError {
                    Text(authViewModel.errorMessage ?? "An error occurred")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    Task {
                        let success = await authViewModel.resetPassword(email: email)
                        if success {
                            showingSuccess = true
                        }
                    }
                }) {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text("Send Reset Link")
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
                .disabled(!authViewModel.validateEmail(email) || authViewModel.isLoading)
                .opacity(authViewModel.validateEmail(email) && !authViewModel.isLoading ? 1.0 : 0.6)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
            .alert("Email Sent", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Please check your email for password reset instructions.")
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}