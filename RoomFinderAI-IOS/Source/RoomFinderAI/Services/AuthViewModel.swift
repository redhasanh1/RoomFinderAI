import Foundation
import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        isLoading = true
        
        Task {
            do {
                print("🔍 Checking authentication status...")
                let user = try await supabaseService.getCurrentUser()
                
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = user != nil
                    self.isLoading = false
                    self.errorMessage = nil
                    print("✅ Auth check completed. Authenticated: \(self.isAuthenticated)")
                }
            } catch {
                print("❌ Auth check error: \(error)")
                await MainActor.run {
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.isLoading = false
                    self.errorMessage = "Authentication check failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func signUp(email: String, password: String, name: String? = nil) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let user = try await supabaseService.signUp(email: email, password: password, name: name)
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signIn(email: String, password: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let user = try await supabaseService.signIn(email: email, password: password)
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signOut() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            try await supabaseService.signOut()
            
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
                self.isLoading = false
            }
            
            clearStoredData()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func resetPassword(email: String) async -> Bool {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            try await supabaseService.resetPassword(email: email)
            
            await MainActor.run {
                self.isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            
            return false
        }
    }
    
    func updateProfile(name: String?, phone: String?, location: String?) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let userId = currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
                self.isLoading = false
            }
            return
        }
        
        do {
            let updatedUser = try await updateUserProfile(
                userId: userId,
                name: name,
                phone: phone,
                location: location
            )
            
            await MainActor.run {
                self.currentUser = updatedUser
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func updatePreferences(_ preferences: UserPreferences) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let userId = currentUser?.id else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
                self.isLoading = false
            }
            return
        }
        
        do {
            let updatedUser = try await updateUserPreferences(
                userId: userId,
                preferences: preferences
            )
            
            await MainActor.run {
                self.currentUser = updatedUser
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func clearStoredData() {
        KeychainManager.shared.deleteString(for: Constants.KeychainKeys.accessToken)
        KeychainManager.shared.deleteString(for: Constants.KeychainKeys.refreshToken)
        KeychainManager.shared.deleteString(for: Constants.KeychainKeys.userSession)
        
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.userPreferences)
    }
    
    private func updateUserProfile(
        userId: String,
        name: String?,
        phone: String?,
        location: String?
    ) async throws -> User {
        var updateData: [String: Any] = [
            "updated_at": Date().ISO8601Format()
        ]
        
        if let name = name {
            updateData["name"] = name
        }
        
        if let phone = phone {
            updateData["phone"] = phone
        }
        
        if let location = location {
            updateData["location"] = location
        }
        
        // This would typically call the Supabase service to update the profile
        // For now, we'll return the current user with updated fields
        guard let currentUser = currentUser else {
            throw AuthError.userNotFound
        }
        
        return User(
            id: currentUser.id,
            email: currentUser.email,
            firstName: name ?? currentUser.firstName,
            lastName: currentUser.lastName,
            profileImage: currentUser.profileImage,
            createdAt: currentUser.createdAt,
            updatedAt: Date()
        )
    }
    
    private func updateUserPreferences(
        userId: String,
        preferences: UserPreferences
    ) async throws -> User {
        guard let currentUser = currentUser else {
            throw AuthError.userNotFound
        }
        
        return User(
            id: currentUser.id,
            email: currentUser.email,
            firstName: currentUser.firstName,
            lastName: currentUser.lastName,
            profileImage: currentUser.profileImage,
            createdAt: currentUser.createdAt,
            updatedAt: Date()
        )
    }
    
    // MARK: - Validation
    
    func validateEmail(_ email: String) -> Bool {
        return email.isValidEmail
    }
    
    func validatePassword(_ password: String) -> Bool {
        return password.isValidPassword
    }
    
    func validatePasswordConfirmation(_ password: String, _ confirmation: String) -> Bool {
        return password == confirmation && validatePassword(password)
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    var hasError: Bool {
        return errorMessage != nil
    }
}

enum AuthError: Error {
    case userNotFound
    case invalidCredentials
    case networkError
    case sessionExpired
    case unknownError
    
    var localizedDescription: String {
        switch self {
        case .userNotFound:
            return "User not found"
        case .invalidCredentials:
            return "Invalid credentials"
        case .networkError:
            return "Network error occurred"
        case .sessionExpired:
            return "Session has expired"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}