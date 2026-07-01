import Foundation
import SwiftUI

class SimpleAuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let mockDataService = MockDataService.shared
    
    init() {
        // Check if user is already logged in (stored in UserDefaults for simplicity)
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        if isLoggedIn {
            // Load stored user data
            self.currentUser = mockDataService.getSampleUser()
            self.isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Simple validation - any email/password combo works for demo
            if !email.isEmpty && !password.isEmpty && email.contains("@") {
                let user = User(
                    id: "user123",
                    email: email,
                    firstName: "Demo",
                    lastName: "User",
                    profileImage: nil,
                    createdAt: Date().addingTimeInterval(-86400 * 30),
                    updatedAt: Date()
                )
                
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
                
                // Store login state
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                UserDefaults.standard.set(email, forKey: "userEmail")
            } else {
                self.errorMessage = "Please enter a valid email and password"
                self.isLoading = false
            }
        }
    }
    
    func signUp(email: String, password: String, firstName: String?, lastName: String?) {
        isLoading = true
        errorMessage = nil
        
        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Simple validation
            if !email.isEmpty && !password.isEmpty && email.contains("@") && password.count >= 6 {
                let user = User(
                    id: "user\(Int.random(in: 100...999))",
                    email: email,
                    firstName: firstName,
                    lastName: lastName,
                    profileImage: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
                
                // Store login state
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                UserDefaults.standard.set(email, forKey: "userEmail")
            } else {
                if password.count < 6 {
                    self.errorMessage = "Password must be at least 6 characters"
                } else {
                    self.errorMessage = "Please enter a valid email and password"
                }
                self.isLoading = false
            }
        }
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        
        // Clear stored login state
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "userEmail")
    }
    
    // MARK: - Validation Helpers
    
    func validateEmail(_ email: String) -> Bool {
        return email.contains("@") && email.contains(".")
    }
    
    func validatePassword(_ password: String) -> Bool {
        return password.count >= 6
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    var hasError: Bool {
        return errorMessage != nil
    }
    
    // MARK: - Profile Management
    
    func updateProfile(name: String?, phone: String?, location: String?) async {
        isLoading = true
        
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            // In a real app, this would update the user profile via API
            // For demo purposes, we just update the current user
            if let currentUser = self.currentUser {
                // Create updated user with new name
                let updatedUser = User(
                    id: currentUser.id,
                    email: currentUser.email,
                    firstName: name?.components(separatedBy: " ").first ?? currentUser.firstName,
                    lastName: name?.components(separatedBy: " ").dropFirst().joined(separator: " "),
                    profileImage: currentUser.profileImage,
                    createdAt: currentUser.createdAt,
                    updatedAt: Date()
                )
                
                self.currentUser = updatedUser
            }
            
            self.isLoading = false
        }
    }
}