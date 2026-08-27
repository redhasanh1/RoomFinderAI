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

    /// Marks a request as coming from the iOS app.
    ///
    /// The server runs these on the free tier whatever the account has bought.
    /// Pro is sold on the website through Stripe and is not available as an
    /// In-App Purchase, and App Store guideline 3.1.1 only allows a
    /// subscription bought elsewhere to work inside an app when the same
    /// subscription is also sold there — which it cannot be until the Paid Apps
    /// Agreement is active. So the app unlocks nothing that was paid for
    /// outside it, and the website is unaffected.
    static func request(_ path: String) -> URLRequest {
        var request = URLRequest(url: url(path))
        request.setValue("ios", forHTTPHeaderField: "X-RoomFinder-Client")
        return request
    }

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
    /// Only `js.stripe.com` remains, because it is a script the site loads
    /// rather than a place the user goes. Stripe *Checkout* is deliberately no
    /// longer here — see `blocksPurchasing` below.
    static let inAppExternalHosts: Set<String> = [
        "js.stripe.com"
    ]

    static func staysInApp(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return inAppExternalHosts.contains(host)
    }

    // MARK: - Purchasing

    /// Pages and hosts that sell the Pro plan, which this build does not offer.
    ///
    /// App Store guideline 3.1.1 requires anything that unlocks features inside
    /// an app to be sold through In-App Purchase. This app is a web view over
    /// the site, and the site sells Pro through Stripe — so simply dropping the
    /// native Pricing menu item would not have been enough: the website's own
    /// navigation still links to it, and a reviewer following that link finds a
    /// card form. That is a straightforward rejection.
    ///
    /// So the whole route is closed on iOS. Pro remains available on the web,
    /// which is expressly allowed as long as the app does not send people there
    /// to buy it. Nothing here reads as an upsell for that reason.
    private static let purchasePaths: Set<String> = [
        "/pricing.html",
        "/payment.html"
    ]

    private static let purchaseHosts: Set<String> = [
        "checkout.stripe.com",
        "billing.stripe.com",
        "hooks.stripe.com"
    ]

    /// True for anything that would let someone buy a plan.
    static func blocksPurchasing(_ url: URL) -> Bool {
        if let host = url.host?.lowercased(), purchaseHosts.contains(host) { return true }

        // Internal pages are matched on path, case-insensitively, and with any
        // query string ignored — `pricing.html?plan=pro` is the same door.
        guard isInternal(url) else { return false }
        return purchasePaths.contains(url.path.lowercased())
    }
}
