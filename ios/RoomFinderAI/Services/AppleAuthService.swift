import AuthenticationServices
import UIKit

/// Native Sign in with Apple.
///
/// Required, not optional: App Store guideline 4.8 says an app offering a
/// third-party sign-in (Google, here) must also offer a privacy-preserving
/// equivalent, and Sign in with Apple is the one Apple accepts. The website's
/// AppleID JavaScript cannot stand in for it — that library opens a popup,
/// which a web view has nowhere to put.
///
/// The identity token goes to the same `/api/auth/apple` endpoint the website
/// uses, which verifies it against Apple's published signing keys.
@MainActor
final class AppleAuthService: NSObject {

    static let shared = AppleAuthService()

    struct Credential {
        let identityToken: String
        let authorizationCode: String?
        /// Apple returns the name ONLY on the very first authorization for an
        /// app, and never again. The backend has to persist it on that first
        /// pass or the account is stuck as "User Name" forever.
        let firstName: String?
        let lastName: String?
    }

    enum AuthError: LocalizedError {
        case cancelled
        case noToken

        var errorDescription: String? {
            switch self {
            case .cancelled: return "Sign-in cancelled."
            case .noToken:   return "Apple did not return an identity token."
            }
        }
    }

    private var continuation: CheckedContinuation<Credential, Error>?
    private weak var anchor: UIWindow?

    func signIn(presentingFrom window: UIWindow?) async throws -> Credential {
        anchor = window

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<Credential, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            finish(.failure(AuthError.noToken))
            return
        }

        let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        finish(.success(Credential(
            identityToken: token,
            authorizationCode: code,
            firstName: credential.fullName?.givenName,
            lastName: credential.fullName?.familyName
        )))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            finish(.failure(AuthError.cancelled))
        } else {
            finish(.failure(error))
        }
    }
}

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor ?? ASPresentationAnchor()
    }
}
