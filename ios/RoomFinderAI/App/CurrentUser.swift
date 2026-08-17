import Combine
import Foundation

/// Who is signed in, as far as the native side is concerned.
///
/// The website is the authority: it identifies people from
/// `localStorage.currentUser`, which lives inside the web view's data store and
/// cannot be read from Swift. The injected bridge posts the address whenever a
/// page loads, and this holds it for the native screens that need it — the
/// inbox, reporting, blocking, posting a room.
///
/// Observable, and that matters: as a plain static it could change without
/// SwiftUI noticing, so signing in on the Profile tab left the other tabs
/// still showing "sign in to see messages" until the app was relaunched.
@MainActor
final class CurrentUser: ObservableObject {

    static let shared = CurrentUser()

    private static let key = "currentUserEmail"

    /// Persisted, so a native tab opened before any web page has loaded still
    /// knows who the user is.
    @Published private(set) var email: String?

    private init() {
        email = UserDefaults.standard.string(forKey: Self.key)?.nilIfEmpty
    }

    var isSignedIn: Bool { email != nil }

    /// Called by the web bridge. `nil` means signed out, which must clear the
    /// cached address rather than be ignored.
    func update(email newValue: String?) {
        let cleaned = newValue?.nilIfEmpty
        guard cleaned != email else { return }

        email = cleaned
        if let cleaned {
            UserDefaults.standard.set(cleaned, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }
}
