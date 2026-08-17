import Foundation

/// Everything about *where* the app points, in one place.
enum AppConfig {

    /// Canonical origin. The sitemap and every internal link use `www`, and the
    /// apex currently answers too, so both are treated as "ours" for
    /// navigation decisions — but we always *load* the canonical one.
    static let origin = URL(string: "https://www.roomfinderai.com")!

    static let internalHosts: Set<String> = [
        "roomfinderai.com",
        "www.roomfinderai.com"
    ]

    /// Custom scheme registered in Info.plist, used by push payloads and email
    /// links: `roomfinderai://listings.html?id=123`.
    static let urlScheme = "roomfinderai"

    static func url(_ path: String) -> URL {
        URL(string: path, relativeTo: origin)?.absoluteURL ?? origin
    }

    /// True for pages the app should render itself rather than hand to Safari.
    static func isInternal(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return internalHosts.contains(host)
    }

    /// Schemes the system should handle instead of the web view.
    static let systemSchemes: Set<String> = ["tel", "mailto", "sms", "facetime", "facetime-audio", "maps", "itms-apps"]

    /// Third-party hosts that must stay inside the app's own web view.
    ///
    /// These are flows that navigate away and then redirect *back* to us —
    /// Stripe Checkout is the one that matters. Handing them to Safari means
    /// the user pays in a sheet, the success redirect lands in that sheet, and
    /// the app never learns the payment happened.
    static let inAppExternalHosts: Set<String> = [
        "checkout.stripe.com",
        "js.stripe.com",
        "hooks.stripe.com",
        "billing.stripe.com"
    ]

    static func staysInApp(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return inAppExternalHosts.contains(host)
    }
}
