import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    let authViewModel: SimpleAuthViewModel
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
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
                        // First Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("First Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your first name", text: $firstName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .textContentType(.givenName)
                                    .autocapitalization(.words)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Last Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your last name", text: $lastName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .textContentType(.familyName)
                                    .autocapitalization(.words)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
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
                            
                            // Password Requirements
                            if !password.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    PasswordRequirement(
                                        text: "At least 6 characters",
                                        isValid: password.count >= 6
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
                                    .stroke(confirmPassword.isEmpty ? Color.clear : (password == confirmPassword ? Color.green : Color.red), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if authViewModel.hasError {
                        Text(authViewModel.errorMessage ?? "")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Sign Up Button
                    Button(action: {
                        authViewModel.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
                        if authViewModel.isAuthenticated {
                            dismiss()
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
            .alert("Sign Up", isPresented: .constant(authViewModel.hasError)) {
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
    
    private var isFormValid: Bool {
        return !firstName.isEmpty &&
               !lastName.isEmpty &&
               !email.isEmpty &&
               password.count >= 6 &&
               password == confirmPassword
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
    SignUpView(authViewModel: SimpleAuthViewModel())
}