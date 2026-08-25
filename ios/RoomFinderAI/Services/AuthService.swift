import Foundation
import Security

/// Signing in, natively.
///
/// The website used to own this entirely: the Profile tab was profile.html in a
/// web view, and who you were lived in that web view's localStorage. Everything
/// native had to be told about it through an injected bridge, which is why
/// `CurrentUser` exists and why the negotiator and the inbox could disagree
/// about whether anyone was signed in.
///
/// This owns it instead. The website's endpoints are unchanged — the same
/// `/api/login` the site posts to — so an account made on the web works here
/// and the other way round.
@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    struct Profile: Codable, Equatable {
        var email: String
        var firstName: String
        var lastName: String
        var profileImage: String?
        var plan: String?
        var isPro: Bool?
        var userId: String?

        /// Whether a real name has ever been set. The login endpoint answers
        /// with the placeholder "User Name" for accounts that have not, so the
        /// presence of a value is not enough to go on.
        var hasName: Bool {
            let joined = [firstName, lastName]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return !joined.isEmpty && joined.caseInsensitiveCompare("User Name") != .orderedSame
        }

        var displayName: String {
            let joined = [firstName, lastName]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return joined.isEmpty ? email : joined
        }

        /// Two initials for the avatar, falling back to the address so there is
        /// never an empty circle.
        var initials: String {
            let parts = [firstName, lastName]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if parts.isEmpty { return String(email.prefix(1)).uppercased() }
            return parts.prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
        }
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @Published private(set) var profile: Profile?
    @Published private(set) var isWorking = false

    var isSignedIn: Bool { profile != nil }

    /// The access token, kept for the one call that needs it: deleting the
    /// account. Held in the keychain rather than UserDefaults because it is a
    /// credential, and a device backup carries UserDefaults in the clear.
    private let tokens = TokenStore()

    private static let profileKey = "authProfile"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.profileKey),
           let saved = try? JSONDecoder().decode(Profile.self, from: data) {
            profile = saved
            CurrentUser.shared.update(email: saved.email)
        }
    }

    // MARK: - Signing in

    func signIn(email: String, password: String) async throws {
        let body: [String: Any] = ["email": email, "password": password]
        let data = try await post("api/login", body)
        try adopt(loginResponse: data, fallbackEmail: email)
    }

    /// Step one of making an account: emails a six-digit code.
    ///
    /// No account exists after this. The server creates it only once the code
    /// comes back, which is why this used to fail every time: it registered and
    /// then immediately tried to sign in, against an account that could not be
    /// there yet, so every sign-up ended on an error and nobody could join.
    func startRegistration(name: String, email: String, password: String) async throws {
        let body: [String: Any] = ["name": name, "email": email, "password": password]
        _ = try await post("api/register", body)
    }

    /// Step two: hands the code back, which creates the account, then signs in
    /// for a real session.
    func completeRegistration(name: String, email: String, password: String, code: String) async throws {
        let parts = name.split(separator: " ", maxSplits: 1).map(String.init)
        let body: [String: Any] = [
            "email": email,
            "code": code,
            "firstName": parts.first ?? name,
            "lastName": parts.count > 1 ? parts[1] : "",
            "password": password
        ]
        // The website's own endpoint, which is the one that actually creates
        // the account. /api/auth/verify-code answers from an in-memory list and
        // hands back a token the rest of the API does not accept.
        _ = try await post("api/verify-email", body)

        try await signIn(email: email, password: password)
    }

    /// Sends a fresh code, for one that expired or never arrived.
    func resendRegistrationCode(name: String, email: String, password: String) async throws {
        try await startRegistration(name: name, email: email, password: password)
    }

    func signInWithGoogle(code: String, redirectURI: String) async throws {
        let data = try await post("api/auth/google/oauth-code", [
            "code": code,
            "redirectUri": redirectURI
        ])
        try adopt(loginResponse: data, fallbackEmail: nil)
    }

    func signInWithApple(identityToken: String, authorizationCode: String?,
                         firstName: String?, lastName: String?) async throws {
        var body: [String: Any] = ["identityToken": identityToken]
        if let authorizationCode { body["authorizationCode"] = authorizationCode }
        if firstName != nil || lastName != nil {
            body["user"] = ["name": ["firstName": firstName ?? "", "lastName": lastName ?? ""]]
        }
        let data = try await post("api/auth/apple", body)
        try adopt(loginResponse: data, fallbackEmail: nil)
    }

    func signOut() {
        profile = nil
        tokens.clear()
        UserDefaults.standard.removeObject(forKey: Self.profileKey)
        CurrentUser.shared.update(email: nil)
    }

    // MARK: - The account

    /// Refreshes the stored profile from the server.
    ///
    /// Never signs anyone out on failure. A flaky connection is not proof the
    /// account is gone, and treating it as such logs people out on the train.
    func refresh() async {
        guard let email = profile?.email else { return }
        struct Response: Decodable {
            let id: String?
            let email: String?
            let firstName: String?
            let lastName: String?
            let profileImage: String?
            let plan: String?
            let isPro: Bool?
        }

        let path = "api/user-profile/\(email.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? email)"
        guard let data = try? await get(path),
              let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return }

        var updated = profile!
        // An empty string is not a name. The profile endpoint returns "" for
        // someone who has never set one, and `??` only steps aside for nil — so
        // refreshing replaced the name the login response had just given us with
        // nothing, and the header fell back to showing the raw email address.
        updated.firstName = decoded.firstName?.nilIfEmpty ?? updated.firstName
        updated.lastName = decoded.lastName?.nilIfEmpty ?? updated.lastName
        updated.profileImage = decoded.profileImage
        updated.plan = decoded.plan
        updated.isPro = decoded.isPro
        updated.userId = decoded.id ?? updated.userId
        store(updated)
    }

    func updateName(firstName: String, lastName: String) async throws {
        guard let email = profile?.email else { throw Failure(message: "You're not signed in.") }
        _ = try await post("api/update-profile", [
            "email": email,
            "firstName": firstName,
            "lastName": lastName
        ])
        var updated = profile!
        updated.firstName = firstName
        updated.lastName = lastName
        store(updated)
    }

    /// Deletes the account for good, which is why it asks for the password
    /// again rather than trusting the session.
    func deleteAccount(password: String) async throws {
        guard let email = profile?.email else { throw Failure(message: "You're not signed in.") }
        var body: [String: Any] = ["email": email, "password": password]
        if let token = tokens.accessToken { body["accessToken"] = token }
        _ = try await post("api/account/delete", body)
        signOut()
    }

    // MARK: - Plumbing

    private func adopt(loginResponse data: Data, fallbackEmail: String?) throws {
        struct Response: Decodable {
            struct User: Decodable {
                let firstName: String?
                let lastName: String?
                let email: String?
            }
            let access_token: String?
            let refresh_token: String?
            let userId: String?
            let user: User?
            let email: String?
        }

        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw Failure(message: "Signed in, but the server's answer couldn't be read.")
        }

        guard let email = decoded.user?.email ?? decoded.email ?? fallbackEmail else {
            throw Failure(message: "Signed in, but no account address came back.")
        }

        tokens.save(access: decoded.access_token, refresh: decoded.refresh_token)

        store(Profile(
            email: email,
            firstName: decoded.user?.firstName ?? "",
            lastName: decoded.user?.lastName ?? "",
            profileImage: nil,
            plan: nil,
            isPro: nil,
            userId: decoded.userId
        ))

        // Everything native reads CurrentUser, and it is what registers this
        // device for push under the right address.
        CurrentUser.shared.update(email: email)

        Task { await refresh() }
    }

    private func store(_ updated: Profile) {
        profile = updated
        if let data = try? JSONEncoder().encode(updated) {
            UserDefaults.standard.set(data, forKey: Self.profileKey)
        }
    }

    private func get(_ path: String) async throws -> Data {
        var request = URLRequest(url: AppConfig.url(path))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
        return data
    }

    @discardableResult
    private func post(_ path: String, _ body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: AppConfig.url(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
        return data
    }

    private func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw Failure(message: "No answer from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            // The server's own wording is better than a status code: it knows
            // whether the password was wrong or the address was never
            // registered.
            struct Refusal: Decodable { let error: String?; let message: String? }
            let stated = (try? JSONDecoder().decode(Refusal.self, from: data))
            throw Failure(message: stated?.error ?? stated?.message
                          ?? "That didn't work (error \(http.statusCode)).")
        }
    }
}

/// The access and refresh tokens, in the keychain.
private struct TokenStore {

    private let service = "com.roomfinderai.app.auth"

    var accessToken: String? { read("access") }

    func save(access: String?, refresh: String?) {
        write("access", access)
        write("refresh", refresh)
    }

    func clear() {
        write("access", nil)
        write("refresh", nil)
    }

    private func write(_ account: String, _ value: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        guard let value, let data = value.data(using: .utf8) else { return }
        var insert = query
        insert[kSecValueData as String] = data
        // Not synchronised to iCloud, and unavailable until the device has been
        // unlocked once after boot.
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    private func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
