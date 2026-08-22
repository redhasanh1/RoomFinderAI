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
        if let stored = UserDefaults.standard.string(forKey: Self.key)?.nilIfEmpty {
            email = stored
            return
        }

        // Falls back to the saved sign-in.
        //
        // This used to depend on AuthService having been created first, since
        // its init is what calls update() here. Nothing at launch created it,
        // so the app could hold a perfectly good session — the profile is in
        // UserDefaults, the Profile tab shows it — while this said nobody was
        // signed in, and every screen that asks here showed its signed-out
        // state. Messages said "Sign in to see messages" to someone who was.
        //
        // Reading the stored session directly removes the ordering question
        // rather than moving it somewhere else.
        struct StoredProfile: Decodable { let email: String }
        if let data = UserDefaults.standard.data(forKey: "authProfile"),
           let saved = try? JSONDecoder().decode(StoredProfile.self, from: data) {
            email = saved.email.nilIfEmpty
        }
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

        // Push registration is filed under the signed-in address, and the
        // token usually arrives before anyone has signed in — so registering
        // only from the token callback meant the common case never registered
        // at all. Signing out hands the device back, so the next person on
        // this phone does not receive the last one's messages.
        Task {
            if cleaned != nil {
                await PushService.shared.registerWithServer()
            } else {
                await PushService.shared.unregisterWithServer()
            }
        }
    }
}
