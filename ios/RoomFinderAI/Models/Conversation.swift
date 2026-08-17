import Foundation

/// A thread with another person.
struct Conversation: Identifiable, Decodable, Hashable {

    /// Where the thread started. The label matters: someone with threads from
    /// three different parts of the product needs to know which is which
    /// before opening them.
    enum Source: String, Decodable {
        case listing
        case sublease
        case roommate

        var label: String {
            switch self {
            case .listing:  return "Listings"
            case .sublease: return "Sublease"
            case .roommate: return "RoomPal"
            }
        }

        var symbol: String {
            switch self {
            case .listing:  return "building.2.fill"
            case .sublease: return "calendar.badge.clock"
            case .roommate: return "person.2.fill"
            }
        }
    }

    let id: String
    let context: String?
    let otherParty: String?
    let subject: String?
    let lastMessage: String?
    let lastMessageAt: String?
    let unreadCount: Int?

    var source: Source { Source(rawValue: context ?? "listing") ?? .listing }

    /// The address is the only name we have for the other person, so the local
    /// part stands in — "leeroybentz" reads better than the full address.
    var displayName: String {
        guard let other = otherParty?.nilIfEmpty else { return "Someone" }
        return other.split(separator: "@").first.map(String.init) ?? other
    }

    var preview: String {
        lastMessage?.nilIfEmpty ?? "No messages yet"
    }

    var hasUnread: Bool { (unreadCount ?? 0) > 0 }

    /// Relative and short — an inbox wants "2h", not a date stamp.
    var timeText: String {
        guard let raw = lastMessageAt, let date = Self.parse(raw) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Postgres timestamps come back with or without fractional seconds
    /// depending on the row, and one ISO8601 formatter cannot take both.
    static func parse(_ raw: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: raw) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}

struct ConversationsResponse: Decodable {
    let success: Bool
    let data: [Conversation]?
}

/// One message inside a thread.
struct ChatMessage: Identifiable, Decodable, Hashable {
    let id: String
    let senderEmail: String?
    let content: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case senderEmail = "sender_email"
        case content
        case createdAt = "created_at"
    }

    func isMine(_ email: String?) -> Bool {
        guard let email, let sender = senderEmail else { return false }
        return sender.lowercased() == email.lowercased()
    }
}

struct ChatMessagesResponse: Decodable {
    let success: Bool
    let data: [ChatMessage]?
}
