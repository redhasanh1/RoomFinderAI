import Foundation

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
    
    func startSession(user: User, accessToken: String, refreshToken: String? = nil) {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let expiresAt = Date().addingTimeInterval(24 * 60 * 60) // 24 hours
        
        let session = UserSession(
            userId: user.id,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            profileImage: user.profileImage,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            deviceId: deviceId,
            lastActivity: Date()
        )
        
        currentSession = session
        let success = keychain.saveUserSession(session)
        
        if success {
            NotificationCenter.default.post(name: Self.sessionDidStartNotification, object: user)
            print("✅ Session started for user: \(user.email)")
        } else {
            print("❌ Failed to save session to keychain")
        }
    }
    
    func endSession() {
        guard let session = currentSession else { return }
        let user = getCurrentUser()
        
        currentSession = nil
        keychain.deleteUserSession()
        
        NotificationCenter.default.post(name: Self.sessionDidEndNotification, object: user)
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