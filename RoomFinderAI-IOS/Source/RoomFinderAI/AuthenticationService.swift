import Foundation
import Supabase
import Auth

// MARK: - Authentication Error
enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case emailAlreadyExists
    case weakPassword
    case networkError
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .weakPassword:
            return "Password is too weak. Please use at least 6 characters"
        case .networkError:
            return "Network error. Please check your connection"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - User Profile Model
struct UserProfile: Codable {
    let id: UUID
    let email: String
    let firstName: String?
    let lastName: String?
    let profileImage: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case profileImage = "profile_image"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Authentication Service
@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var currentUser: Auth.User?
    @Published var userProfile: UserProfile?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private let client = SupabaseConfig.client
    
    private init() {
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Authentication Status
    
    func checkAuthStatus() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            self.isAuthenticated = session.user != nil
            
            if let user = session.user {
                await fetchUserProfile(userId: user.id)
            }
        } catch {
            print("❌ Error checking auth status: \(error)")
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Create auth user with metadata
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: [
                    "first_name": .string(firstName),
                    "last_name": .string(lastName)
                ]
            )
            
            guard let user = response.user else {
                throw AuthenticationError.unknown(NSError(domain: "auth", code: -1))
            }
            
            self.currentUser = user
            self.isAuthenticated = true
            
            // Fetch the created profile
            await fetchUserProfile(userId: user.id)
            
        } catch let error as AuthError {
            print("❌ Auth error: \(error)")
            throw handleAuthError(error)
        } catch {
            print("❌ Sign up error: \(error)")
            throw AuthenticationError.unknown(error)
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            self.currentUser = response.user
            self.isAuthenticated = true
            
            if let user = response.user {
                await fetchUserProfile(userId: user.id)
            }
            
        } catch let error as AuthError {
            print("❌ Auth error: \(error)")
            throw handleAuthError(error)
        } catch {
            print("❌ Sign in error: \(error)")
            throw AuthenticationError.unknown(error)
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await client.auth.signOut()
            self.currentUser = nil
            self.userProfile = nil
            self.isAuthenticated = false
        } catch {
            print("❌ Sign out error: \(error)")
            throw AuthenticationError.unknown(error)
        }
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await client.auth.resetPasswordForEmail(email)
        } catch let error as AuthError {
            print("❌ Auth error: \(error)")
            throw handleAuthError(error)
        } catch {
            print("❌ Password reset error: \(error)")
            throw AuthenticationError.unknown(error)
        }
    }
    
    // MARK: - Profile Management
    
    private func fetchUserProfile(userId: UUID) async {
        do {
            let profile: UserProfile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            self.userProfile = profile
        } catch {
            print("❌ Error fetching profile: \(error)")
        }
    }
    
    func updateProfile(firstName: String, lastName: String) async throws {
        guard let userId = currentUser?.id else {
            throw AuthenticationError.userNotFound
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let updatedProfile: UserProfile = try await client
                .from("profiles")
                .update([
                    "first_name": firstName,
                    "last_name": lastName,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: userId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            self.userProfile = updatedProfile
        } catch {
            print("❌ Error updating profile: \(error)")
            throw AuthenticationError.unknown(error)
        }
    }
    
    func uploadProfileImage(imageData: Data) async throws -> String {
        guard let userId = currentUser?.id else {
            throw AuthenticationError.userNotFound
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let fileName = "\(userId.uuidString)/profile-\(Date().timeIntervalSince1970).jpg"
        
        do {
            // Upload to Supabase Storage
            try await client.storage
                .from("avatars")
                .upload(
                    path: fileName,
                    file: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )
            
            // Get public URL
            let publicURL = try client.storage
                .from("avatars")
                .getPublicURL(path: fileName)
            
            // Update profile with new image URL
            let updatedProfile: UserProfile = try await client
                .from("profiles")
                .update(["profile_image": publicURL.absoluteString])
                .eq("id", value: userId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            self.userProfile = updatedProfile
            return publicURL.absoluteString
            
        } catch {
            print("❌ Error uploading profile image: \(error)")
            throw AuthenticationError.unknown(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleAuthError(_ error: AuthError) -> AuthenticationError {
        switch error {
        case .api(let message):
            if message.contains("Invalid login") {
                return .invalidCredentials
            } else if message.contains("User already registered") {
                return .emailAlreadyExists
            } else if message.contains("Password") {
                return .weakPassword
            }
            return .unknown(error)
        case .network:
            return .networkError
        default:
            return .unknown(error)
        }
    }
    
    // MARK: - Session Token
    
    func getAccessToken() async -> String? {
        do {
            let session = try await client.auth.session
            return session.accessToken
        } catch {
            print("❌ Error getting access token: \(error)")
            return nil
        }
    }
}