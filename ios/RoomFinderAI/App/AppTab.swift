import Foundation

/// The five things people open the app to do. Everything else — Sublease,
/// Favourites, Pricing, Support, Legal — lives in the native overflow menu,
/// mirroring the website's "More" dropdown so the two never drift apart.
enum AppTab: String, CaseIterable, Identifiable, Codable {
    case home
    case listings
    /// The middle slot. Selecting it opens the post sheet and hands the
    /// selection straight back to the tab you were on — it is an action, not a
    /// place, which is why it has no screen.
    case post
    /// Both kinds of conversation: the AI negotiator, and real threads with
    /// landlords and roommates.
    case messages
    case profile

    /// The five slots, in order. RoomPal is reached from Home rather than
    /// occupying a slot: a sixth tab would push the bar into iOS's "More"
    /// overflow and bury a real tab behind a chevron.
    static let tabBar: [AppTab] = [.home, .listings, .post, .messages, .profile]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:       return "Home"
        case .listings:   return "Listings"
        case .post:       return "Post"
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
        case .post:       return "plus.circle.fill"
        case .messages:   return "bubble.left.and.text.bubble.right.fill"
        case .profile:    return "person.crop.circle.fill"
        }
    }

    var path: String {
        switch self {
        case .home:       return "index.html"
        case .listings:   return "listings.html"
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
        // RoomPal has no slot of its own; Home opens it.
        case "roommate-matching.html":          return .home
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
        .init(title: "Pricing",       symbol: "tag.fill",             path: "pricing.html"),
        .init(title: "Support",       symbol: "lifepreserver.fill",   path: "support.html"),
        .init(title: "Privacy Policy", symbol: "hand.raised.fill",    path: "privacy-policy.html"),
        .init(title: "Terms of Service", symbol: "doc.text.fill",     path: "terms-of-service.html")
    ]
}
