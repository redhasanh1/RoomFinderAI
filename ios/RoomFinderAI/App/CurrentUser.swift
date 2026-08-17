import Foundation

/// Who is signed in, as far as the native side is concerned.
///
/// The website is the authority here: it identifies people from
/// `localStorage.currentUser`, which lives inside the web view's data store and
/// cannot be read from Swift directly. So the injected bridge posts the address
/// whenever a page loads, and this caches it for the native screens that need
/// it — filing a report, blocking someone.
///
/// Cached in UserDefaults so a native tab opened before any web page has loaded
/// still knows who the user is.
@MainActor
enum CurrentUser {

    private static let key = "currentUserEmail"

    static var email: String? {
        get { UserDefaults.standard.string(forKey: key)?.nilIfEmpty }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    static var isSignedIn: Bool { email != nil }
}
