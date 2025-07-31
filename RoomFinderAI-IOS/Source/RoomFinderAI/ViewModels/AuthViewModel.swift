import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var confirmPassword = ""
    
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isAuthenticated = false
    
    private let authService = AuthenticationService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe authentication state changes
        authService.$isAuthenticated
            .assign(to: &$isAuthenticated)
        
        authService.$isLoading
            .assign(to: &$isLoading)
    }
    
    // MARK: - Sign In
    
    func signIn() async {
        guard validateSignInForm() else { return }
        
        do {
            try await authService.signIn(email: email, password: password)
            clearForm()
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Sign Up
    
    func signUp() async {
        guard validateSignUpForm() else { return }
        
        do {
            try await authService.signUp(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            clearForm()
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Password Reset
    
    func resetPassword() async {
        guard !email.isEmpty else {
            showError = true
            errorMessage = "Please enter your email address"
            return
        }
        
        do {
            try await authService.resetPassword(email: email)
            showError = true
            errorMessage = "Password reset email sent. Please check your inbox."
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Validation
    
    private func validateSignInForm() -> Bool {
        if email.isEmpty || password.isEmpty {
            showError = true
            errorMessage = "Please fill in all fields"
            return false
        }
        
        if !isValidEmail(email) {
            showError = true
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        return true
    }
    
    private func validateSignUpForm() -> Bool {
        if email.isEmpty || password.isEmpty || firstName.isEmpty || lastName.isEmpty {
            showError = true
            errorMessage = "Please fill in all fields"
            return false
        }
        
        if !isValidEmail(email) {
            showError = true
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        if password.count < 6 {
            showError = true
            errorMessage = "Password must be at least 6 characters"
            return false
        }
        
        if password != confirmPassword {
            showError = true
            errorMessage = "Passwords don't match"
            return false
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func clearForm() {
        email = ""
        password = ""
        firstName = ""
        lastName = ""
        confirmPassword = ""
    }
    
    // MARK: - User Info
    
    var currentUser: Auth.User? {
        authService.currentUser
    }
    
    var userProfile: UserProfile? {
        authService.userProfile
    }
    
    var userDisplayName: String {
        if let profile = userProfile {
            return profile.fullName.isEmpty ? profile.email : profile.fullName
        }
        return currentUser?.email ?? "Guest"
    }
}