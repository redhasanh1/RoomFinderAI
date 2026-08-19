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

    /// A message announcing a closed deal reads differently from a reply: it is
    /// the outcome the whole conversation was for, so it gets its own shape in
    /// the transcript rather than being one more grey bubble to scroll past.
    struct Deal: Hashable {
        let room: String
        let price: Int?
        let asking: Int?
        let viewing: String?

        var savedPerMonth: Int? {
            guard let price, let asking, asking > price else { return nil }
            return asking - price
        }
    }

    let id = UUID()
    let author: Author
    let text: String
    /// Set when this message is the announcement of a landlord agreeing.
    var deal: Deal?
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

    /// How hard to push. The website has had this since the start and the app
    /// did not, so every negotiation here argued at one fixed setting no matter
    /// what the tenant wanted.
    enum Assertiveness: String, Codable, CaseIterable, Identifiable {
        case gentle, firm, aggressive
        var id: String { rawValue }

        var label: String {
            switch self {
            case .gentle:     return "Gentle"
            case .firm:       return "Firm"
            case .aggressive: return "Aggressive"
            }
        }

        var explanation: String {
            switch self {
            case .gentle:     return "Asks politely, accepts a small discount, keeps things warm."
            case .firm:       return "Holds your number, pushes back once or twice."
            case .aggressive: return "Pushes hard, walks away from bad offers."
            }
        }

        /// The wording `/api/negotiate/reply` expects.
        var apiValue: String {
            switch self {
            case .gentle:     return "polite and easygoing"
            case .firm:       return "firm but polite"
            case .aggressive: return "very assertive, pushes hard on price"
            }
        }
    }

    enum Tone: String, Codable, CaseIterable, Identifiable {
        case friendly, neutral, professional
        var id: String { rawValue }

        var label: String {
            switch self {
            case .friendly:     return "Friendly"
            case .neutral:      return "Neutral"
            case .professional: return "Professional"
            }
        }
    }

    var assertiveness: Assertiveness = .firm
    var tone: Tone = .friendly

    /// Your side of the case: what makes you worth a discount.
    var employment: String = ""
    var occupants: String = ""
    var pets: String = ""
    var nonSmoker = false

    /// Concessions worth asking for when the rent itself will not move.
    var askLowerDeposit = false
    var askFirstMonthFree = false

    /// When the tenant last confirmed these, or nil if they never have.
    ///
    /// Nothing is sent to a landlord on unconfirmed goals. The website has the
    /// same gate — its panel calls it "lock in" — and it matters more here,
    /// because the app contacts several landlords at once and a wrong budget
    /// would go out several times before anyone noticed.
    var confirmedAt: Date?

    var isConfirmed: Bool { confirmedAt != nil }

    /// The least the tenant has to say before the AI can argue for them.
    var isUsable: Bool { (maxRent ?? 0) > 0 }

    /// A short line for the banner, so the tenant can check the numbers
    /// without reopening the form.
    var summary: String {
        var parts: [String] = []
        if let maxRent { parts.append("up to $\(Int(maxRent))/mo") }
        if let targetRent { parts.append("aiming for $\(Int(targetRent))") }
        if !city.isEmpty { parts.append(city) }
        if let leaseMonths { parts.append("\(leaseMonths) months") }
        if !moveInDate.isEmpty { parts.append("from \(moveInDate)") }
        parts.append(assertiveness.label.lowercased())
        return parts.isEmpty ? "No goals set yet" : parts.joined(separator: " · ")
    }

    // MARK: - Kept between launches

    /// Filed under the signed-in address: a shared device must not negotiate
    /// for one person using the last person's budget.
    private static func key(for email: String?) -> String {
        "negotiationGoals.\((email ?? "anonymous").lowercased())"
    }

    static func load(for email: String?) -> NegotiationGoals {
        guard let data = UserDefaults.standard.data(forKey: key(for: email)),
              let decoded = try? JSONDecoder().decode(NegotiationGoals.self, from: data)
        else { return NegotiationGoals() }
        return decoded
    }

    func save(for email: String?) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key(for: email))
    }

    /// Only the fields actually filled in — sending empty values would have the
    /// AI negotiate for things nobody asked about.
    /// The same goals under the names `/api/negotiate/reply` expects.
    ///
    /// That endpoint owns the price ceiling, so what it is told here decides
    /// what the AI is allowed to agree to. `monthly_budget` in particular is a
    /// hard limit: it will not commit above it.
    var negotiationPayload: [String: Any] {
        var payload: [String: Any] = [:]
        if let maxRent { payload["monthly_budget"] = maxRent }
        if let maxRent, let targetRent, maxRent > targetRent {
            payload["target_reduction"] = maxRent - targetRent
        }
        if !moveInDate.isEmpty { payload["movein_date"] = moveInDate }
        if let leaseMonths { payload["lease_length"] = "\(leaseMonths) months" }
        // "pets" is what the tenant has, not what the room allows — the model
        // needs to know whether it has to ask for permission.
        if !pets.isEmpty {
            payload["pets"] = pets
        } else {
            payload["pets"] = petFriendly ? "yes" : "none"
        }

        var mustHaves: [String] = []
        if parkingNeeded { mustHaves.append("parking") }
        if furnished { mustHaves.append("furnished") }
        if nonSmoker { mustHaves.append("non-smoking household") }
        if !mustHaves.isEmpty { payload["must_haves"] = mustHaves }

        if utilitiesIncluded { payload["ask_utilities_included"] = true }
        if askLowerDeposit { payload["ask_lower_deposit"] = true }
        if askFirstMonthFree { payload["ask_first_month_free"] = true }
        if !occupants.isEmpty { payload["occupants"] = occupants }
        if !notes.isEmpty { payload["notes"] = notes }

        // How hard to push, and how it sounds doing it. Defaulted rather than
        // left blank: an AI with no position hedges every sentence and gets
        // nothing off the rent.
        payload["employment"] = employment.isEmpty
            ? "stable full-time work, good references"
            : employment
        payload["assertiveness"] = assertiveness.apiValue
        payload["tone"] = tone.rawValue
        return payload
    }

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
