import Foundation
import Security

// MARK: - Keychain Service
class KeychainService {
    static let shared = KeychainService()
    
    private let serviceName = "com.roomfinder.ai"
    private let accessGroup = "group.com.roomfinder.ai"
    
    private init() {}
    
    // MARK: - Generic Keychain Operations
    
    func save<T: Codable>(_ item: T, forKey key: String) -> Bool {
        do {
            let data = try JSONEncoder().encode(item)
            return saveData(data, forKey: key)
        } catch {
            print("Failed to encode item for keychain: \(error)")
            return false
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = loadData(forKey: key) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to decode item from keychain: \(error)")
            return nil
        }
    }
    
    func saveData(_ data: Data, forKey key: String) -> Bool {
        // Delete any existing item first
        deleteItem(forKey: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func loadData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }
    
    func deleteItem(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Authentication Token Management
    
    func saveAuthToken(_ token: String) -> Bool {
        return saveData(token.data(using: .utf8) ?? Data(), forKey: "auth_token")
    }
    
    func getAuthToken() -> String? {
        guard let data = loadData(forKey: "auth_token") else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func deleteAuthToken() -> Bool {
        return deleteItem(forKey: "auth_token")
    }
    
    // MARK: - User Session Management
    
    func saveUserSession(_ session: UserSession) -> Bool {
        return save(session, forKey: "user_session")
    }
    
    func getUserSession() -> UserSession? {
        return load(UserSession.self, forKey: "user_session")
    }
    
    func deleteUserSession() -> Bool {
        return deleteItem(forKey: "user_session")
    }
    
    // MARK: - Refresh Token Management
    
    func saveRefreshToken(_ token: String) -> Bool {
        return saveData(token.data(using: .utf8) ?? Data(), forKey: "refresh_token")
    }
    
    func getRefreshToken() -> String? {
        guard let data = loadData(forKey: "refresh_token") else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func deleteRefreshToken() -> Bool {
        return deleteItem(forKey: "refresh_token")
    }
    
    // MARK: - Biometric Authentication Settings
    
    func saveBiometricEnabled(_ enabled: Bool) -> Bool {
        return saveData(Data([enabled ? 1 : 0]), forKey: "biometric_enabled")
    }
    
    func isBiometricEnabled() -> Bool {
        guard let data = loadData(forKey: "biometric_enabled") else { return false }
        return data.first == 1
    }
    
    // MARK: - Device ID Management
    
    func saveDeviceId(_ deviceId: String) -> Bool {
        return saveData(deviceId.data(using: .utf8) ?? Data(), forKey: "device_id")
    }
    
    func getDeviceId() -> String? {
        guard let data = loadData(forKey: "device_id") else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func getOrCreateDeviceId() -> String {
        if let existingId = getDeviceId() {
            return existingId
        }
        
        let newId = UUID().uuidString
        _ = saveDeviceId(newId)
        return newId
    }
}

// MARK: - User Session Model
struct UserSession: Codable {
    let userId: String
    let email: String
    let firstName: String
    let lastName: String
    let profileImage: String?
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let deviceId: String
    let lastActivity: Date
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var isActive: Bool {
        return !isExpired && Date().timeIntervalSince(lastActivity) < 3600 // 1 hour
    }
}

// MARK: - Session Manager
class SessionManager {
    static let shared = SessionManager()
    
    private let keychain = KeychainService.shared
    private var currentSession: UserSession?
    
    // Session change notifications
    static let sessionDidStartNotification = Notification.Name("SessionDidStart")
    static let sessionDidEndNotification = Notification.Name("SessionDidEnd")
    static let sessionDidExpireNotification = Notification.Name("SessionDidExpire")
    
    private init() {
        loadExistingSession()
    }
    
    // MARK: - Session Management
    
    func startSession(user: User, accessToken: String, refreshToken: String?, expiresIn: TimeInterval = 3600) {
        let session = UserSession(
            userId: user.id,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            profileImage: user.profileImage,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn),
            deviceId: keychain.getOrCreateDeviceId(),
            lastActivity: Date()
        )
        
        currentSession = session
        
        // Save to keychain
        _ = keychain.saveUserSession(session)
        _ = keychain.saveAuthToken(accessToken)
        
        if let refreshToken = refreshToken {
            _ = keychain.saveRefreshToken(refreshToken)
        }
        
        // Notify about session start
        NotificationCenter.default.post(name: SessionManager.sessionDidStartNotification, object: session)
        
        print("✅ Session started for user: \(user.email)")
    }
    
    func endSession() {
        currentSession = nil
        
        // Clear keychain
        _ = keychain.deleteUserSession()
        _ = keychain.deleteAuthToken()
        _ = keychain.deleteRefreshToken()
        
        // Notify about session end
        NotificationCenter.default.post(name: SessionManager.sessionDidEndNotification, object: nil)
        
        print("✅ Session ended")
    }
    
    func updateActivity() {
        guard var session = currentSession else { return }
        
        session = UserSession(
            userId: session.userId,
            email: session.email,
            firstName: session.firstName,
            lastName: session.lastName,
            profileImage: session.profileImage,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: session.expiresAt,
            deviceId: session.deviceId,
            lastActivity: Date()
        )
        
        currentSession = session
        _ = keychain.saveUserSession(session)
    }
    
    // MARK: - Session Validation
    
    func isSessionValid() -> Bool {
        guard let session = currentSession else { return false }
        return session.isActive
    }
    
    func getAccessToken() -> String? {
        guard let session = currentSession, session.isActive else { return nil }
        return session.accessToken
    }
    
    func getCurrentUser() -> User? {
        guard let session = currentSession, session.isActive else { return nil }
        
        return User(
            id: session.userId,
            email: session.email,
            firstName: session.firstName,
            lastName: session.lastName,
            phone: nil,
            profileImage: session.profileImage,
            createdAt: ""
        )
    }
    
    func getRefreshToken() -> String? {
        guard let session = currentSession else { return nil }
        return session.refreshToken
    }
    
    // MARK: - Session Refresh
    
    func refreshSession(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = getRefreshToken() else {
            completion(false)
            return
        }
        
        SecureAPIService.shared.refreshAccessToken(refreshToken: refreshToken) { [weak self] result in
            switch result {
            case .success(let authResponse):
                if let user = authResponse.user, let token = authResponse.token {
                    self?.startSession(user: user, accessToken: token, refreshToken: refreshToken)
                    completion(true)
                } else {
                    completion(false)
                }
            case .failure:
                self?.endSession()
                completion(false)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadExistingSession() {
        guard let session = keychain.getUserSession() else { return }
        
        if session.isExpired {
            // Try to refresh if we have a refresh token
            if session.refreshToken != nil {
                refreshSession { _ in }
            } else {
                endSession()
            }
        } else {
            currentSession = session
            print("✅ Existing session loaded for user: \(session.email)")
        }
    }
}