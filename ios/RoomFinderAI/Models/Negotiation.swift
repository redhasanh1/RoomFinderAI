import Foundation

/// One turn in the tenant's conversation with their negotiator.
///
/// The negotiator works **for the tenant**. The tenant says what they are
/// after, the AI answers, finds rooms, and does the arguing with landlords on
/// their behalf. The tenant never speaks for the landlord.
struct NegotiationMessage: Identifiable, Hashable {
    enum Author: String, Hashable {
        /// The tenant using the app.
        case you
        /// The AI acting on the tenant's behalf.
        case negotiator

        var label: String {
            switch self {
            case .you:        return "You"
            case .negotiator: return "AI Negotiator"
            }
        }

        /// The API's role names for `conversationHistory`.
        var apiRole: String {
            switch self {
            case .you:        return "user"
            case .negotiator: return "assistant"
            }
        }
    }

    let id = UUID()
    let author: Author
    let text: String
    /// Rooms the AI found for this turn, shown as cards under its reply.
    var listings: [Listing] = []
    let sentAt: Date
}

/// What the tenant wants, sent with every turn so the AI answers against the
/// same targets instead of re-asking.
struct NegotiationGoals: Codable, Equatable {
    var maxRent: Double?
    var targetRent: Double?
    var city: String = ""
    var moveInDate: String = ""
    var leaseMonths: Int?
    var petFriendly = false
    var parkingNeeded = false
    var furnished = false
    var utilitiesIncluded = false
    var notes: String = ""

    /// Only the fields actually filled in — sending empty values would have the
    /// AI negotiate for things nobody asked about.
    var apiPayload: [String: Any] {
        var payload: [String: Any] = [:]
        if let maxRent { payload["maxRent"] = maxRent }
        if let targetRent { payload["targetRent"] = targetRent }
        if !city.isEmpty { payload["city"] = city }
        if !moveInDate.isEmpty { payload["moveInDate"] = moveInDate }
        if let leaseMonths { payload["leaseMonths"] = leaseMonths }
        if petFriendly { payload["petFriendly"] = true }
        if parkingNeeded { payload["parking"] = true }
        if furnished { payload["furnished"] = true }
        if utilitiesIncluded { payload["utilitiesIncluded"] = true }
        if !notes.isEmpty { payload["notes"] = notes }
        return payload
    }
}

/// `/api/chat` returns the reply plus what it understood the tenant to want.
struct AssistantReply: Decodable {
    let response: String
    let criteria: Criteria?

    struct Criteria: Decodable {
        let price: Double?
        let city: String?
        let bedrooms: Int?
        let intent: String?

        /// True when the AI decided this turn was a request to find rooms, so
        /// the app knows to run a search and show the results.
        var wantsSearch: Bool {
            intent?.lowercased() == "search" || city?.isEmpty == false
        }
    }
}
