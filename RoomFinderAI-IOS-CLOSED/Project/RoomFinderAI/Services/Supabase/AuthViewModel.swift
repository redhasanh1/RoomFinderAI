import Foundation
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        // TODO: Implement Supabase auth check
        // For now, simulate auth state
        isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        print("Auth status checked: \(isAuthenticated)")
    }
    
    func signIn() {
        isLoading = true
        errorMessage = nil
        
        // TODO: Implement proper Supabase authentication
        // For now, simulate sign in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isAuthenticated = true
            self.currentUser = User(id: "demo-user", email: "demo@example.com")
            UserDefaults.standard.set(true, forKey: "isAuthenticated")
            self.isLoading = false
            print("User signed in successfully")
        }
    }
    
    func signOut() {
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
        print("User signed out")
    }
    
    func createAccount() {
        // TODO: Implement account creation with Supabase
        print("Create account functionality coming soon")
    }
}

