import Foundation
import Supabase
import Security

final class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let client = SupabaseClientProvider.shared
    
    private let keychainService = "com.roomfinderai.auth"
    private let sessionKey = "supabase_session"
    
    init() {
        checkAuthStatus()
    }
    
    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(email: email, password: password)
        
        await MainActor.run {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
        
        await saveSessionToKeychain(response.session)
        await setCurrentUserEmail(email)
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "first_name": .string(firstName),
                "last_name": .string(lastName)
            ]
        )
        
        if let user = response.user {
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
            }
            
            if let session = response.session {
                await saveSessionToKeychain(session)
            }
            
            await setCurrentUserEmail(email)
            
            try await createUserProfile(email: email, firstName: firstName, lastName: lastName)
        }
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
        
        removeSessionFromKeychain()
    }
    
    func refreshSession() async throws {
        let session = try await client.auth.refreshSession()
        
        await saveSessionToKeychain(session)
        
        if let user = session.user {
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
            }
            
            await setCurrentUserEmail(user.email ?? "")
        }
    }
    
    private func checkAuthStatus() {
        if let session = getSessionFromKeychain() {
            Task {
                do {
                    try await client.auth.setSession(accessToken: session.accessToken, refreshToken: session.refreshToken)
                    
                    let user = try await client.auth.user()
                    await MainActor.run {
                        self.currentUser = user
                        self.isAuthenticated = true
                    }
                    
                    await setCurrentUserEmail(user.email ?? "")
                } catch {
                    print("Failed to restore session: \(error)")
                    removeSessionFromKeychain()
                }
            }
        }
    }
    
    private func createUserProfile(email: String, firstName: String, lastName: String) async throws {
        let profileData: [String: AnyJSON] = [
            "email": .string(email),
            "first_name": .string(firstName),
            "last_name": .string(lastName),
            "profile_image": .string("https://via.placeholder.com/40")
        ]
        
        try await client.database
            .from("users")
            .insert(profileData)
            .execute()
    }
    
    private func setCurrentUserEmail(_ email: String) async {
        do {
            try await client.database.rpc("set_current_user_email", params: ["user_email": email]).execute()
        } catch {
            print("Failed to set current user email: \(error)")
        }
    }
    
    private func saveSessionToKeychain(_ session: Session) async {
        let sessionData = try? JSONEncoder().encode(SessionData(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: session.expiresAt
        ))
        
        guard let data = sessionData else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: sessionKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getSessionFromKeychain() -> SessionData? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: sessionKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr, let data = dataTypeRef as? Data {
            return try? JSONDecoder().decode(SessionData.self, from: data)
        }
        
        return nil
    }
    
    private func removeSessionFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: sessionKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

struct SessionData: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}