import Foundation

/// The sections of the app, matching the website's header so the two do not
/// have to be learned separately. Favourites, Support and the legal pages live
/// in the native overflow menu, mirroring the site's "More" dropdown.
enum AppTab: String, CaseIterable, Identifiable, Codable {
    case home
    case listings
    /// Both kinds of conversation: the AI negotiator, and real threads with
    /// landlords and roommates. Named after what the website calls it.
    case messages
    case roompal
    case sublease
    /// An action, not a place. Selecting it opens the post sheet and hands the
    /// selection straight back to the tab you were on, which is why it has no
    /// screen of its own.
    case post
    case profile

    /// The same sections the website's header has, in the same order, plus
    /// Post.
    ///
    /// It used to be a five-slot bar with Sublease and Listings hidden in an
    /// overflow menu, so someone who knew the site could not find them here.
    /// Matching the site means the two do not have to be learned separately.
    /// Five slots, with Post dead centre.
    ///
    /// Seven was tried, to mirror the website's header. iOS sizes this bar to
    /// fit whatever it is given rather than growing, so every item got narrower
    /// and the whole thing read as cramped. Listings and Sublease are in the
    /// menu instead, which is what the site's own "More" does with its
    /// overflow.
    static let tabBar: [AppTab] = [.home, .roompal, .post, .messages, .profile]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:       return "Home"
        case .listings:   return "Listings"
        case .roompal:    return "RoomPal"
        case .sublease:   return "Sublease"
        case .post:       return "Post"
        // "Messages", not "Negotiator". The tab holds two halves: the AI
        // negotiator and real threads with landlords and roommates. Naming it
        // after one of them hides the other.
        case .messages:   return "Messages"
        case .profile:    return "Profile"
        }
    }

    /// SF Symbols only — no bundled artwork to keep in sync, and they adapt to
    /// weight, Dynamic Type and the tab bar's selected state for free.
    var symbol: String {
        switch self {
        case .home:       return "house.fill"
        case .listings:   return "building.2.fill"
        case .roompal:    return "person.2.fill"
        case .sublease:   return "calendar.badge.clock"
        case .post:       return "plus.circle.fill"
        case .messages:   return "bubble.left.and.text.bubble.right.fill"
        case .profile:    return "person.crop.circle.fill"
        }
    }

    var path: String {
        switch self {
        case .home:       return "index.html"
        case .listings:   return "listings.html"
        case .roompal:    return "roommate-matching.html"
        case .sublease:   return "sublease.html"
        case .post:       return "listings.html"
        case .messages:   return "ai-negotiator.html"
        case .profile:    return "profile.html"
        }
    }

    var url: URL { AppConfig.url(path) }

    /// Which tab owns an arbitrary site path, so a deep link or an in-page link
    /// lands in the right place instead of stranding the user in a tab whose
    /// title no longer describes what they are looking at.
    static func owning(path: String) -> AppTab? {
        let file = path.split(separator: "/").last.map(String.init) ?? path
        switch file {
        case "", "index.html":                  return .home
        // Only listings.html itself maps here — the Listings tab is native and
        // has no web view to hand a URL to. listing_details.html and
        // favorites.html are left unowned so they open in a web-capable tab.
        case "listings.html":                   return .listings
        case "ai-negotiator.html":              return .messages  // native; selecting it is the whole action
        case "roommate-matching.html":          return .roompal
        case "profile.html", "login.html", "signup.html", "forgot-password.html": return .profile
        default:                                return nil
        }
    }
}

/// Pages reachable from the native overflow menu — the app's equivalent of the
/// website's "More" dropdown, plus the two links Apple expects to be reachable
/// without an account (privacy policy and terms).
struct MoreDestination: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let symbol: String
    let path: String

    static let all: [MoreDestination] = [
        .init(title: "Sublease",      symbol: "calendar.badge.clock", path: "sublease.html"),
        .init(title: "Saved",         symbol: "heart.fill",           path: "favorites.html"),
        .init(title: "Legal Help",    symbol: "checkmark.shield.fill", path: "legal.html"),
        // No Pricing entry. The Pro plan is sold through Stripe on the website,
        // and App Store guideline 3.1.1 requires anything unlocking in-app
        // features to go through In-App Purchase. See AppConfig.blocksPurchasing,
        // which closes the route rather than just hiding this row.
        .init(title: "Support",       symbol: "lifepreserver.fill",   path: "support.html"),
        .init(title: "Privacy Policy", symbol: "hand.raised.fill",    path: "privacy-policy.html"),
        .init(title: "Terms of Service", symbol: "doc.text.fill",     path: "terms-of-service.html")
    ]
}
