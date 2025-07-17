import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var agreeToTerms = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.primaryBlue)
                        
                        Text("Create Account")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Join thousands of users finding their perfect room")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Sign Up Form
                    VStack(spacing: 16) {
                        // Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your full name", text: $name)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .textContentType(.name)
                                    .autocapitalization(.words)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(name.isEmpty ? Color.clear : (name.count >= 2 ? Color.green : Color.red), lineWidth: 1)
                            )
                        }
                        
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
                                        .textContentType(.newPassword)
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .textContentType(.newPassword)
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
                            
                            // Password Requirements
                            if !password.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    PasswordRequirement(
                                        text: "At least 8 characters",
                                        isValid: password.count >= 8
                                    )
                                    PasswordRequirement(
                                        text: "Contains uppercase and lowercase letters",
                                        isValid: password.contains(where: { $0.isUppercase }) && password.contains(where: { $0.isLowercase })
                                    )
                                    PasswordRequirement(
                                        text: "Contains a number",
                                        isValid: password.contains(where: { $0.isNumber })
                                    )
                                }
                                .padding(.leading, 8)
                            }
                        }
                        
                        // Confirm Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                
                                if showConfirmPassword {
                                    TextField("Confirm your password", text: $confirmPassword)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .textContentType(.newPassword)
                                } else {
                                    SecureField("Confirm your password", text: $confirmPassword)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .textContentType(.newPassword)
                                }
                                
                                Button(action: {
                                    showConfirmPassword.toggle()
                                }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(confirmPassword.isEmpty ? Color.clear : (authViewModel.validatePasswordConfirmation(password, confirmPassword) ? Color.green : Color.red), lineWidth: 1)
                            )
                        }
                        
                        // Terms and Conditions
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: {
                                agreeToTerms.toggle()
                            }) {
                                Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(agreeToTerms ? .primaryBlue : .secondary)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I agree to the")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    Button("Terms of Service") {
                                        // Open Terms of Service
                                    }
                                    .font(.caption)
                                    .foregroundColor(.primaryBlue)
                                    
                                    Text("and")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Button("Privacy Policy") {
                                        // Open Privacy Policy
                                    }
                                    .font(.caption)
                                    .foregroundColor(.primaryBlue)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if authViewModel.hasError {
                        Text(authViewModel.errorMessage ?? "An error occurred")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Sign Up Button
                    Button(action: {
                        Task {
                            await authViewModel.signUp(email: email, password: password, name: name)
                        }
                    }) {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text("Create Account")
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
                    
                    // Sign in with Apple
                    Button(action: {
                        // Implement Sign in with Apple
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                                .font(.headline)
                            
                            Text("Sign up with Apple")
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
                    
                    // Sign In Link
                    HStack {
                        Text("Already have an account?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Sign In") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryBlue)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    private var isFormValid: Bool {
        return !name.isEmpty &&
               name.count >= 2 &&
               authViewModel.validateEmail(email) &&
               authViewModel.validatePasswordConfirmation(password, confirmPassword) &&
               agreeToTerms
    }
}

struct PasswordRequirement: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? .green : .red)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .green : .red)
            
            Spacer()
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}