import Foundation

/// The tenant's conversation with their negotiator.
///
/// Talks to `/api/chat`, the same endpoint the website's negotiator page uses.
/// The AI works **for the tenant**: they say what they want, it answers, and
/// when it decides the turn was a search it finds rooms and hands them back to
/// be shown under the reply.
///
/// Arguing with landlords happens elsewhere — inside a real conversation with a
/// real landlord, through `/api/negotiate/reply`. This screen is where the
/// tenant briefs their negotiator, which is why nothing here ever asks the
/// tenant to type the landlord's words.
@MainActor
final class NegotiationService: ObservableObject {

    /// Shared, because a landlord can agree while the tenant is on any tab and
    /// the news has to land in this transcript wherever they are.
    static let shared = NegotiationService()

    @Published private(set) var messages: [NegotiationMessage] = []
    @Published private(set) var isThinking = false
    @Published var errorMessage: String?

    /// The campaign owns the goals: the tenant confirms them in one place and
    /// both the chat and every landlord thread argue to the same numbers.
    var goals: NegotiationGoals { NegotiationCampaign.shared.goals }

    var hasStarted: Bool { !messages.isEmpty }

    /// Says it in the chat, which is where the tenant asked for this in the
    /// first place.
    func announce(_ deal: NegotiationMessage.Deal) {
        var line = deal.price.map { "Good news, I secured it at $\($0) a month." }
            ?? "Good news, the landlord agreed."
        line += " That's \(deal.room)."
        if let saved = deal.savedPerMonth {
            line += " I got $\(saved) a month off the asking price, about $\(saved * 12) over a year."
        }
        if let viewing = deal.viewing {
            line += " Your viewing is booked for \(viewing). Go and look it over, and only sign if you are happy."
        }

        messages.append(NegotiationMessage(
            author: .negotiator,
            text: line,
            deal: deal,
            sentAt: Date()
        ))
    }

    func reset() {
        messages.removeAll()
        errorMessage = nil
    }

    /// Opens a negotiation about one specific room.
    ///
    /// Reached from "Negotiate this rent" on a listing. That button used to
    /// switch to this tab and nothing more, so the negotiator sat on its empty
    /// opening screen and the tap looked like it had failed.
    ///
    /// The first message is sent as if the tenant had typed it, so the AI
    /// answers about that room straight away. The room's own numbers seed the
    /// goals too, but that happens in the campaign, which owns them.
    func start(about listing: Listing) async {
        // Returning to this listing should not stack a second conversation on
        // the first.
        reset()

        var opener = "I'm interested in \(listing.title)"
        if let city = listing.location?.nilIfEmpty { opener += " in \(city)" }
        if let price = listing.price, price > 0 {
            opener += ", listed at $\(Int(price))/month. Can you help me get it for less?"
        } else {
            opener += ". Can you help me negotiate the rent?"
        }

        await send(opener)
    }

    /// Sends what the tenant said and appends the AI's reply.
    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(NegotiationMessage(author: .you, text: trimmed, sentAt: Date()))

        // "How many did we secure?" is a question about state this app holds
        // and the chat endpoint has never heard of, so asking the model gave a
        // confident nothing. Answered here, from the negotiations themselves.
        if let answer = statusAnswer(for: trimmed) {
            messages.append(NegotiationMessage(author: .negotiator, text: answer, sentAt: Date()))
            return
        }

        isThinking = true
        errorMessage = nil
        defer { isThinking = false }

        // Last ten turns, the same window the website sends, so both clients
        // give the model the same amount of context.
        let history = messages.suffix(10).map {
            ["role": $0.author.apiRole, "content": $0.text]
        }

        var body: [String: Any] = [
            "message": trimmed,
            "conversationHistory": history,
            "tenantGoals": goals.apiPayload
        ]
        if let email = CurrentUser.shared.email { body["userEmail"] = email }

        do {
            var request = URLRequest(url: AppConfig.url("api/chat"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 60
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200..<300).contains(http.statusCode) else {
                // These routes are rate limited; saying so beats "went wrong".
                errorMessage = http.statusCode == 429
                    ? "That's a lot of questions at once. Give it a moment and try again."
                    : "The negotiator couldn't reply (error \(http.statusCode))."
                return
            }

            let reply = try JSONDecoder().decode(AssistantReply.self, from: data)

            // An empty reply renders as a blank bubble, which reads as the app
            // breaking rather than the model having nothing to say.
            let spoken = reply.response.trimmingCharacters(in: .whitespacesAndNewlines)
            var message = NegotiationMessage(
                author: .negotiator,
                text: spoken.isEmpty
                    ? "Sorry, I didn't catch that. Could you say it another way?"
                    : spoken,
                sentAt: Date()
            )

            // When the AI read this as a search, actually run it — a reply
            // saying "let me find those" followed by nothing is the single
            // most annoying thing an assistant can do.
            if let criteria = reply.criteria, criteria.wantsSearch {
                let found = await searchRooms(criteria)
                message.listings = found
                messages.append(message)

                // Finding rooms and waiting to be told to act on them is the
                // tenant doing the work again. Everything that fits gets
                // contacted, which is the whole promise of a negotiator.
                await pursue(found)
                return
            }

            messages.append(message)
        } catch {
            // Name the failure. "Couldn't reply" covered a dead network, a
            // rejected request and a response we failed to read, which are
            // three different problems and gave no way to tell them apart from
            // the outside.
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    errorMessage = "You're offline. Reconnect to keep talking."
                case .timedOut:
                    errorMessage = "That took too long. Tap send to try again."
                default:
                    errorMessage = "Couldn't reach the negotiator (\(urlError.code.rawValue))."
                }
            } else if error is DecodingError {
                errorMessage = "The negotiator sent something I couldn't read. Try again."
                print("Negotiator decode failure: \(error)")
            } else {
                errorMessage = "The negotiator couldn't reply. Please try again."
                print("Negotiator failure: \(error)")
            }
        }
    }

    /// Answers "how's it going" from what is actually happening, or nil when
    /// the question was about something else.
    private func statusAnswer(for question: String) -> String? {
        let text = question.lowercased()

        let asksAboutProgress =
            text.contains("how many") || text.contains("how much")
            || text.contains("secure") || text.contains("status")
            || text.contains("how's it going") || text.contains("hows it going")
            || text.contains("any offers") || text.contains("any luck")
            || text.contains("any replies") || text.contains("heard back")
            || text.contains("what's happening") || text.contains("whats happening")
            || text.contains("did we get") || text.contains("did you get")
            || text.contains("update")

        let aboutNegotiations =
            text.contains("secure") || text.contains("negotiat") || text.contains("landlord")
            || text.contains("offer") || text.contains("deal") || text.contains("repl")
            || text.contains("room") || text.contains("place") || text.contains("it going")
            || text.contains("update") || text.contains("status")

        guard asksAboutProgress, aboutNegotiations else { return nil }

        let campaign = NegotiationCampaign.shared
        let running = campaign.active
        guard !running.isEmpty || !campaign.queued.isEmpty else {
            return "Nothing on the go yet. Tell me what you're looking for, or open a room and tap Negotiate this rent, and I'll start messaging landlords for you."
        }

        var lines: [String] = []

        let secured = campaign.secured
        if secured.isEmpty {
            lines.append(running.count == 1
                         ? "Nothing agreed yet. I'm negotiating on one room."
                         : "Nothing agreed yet. I'm negotiating on \(running.count) rooms.")
        } else {
            lines.append(secured.count == 1
                         ? "One secured so far."
                         : "\(secured.count) secured so far.")
            for negotiation in secured {
                guard case .closed(let price, let viewing) = negotiation.phase else { continue }
                var line = "\(negotiation.listing.title)"
                if let price { line += ", $\(price) a month" }
                if let asking = negotiation.listing.price.map(Int.init),
                   let price, asking > price {
                    line += " (that's $\(asking - price) under asking)"
                }
                if let viewing { line += ", viewing \(viewing)" }
                lines.append(line + ".")
            }
        }

        let waiting = running.filter { $0.phase == .waitingForLandlord }.count
        if waiting > 0 {
            lines.append(waiting == 1
                         ? "One landlord hasn't replied yet."
                         : "\(waiting) landlords haven't replied yet.")
        }
        if !campaign.queued.isEmpty {
            lines.append("\(campaign.queued.count) more lined up, waiting for you to confirm your goals.")
        }

        return lines.joined(separator: " ")
    }

    /// Hands what the chat found to the campaign and says what happened.
    ///
    /// Gated on confirmed goals: those numbers are what the AI argues to, and
    /// several landlords would be messaged on them at once. If they are not
    /// confirmed the chat asks rather than silently doing nothing, because a
    /// negotiator that finds rooms and then goes quiet reads as broken.
    private func pursue(_ found: [Listing]) async {
        guard !found.isEmpty else { return }

        let campaign = NegotiationCampaign.shared
        let fresh = found.filter { !campaign.isTaken($0.id) }
        guard !fresh.isEmpty else { return }

        guard campaign.goals.isConfirmed, campaign.goals.isUsable else {
            // Name the button that will actually work. Telling someone to tap
            // "These are right" when no budget is set sends them to a control
            // that can only open the form, which reads as the app ignoring them.
            let howMany = fresh.count == 1 ? "this one" : "all \(fresh.count) of these"
            let whatToDo = campaign.goals.isUsable
                ? "check your goals at the top of this screen and tap \u{201C}These are right\u{201D}"
                : "tap \u{201C}Set your budget\u{201D} at the top of this screen and tell me the most you'll pay"

            messages.append(NegotiationMessage(
                author: .negotiator,
                text: "I can start negotiating on \(howMany) right now. First, \(whatToDo), so I know what I'm allowed to agree to.",
                sentAt: Date()
            ))
            return
        }

        let started = await campaign.queueAndStart(fresh)
        guard started > 0 else { return }

        messages.append(NegotiationMessage(
            author: .negotiator,
            text: started == 1
                ? "I've messaged that landlord. You'll see the whole conversation under Negotiating above, and I'll keep answering them for you."
                : "I've messaged all \(started) landlords. You'll see each conversation under Negotiating above. I'll keep answering them for you and tell you who agrees.",
            sentAt: Date()
        ))
    }

    /// Runs the search the AI asked for. Failures are quiet on purpose: the
    /// reply still stands on its own, and an error bar about a search the user
    /// did not explicitly ask for would be noise.
    private func searchRooms(_ criteria: AssistantReply.Criteria) async -> [Listing] {
        var components = URLComponents(
            url: AppConfig.url("api/listings/search"),
            resolvingAgainstBaseURL: false
        )!

        var items: [URLQueryItem] = []
        if let city = criteria.city, !city.isEmpty { items.append(.init(name: "q", value: city)) }
        if let price = criteria.price, price > 0 { items.append(.init(name: "max_price", value: String(Int(price)))) }
        if let bedrooms = criteria.bedrooms, bedrooms > 0 { items.append(.init(name: "bedrooms", value: String(bedrooms))) }
        components.queryItems = items.isEmpty ? nil : items

        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(ListingsResponse.self, from: data) else {
            return []
        }

        // Capped at five: this is a chat, and twenty cards under one reply
        // buries the conversation. The Listings tab is there for the full set.
        return (decoded.data ?? [])
            .filter { ($0.available ?? true) && !$0.title.isEmpty }
            .prefix(5)
            .map { $0 }
    }
}
