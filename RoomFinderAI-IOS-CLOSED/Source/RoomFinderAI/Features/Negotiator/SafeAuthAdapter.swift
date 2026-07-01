import Foundation
import SwiftUI

// MARK: - Safe Authentication Adapter
/// Provides "safe auth" functionality that never redirects and operates in read-only mode when needed
class SafeAuthAdapter: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var isAnonymous: Bool = false
    
    // MARK: - User Model
    struct AuthUser: Codable, Equatable {
        let id: String?
        let email: String
        let name: String?
        let firstName: String?
        let lastName: String?
        let profileImage: String?
        
        var displayName: String {
            if let name = name, !name.isEmpty {
                return name
            }
            if let firstName = firstName, let lastName = lastName {
                return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            }
            if let firstName = firstName {
                return firstName
            }
            return email
        }
        
        var isAnonymous: Bool {
            return email == "anonymous@user.com" || email.contains("anonymous")
        }
    }
    
    // MARK: - Initialization
    init() {
        loadCurrentUser()
    }
    
    // MARK: - User Management
    func loadCurrentUser() {
        // Try to load from existing session
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(AuthUser.self, from: userData) {
            self.currentUser = user
            self.isAnonymous = user.isAnonymous
            print("SafeAuth: Loaded existing user: \(user.email)")
            return
        }
        
        // Try to load from localStorage equivalent
        if let userString = UserDefaults.standard.string(forKey: "currentUser_localStorage"),
           let userData = userString.data(using: .utf8),
           let userDict = try? JSONSerialization.jsonObject(with: userData) as? [String: Any] {
            
            let user = AuthUser(
                id: userDict["id"] as? String,
                email: userDict["email"] as? String ?? "anonymous@user.com",
                name: userDict["name"] as? String,
                firstName: userDict["firstName"] as? String,
                lastName: userDict["lastName"] as? String,
                profileImage: userDict["profileImage"] as? String
            )
            
            self.currentUser = user
            self.isAnonymous = user.isAnonymous
            saveCurrentUser(user)
            print("SafeAuth: Migrated user from localStorage: \(user.email)")
            return
        }
        
        // No existing user found, create anonymous session
        createAnonymousSession()
    }
    
    func createAnonymousSession() {
        let anonymousUser = AuthUser(
            id: UUID().uuidString,
            email: "anonymous@user.com",
            name: "Anonymous User",
            firstName: "Anonymous",
            lastName: "User",
            profileImage: generateDefaultAvatar()
        )
        
        self.currentUser = anonymousUser
        self.isAnonymous = true
        saveCurrentUser(anonymousUser)
        print("SafeAuth: Created anonymous session")
    }
    
    func updateUserProfile(name: String? = nil, profileImage: String? = nil) {
        guard var user = currentUser else { return }
        
        if let name = name {
            user = AuthUser(
                id: user.id,
                email: user.email,
                name: name,
                firstName: user.firstName,
                lastName: user.lastName,
                profileImage: profileImage ?? user.profileImage
            )
        }
        
        if let profileImage = profileImage {
            user = AuthUser(
                id: user.id,
                email: user.email,
                name: user.name,
                firstName: user.firstName,
                lastName: user.lastName,
                profileImage: profileImage
            )
        }
        
        self.currentUser = user
        saveCurrentUser(user)
    }
    
    private func saveCurrentUser(_ user: AuthUser) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "currentUser")
        }
    }
    
    // MARK: - Profile Creation
    func ensureProfile(with supabase: SupabaseClient) async -> AuthUser? {
        guard let user = currentUser else {
            createAnonymousSession()
            return currentUser
        }
        
        // For anonymous users, don't try to create database profiles
        if user.isAnonymous {
            return user
        }
        
        do {
            // Check if profile exists
            let existingProfile = try await supabase
                .from("profiles")
                .select("*")
                .eq("email", value: user.email)
                .execute()
            
            // If profile exists, we're done
            if let data = existingProfile.data as? Data,
               let profiles = try? JSONDecoder().decode([[String: Any]].self, from: data),
               !profiles.isEmpty {
                print("SafeAuth: Profile exists for \(user.email)")
                return user
            }
            
            // Create minimal profile
            let profileData: [String: Any] = [
                "email": user.email,
                "name": user.displayName,
                "profile_image": user.profileImage ?? generateDefaultAvatar(),
                "created_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            try await supabase
                .from("profiles")
                .insert(profileData)
                .execute()
            
            print("SafeAuth: Created profile for \(user.email)")
            return user
            
        } catch {
            print("SafeAuth: Warning - Could not ensure profile for \(user.email): \(error)")
            // Continue with existing user data - never fail
            return user
        }
    }
    
    // MARK: - Safe Operations
    func performSafeAuth<T>(operation: () async throws -> T, fallback: T) async -> T {
        guard let user = currentUser, !user.isAnonymous else {
            print("SafeAuth: Operation skipped - anonymous user")
            return fallback
        }
        
        do {
            return try await operation()
        } catch {
            print("SafeAuth: Operation failed safely: \(error)")
            return fallback
        }
    }
    
    func requiresAuth() -> Bool {
        return currentUser == nil || isAnonymous
    }
    
    func getUserEmail() -> String {
        return currentUser?.email ?? "anonymous@user.com"
    }
    
    func getUserDisplayName() -> String {
        return currentUser?.displayName ?? "Anonymous User"
    }
    
    // MARK: - Default Avatar Generation
    private func generateDefaultAvatar() -> String {
        return "data:image/svg+xml;base64," + Data("""
            <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
                <rect width="100" height="100" rx="50" fill="#E5E7EB"/>
                <path d="M50 45C56.075 45 61 40.075 61 34C61 27.925 56.075 23 50 23C43.925 23 39 27.925 39 34C39 40.075 43.925 45 50 45Z" fill="#9CA3AF"/>
                <path d="M30 77C30 77 30 66.103 30 62C30 55.373 36.268 50 44 50H56C63.732 50 70 55.373 70 62C70 66.103 70 77 70 77" fill="#9CA3AF"/>
            </svg>
        """.utf8).base64EncodedString()
    }
    
    // MARK: - Session Persistence
    func preserveSession() {
        if let user = currentUser {
            saveCurrentUser(user)
            
            // Also save to backup locations for restoration
            UserDefaults.standard.set(user.email, forKey: "backup_user_email")
            UserDefaults.standard.set(user.displayName, forKey: "backup_user_name")
            UserDefaults.standard.set(Date(), forKey: "backup_timestamp")
        }
    }
    
    func restoreSession() {
        // If current session is lost, try to restore from backups
        if currentUser == nil {
            if let email = UserDefaults.standard.string(forKey: "backup_user_email"),
               let name = UserDefaults.standard.string(forKey: "backup_user_name") {
                
                let restoredUser = AuthUser(
                    id: UUID().uuidString,
                    email: email,
                    name: name,
                    firstName: nil,
                    lastName: nil,
                    profileImage: generateDefaultAvatar()
                )
                
                self.currentUser = restoredUser
                self.isAnonymous = restoredUser.isAnonymous
                saveCurrentUser(restoredUser)
                print("SafeAuth: Restored session for \(email)")
            }
        }
    }
    
    // MARK: - Debug Information
    func getDebugInfo() -> String {
        guard let user = currentUser else {
            return "No current user session"
        }
        
        return """
        SafeAuth Debug Info:
        - Email: \(user.email)
        - Display Name: \(user.displayName)
        - Is Anonymous: \(user.isAnonymous)
        - Has Profile Image: \(user.profileImage != nil)
        - Session Valid: \(currentUser != nil)
        """
    }
}

// MARK: - SwiftUI Integration
extension SafeAuthAdapter {
    var isAuthenticated: Bool {
        return currentUser != nil && !isAnonymous
    }
    
    var canPerformAuthenticatedActions: Bool {
        return currentUser != nil // Including anonymous users for read-only operations
    }
}

// MARK: - Supabase Extension
import Supabase

extension SafeAuthAdapter {
    func createSafeSupabaseClient(url: String, key: String) -> SupabaseClient {
        return SupabaseClient(supabaseURL: URL(string: url)!, supabaseKey: key)
    }
    
    func performSupabaseOperation<T>(
        _ operation: (SupabaseClient) async throws -> T,
        supabase: SupabaseClient,
        fallback: T
    ) async -> T {
        do {
            return try await operation(supabase)
        } catch {
            print("SafeAuth: Supabase operation failed safely: \(error)")
            return fallback
        }
    }
}