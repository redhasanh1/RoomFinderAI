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