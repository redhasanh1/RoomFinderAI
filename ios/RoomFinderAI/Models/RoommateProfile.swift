import Foundation

/// Someone on the roommate marketplace — either looking for a room, or with a
/// room to share.
struct RoommateProfile: Identifiable, Decodable, Hashable {

    enum Kind: String, Decodable {
        /// Looking for a room.
        case seeking
        /// Has a spot to fill.
        case hasSpot = "has_spot"

        var label: String {
            switch self {
            case .seeking: return "Looking for a room"
            case .hasSpot: return "Has a room"
            }
        }

        var symbol: String {
            switch self {
            case .seeking: return "magnifyingglass"
            case .hasSpot: return "house.fill"
            }
        }
    }

    let id: String
    let name: String?
    let userType: String?
    let budgetMin: Int?
    let budgetMax: Int?
    let preferredAreas: [String]?
    let moveInDate: String?
    let bio: String?
    let avatarUrl: String?
    let roomRent: Int?
    let roomLocation: String?
    let roomDescription: String?
    let roomPhotos: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, bio
        case userType = "user_type"
        case budgetMin = "budget_min"
        case budgetMax = "budget_max"
        case preferredAreas = "preferred_areas"
        case moveInDate = "move_in_date"
        case avatarUrl = "avatar_url"
        case roomRent = "room_rent"
        case roomLocation = "room_location"
        case roomDescription = "room_description"
        case roomPhotos = "room_photos"
    }

    var kind: Kind { Kind(rawValue: userType ?? "seeking") ?? .seeking }

    var displayName: String { name?.nilIfEmpty ?? "Someone" }

    /// Seed rows carry a `[seed]` marker that must never reach a real person.
    var cleanBio: String? {
        bio?.replacingOccurrences(of: "[seed]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    /// What they're offering, or what they can pay. Only sensible values are
    /// shown: one seed row has a budget of $23–$333,333, which is noise.
    var budgetText: String {
        if kind == .hasSpot, let rent = roomRent, rent > 0 {
            return "$\(rent)/mo"
        }
        guard let low = budgetMin, let high = budgetMax,
              low > 0, high > low, high < 20_000 else {
            if let high = budgetMax, high > 0, high < 20_000 { return "Up to $\(high)/mo" }
            return "Budget not set"
        }
        return "$\(low)–$\(high)/mo"
    }

    var locationText: String {
        if let room = roomLocation?.nilIfEmpty { return room }
        if let areas = preferredAreas, !areas.isEmpty { return areas.joined(separator: ", ") }
        return "Anywhere"
    }

    var avatarURL: URL? {
        guard let avatarUrl, !avatarUrl.isEmpty else { return nil }
        return URL(string: avatarUrl)
    }

    /// Initials for the fallback avatar, so a profile without a photo still
    /// looks like a person rather than a broken image.
    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }
}

struct RoommateProfilesResponse: Decodable {
    let success: Bool
    let data: [RoommateProfile]?
    let message: String?
}
