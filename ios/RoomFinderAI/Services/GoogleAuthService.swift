import AuthenticationServices
import Foundation
import UIKit

/// Google sign-in for the app.
///
/// The website signs in with Google Identity Services, which opens a popup and
/// talks back to its opener with `postMessage`. Neither half of that works
/// here: `WKWebView` has no popup to open, and Google actively refuses OAuth
/// from embedded web views (`disallowed_useragent`) precisely because an
/// embedding app could read the password.
///
/// So the app runs the authorization-code flow in `ASWebAuthenticationSession`
/// — the system's own Safari context, which Google accepts and which the app
/// cannot see into. The code that comes back is handed to the page, which
/// exchanges it through the same backend endpoint the website already uses.
/// One sign-in implementation, two front doors.
@MainActor
final class GoogleAuthService: NSObject {

    static let shared = GoogleAuthService()

    enum AuthError: LocalizedError {
        case notConfigured
        case cancelled
        case denied(String)
        case noCode

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Google sign-in is not configured."
            case .cancelled:     return "Sign-in cancelled."
            case .denied(let m): return m
            case .noCode:        return "Google did not return an authorization code."
            }
        }
    }

    private var session: ASWebAuthenticationSession?
    private weak var anchor: UIWindow?

    /// Cached from `/api/config` so the client ID and redirect URI are never
    /// hardcoded in two places.
    private struct RemoteConfig: Decodable {
        let GOOGLE_OAUTH_CLIENT_ID: String?
        let GOOGLE_NATIVE_REDIRECT_URI: String?
    }
    private var cachedConfig: RemoteConfig?

    private func loadConfig() async throws -> RemoteConfig {
        if let cachedConfig { return cachedConfig }
        let (data, _) = try await URLSession.shared.data(from: AppConfig.url("api/config"))
        let decoded = try JSONDecoder().decode(RemoteConfig.self, from: data)
        cachedConfig = decoded
        return decoded
    }

    /// Runs the flow and returns the authorization code plus the redirect URI
    /// it was issued for — the backend needs both to complete the exchange.
    func signIn(presentingFrom window: UIWindow?) async throws -> (code: String, redirectURI: String) {
        anchor = window

        let config = try await loadConfig()
        guard let clientID = config.GOOGLE_OAUTH_CLIENT_ID, !clientID.isEmpty,
              let redirectURI = config.GOOGLE_NATIVE_REDIRECT_URI, !redirectURI.isEmpty else {
            throw AuthError.notConfigured
        }

        // `state` is generated per attempt and checked on return, so a redirect
        // the app did not start cannot complete a sign-in.
        //
        // The "rfios." prefix is what tells the server this redirect belongs to
        // the app and should be bounced into the custom URL scheme. Google only
        // has the site root registered as a redirect URI, so without the marker
        // the server cannot tell an app sign-in from ordinary homepage traffic.
        let state = "rfios." + UUID().uuidString

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "state", value: state),
            // Without this Google returns no code on repeat sign-ins.
            .init(name: "prompt", value: "select_account")
        ]

        guard let authURL = components.url else { throw AuthError.notConfigured }

        let callback = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: AppConfig.urlScheme
            ) { url, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let url else {
                    continuation.resume(throwing: AuthError.noCode)
                    return
                }
                continuation.resume(returning: url)
            }

            session.presentationContextProvider = self
            // Uses the shared Safari session, so someone already signed in to
            // Google on this phone taps once instead of typing a password.
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let error = value("error") {
            throw AuthError.denied(error == "access_denied" ? "Sign-in cancelled." : error)
        }
        guard value("state") == state else {
            throw AuthError.denied("Sign-in could not be verified. Please try again.")
        }
        guard let code = value("code"), !code.isEmpty else {
            throw AuthError.noCode
        }

        return (code, redirectURI)
    }
}

extension GoogleAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor ?? ASPresentationAnchor()
    }
}
