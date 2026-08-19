import Foundation

/// A sublease someone is offering, or looking for.
///
/// One table serves both directions, told apart by `type`: a "transfer" is
/// somebody handing over a place they hold, a "seeking" is somebody after one.
/// They read completely differently to a person, so the screen says which.
struct SubleaseRequest: Identifiable, Decodable, Hashable {

    enum Kind: String, Decodable {
        case transfer
        case seeking

        var label: String {
            switch self {
            case .transfer: return "Offering"
            case .seeking:  return "Looking"
            }
        }

        var symbol: String {
            switch self {
            case .transfer: return "arrow.right.circle.fill"
            case .seeking:  return "magnifyingglass.circle.fill"
            }
        }
    }

    let id: String
    let type: String?
    let title: String?
    let description: String?
    let city: String?
    let state: String?
    let rentAmount: Double?
    let minBudget: Double?
    let maxBudget: Double?
    let preferredMoveIn: String?
    let preferredMoveOut: String?
    let availableFrom: String?
    let availableUntil: String?
    let durationMonths: Int?
    let propertyType: String?
    let bedrooms: Int?
    let furnished: Bool?
    let utilitiesIncluded: Bool?
    let petFriendly: Bool?
    let amenities: [String]?
    let urgencyLevel: Int?
    let userEmail: String?

    enum CodingKeys: String, CodingKey {
        case id, type, title, description, city, state, amenities, bedrooms, furnished
        case rentAmount = "rent_amount"
        case minBudget = "min_budget"
        case maxBudget = "max_budget"
        case preferredMoveIn = "preferred_move_in"
        case preferredMoveOut = "preferred_move_out"
        case availableFrom = "available_from"
        case availableUntil = "available_until"
        case durationMonths = "duration_months"
        case propertyType = "property_type"
        case utilitiesIncluded = "utilities_included"
        case petFriendly = "pet_friendly"
        case urgencyLevel = "urgency_level"
        case userEmail = "user_email"
    }

    var kind: Kind { Kind(rawValue: type ?? "seeking") ?? .seeking }

    var displayTitle: String {
        title?.nilIfEmpty ?? (kind == .transfer ? "Sublease available" : "Looking for a sublease")
    }

    var place: String {
        [city?.nilIfEmpty, state?.nilIfEmpty].compactMap { $0 }.joined(separator: ", ")
    }

    /// One line covering both directions: what it costs, or what they'll pay.
    var moneyLine: String {
        if let rent = rentAmount, rent > 0 { return "$\(Int(rent))/mo" }
        switch (minBudget, maxBudget) {
        case let (min?, max?) where min > 0 && max > 0: return "$\(Int(min)) to $\(Int(max))/mo"
        case let (_, max?) where max > 0:               return "up to $\(Int(max))/mo"
        case let (min?, _) where min > 0:               return "from $\(Int(min))/mo"
        default:                                        return "Budget not stated"
        }
    }

    /// The dates that matter, whichever pair the row happens to carry.
    var datesLine: String? {
        let from = (availableFrom ?? preferredMoveIn)?.nilIfEmpty
        let to = (availableUntil ?? preferredMoveOut)?.nilIfEmpty
        let start = from.flatMap(Self.pretty)
        let end = to.flatMap(Self.pretty)

        switch (start, end) {
        case let (s?, e?): return "\(s) to \(e)"
        case let (s?, nil): return "From \(s)"
        case let (nil, e?): return "Until \(e)"
        default:
            guard let months = durationMonths, months > 0 else { return nil }
            return "\(months) month\(months == 1 ? "" : "s")"
        }
    }

    var detailLine: String {
        var parts: [String] = []
        if let propertyType = propertyType?.nilIfEmpty { parts.append(propertyType.capitalized) }
        if let bedrooms, bedrooms > 0 { parts.append("\(bedrooms) bed") }
        if furnished == true { parts.append("Furnished") }
        if utilitiesIncluded == true { parts.append("Utilities included") }
        if petFriendly == true { parts.append("Pets ok") }
        return parts.joined(separator: " · ")
    }

    /// Urgency is 1 to 5 in the data. Only the top of that range is worth
    /// shouting about; anything less is noise on a card.
    var isUrgent: Bool { (urgencyLevel ?? 0) >= 4 }

    private static func pretty(_ raw: String) -> String? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        guard let date = iso.date(from: String(raw.prefix(10))) else { return nil }

        let out = DateFormatter()
        out.dateFormat = "d MMM"
        return out.string(from: date)
    }
}

struct SubleaseSearchResponse: Decodable {
    let requests: [SubleaseRequest]?
}
