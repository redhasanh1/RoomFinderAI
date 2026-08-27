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
        // Checked first, and answered here rather than by the model. "Stop
        // messaging them" went to the chat endpoint, which has no power to
        // stop anything, so it replied agreeably and the AI carried on
        // arguing with landlords — the worst possible answer to that sentence.
        if let answer = stopAnswer(for: trimmed) {
            messages.append(NegotiationMessage(author: .negotiator, text: answer, sentAt: Date()))
            return
        }

        // Picking from what was just offered. "Only the top one" went to the
        // chat endpoint, which cannot narrow anything, and the model answered
        // "I will start negotiating on the top rental for you" — a promise it
        // had no way to keep. Nothing was messaged and nothing was chosen.
        if let answer = narrowAnswer(for: trimmed) {
            messages.append(NegotiationMessage(author: .negotiator, text: answer, sentAt: Date()))
            return
        }

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
            var request = AppConfig.request("api/chat")
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 60
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200..<300).contains(http.statusCode) else {
                // The server says which limit was hit and whether waiting will
                // help. Flattening every 429 into "give it a moment" told
                // people to wait out a cap that resets next month.
                struct Refusal: Decodable { let message: String?; let error: String? }
                let stated = (try? JSONDecoder().decode(Refusal.self, from: data))?.message

                errorMessage = stated
                    ?? (http.statusCode == 429
                        ? "That's a lot of questions at once. Give it a moment and try again."
                        : "The negotiator couldn't reply (error \(http.statusCode)).")
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
            // What they just said becomes the goals.
            //
            // Someone who types "a place in Toronto under 2200" has already
            // given the budget and the city. Making them open a form and type
            // both again is the app asking twice for the same thing. The purple
            // button is there to confirm, not to collect.
            if let criteria = reply.criteria {
                applyToGoals(criteria, saidBy: trimmed)
            }

            if let criteria = reply.criteria, criteria.wantsSearch {
                let found = await searchRooms(criteria)
                message.listings = found
                messages.append(message)

                // Finding rooms and waiting to be told to act on them is the
                // tenant doing the work again. Everything that fits gets
                // contacted, which is the whole promise of a negotiator.
                await propose(found)
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

    /// Calls the negotiations off when asked to, or nil when that was not the
    /// ask.
    ///
    /// Deliberately narrow. "Stop" has to mean stop, but "don't stop until you
    /// get a good price" must not, so a negative in front of the verb rules the
    /// whole sentence out.
    private func stopAnswer(for question: String) -> String? {
        let text = question.lowercased()

        let saysStop = ["stop", "cancel", "call it off", "abort", "quit",
                        "give up", "leave it", "forget it", "never mind",
                        "nevermind", "pull out", "back off", "hold off",
                        "stand down"].contains { text.contains($0) }
        guard saysStop else { return nil }

        // "don't stop", "no need to cancel", "why did you stop"
        let negated = ["don't stop", "dont stop", "do not stop", "never stop",
                       "don't cancel", "dont cancel", "no need to stop",
                       "why did you stop", "did you stop", "why stop",
                       "shouldn't stop", "keep going"].contains { text.contains($0) }
        guard !negated else { return nil }

        let campaign = NegotiationCampaign.shared
        let running = campaign.active
        guard !running.isEmpty || !campaign.queued.isEmpty else {
            awaitingConfirmation = []
            return "Nothing is running, so there's nothing to stop. Tell me when you want me to start again."
        }

        // Naming one of them. "Stop only the first one" used to fall through to
        // the chat endpoint, which cannot stop anything, so it sat thinking and
        // then answered agreeably while every negotiation carried on.
        if let picked = Self.singledOut(in: text, from: running) {
            campaign.stop(listingID: picked.listingID)
            return "Stopped. I won't reply to \(picked.listing.title) again. The others are still going, and that conversation is still under Direct Messages if you want to take it over."
        }

        let meansEverything = ["all", "everything", "every", "both", "them all",
                               "the lot", "each"].contains { text.contains($0) }

        // One running and no room named: they can only have meant that one.
        if !meansEverything, running.count > 1, Self.namesSomeSubset(text) {
            let list = running.enumerated()
                .map { "\($0.offset + 1). \($0.element.listing.title)" }
                .joined(separator: "\n")
            return "Which one? Say the number or the name and I'll stop just that one, or say stop all.\n\n\(list)"
        }

        let stopped = campaign.stopAll()
        awaitingConfirmation = []
        return stopped == 1
            ? "Stopped. I won't reply to that landlord again. The conversation is still there under Direct Messages if you want to take it over yourself."
            : "Stopped all \(stopped). I won't reply to any of those landlords again. The conversations are still there under Direct Messages if you want to take any of them over yourself."
    }

    /// Narrows what is waiting on a yes, when someone says which of them they
    /// meant. Nil when they were talking about something else.
    private func narrowAnswer(for question: String) -> String? {
        guard awaitingConfirmation.count > 1 else { return nil }
        let text = question.lowercased()

        let picksSome = ["only", "just", "top one", "first one", "that one",
                         "this one", "cheapest", "cheaper", "dearest",
                         "most expensive", "pick", "choose", "instead of"]
            .contains { text.contains($0) }
        let picksAll = ["all of them", "both", "everything", "all three",
                        "all of these", "keep both", "keep all"]
            .contains { text.contains($0) }
        guard picksSome || picksAll else { return nil }

        if picksAll, !picksSome {
            let count = awaitingConfirmation.count
            return "All \(count) then. Tap \u{201C}These are right\u{201D} at the top and I'll message every one of them."
        }

        guard let chosen = pickedRoom(in: text) else {
            let list = awaitingConfirmation.enumerated()
                .map { "\($0.offset + 1). \($0.element.title) \u{2014} \($0.element.priceText)" }
                .joined(separator: "\n")
            return "Which one? Say the number or the name.\n\n\(list)"
        }

        awaitingConfirmation = [chosen]
        return "Just \(chosen.title) then, at \(chosen.priceText). Tap \u{201C}These are right\u{201D} at the top and I'll message them. I won't contact the others."
    }

    /// The room a sentence points at: by position, by price, or by name.
    private func pickedRoom(in text: String) -> Listing? {
        let rooms = awaitingConfirmation
        guard !rooms.isEmpty else { return nil }

        // "Top" means the one at the top of the list they are looking at, which
        // is the first, not the dearest.
        let positions: [(String, Int)] = [
            ("top", 0), ("first", 0), ("1st", 0), ("number 1", 0), ("number one", 0),
            ("second", 1), ("2nd", 1), ("number 2", 1), ("number two", 1),
            ("third", 2), ("3rd", 2), ("number 3", 2), ("number three", 2)
        ]
        for (word, index) in positions where text.contains(word) {
            return index < rooms.count ? rooms[index] : nil
        }
        if text.contains("last") || text.contains("bottom") { return rooms.last }

        if text.contains("cheapest") || text.contains("cheaper") {
            return rooms.min { ($0.price ?? .greatestFiniteMagnitude) < ($1.price ?? .greatestFiniteMagnitude) }
        }
        if text.contains("dearest") || text.contains("most expensive") {
            return rooms.max { ($0.price ?? -1) < ($1.price ?? -1) }
        }

        // Longest title first, so a short one cannot swallow a longer match.
        for room in rooms.sorted(by: { $0.title.count > $1.title.count }) {
            let title = room.title.lowercased()
            if !title.isEmpty, text.contains(title) { return room }
        }
        return nil
    }

    /// The one negotiation a sentence points at, by position or by name.
    private static func singledOut(in text: String,
                                   from running: [LandlordNegotiationService]) -> LandlordNegotiationService? {
        guard !running.isEmpty else { return nil }

        let positions: [(String, Int)] = [
            ("first", 0), ("1st", 0), ("number 1", 0), ("number one", 0),
            ("second", 1), ("2nd", 1), ("number 2", 1), ("number two", 1),
            ("third", 2), ("3rd", 2), ("number 3", 2), ("number three", 2),
            ("fourth", 3), ("4th", 3), ("fifth", 4), ("5th", 4)
        ]
        for (word, index) in positions where text.contains(word) {
            return index < running.count ? running[index] : nil
        }
        if text.contains("last") { return running.last }

        // By name. Longest title first, so "Bright 1 Bed" cannot swallow a
        // match for "Bright 1 Bed on College St".
        let byLength = running.sorted { $0.listing.title.count > $1.listing.title.count }
        for negotiation in byLength {
            let title = negotiation.listing.title.lowercased()
            if !title.isEmpty, text.contains(title) { return negotiation }
        }
        return nil
    }

    /// Words that say "not all of them" without saying which.
    private static func namesSomeSubset(_ text: String) -> Bool {
        ["only", "just", "one of", "that one", "this one", "the other"]
            .contains { text.contains($0) }
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

    /// Copies what the AI understood into the goals the negotiator argues from.
    ///
    /// Any change withdraws the tenant's confirmation, so a new budget has to be
    /// confirmed before anything goes out on it. Saying a lower number and
    /// having the AI keep arguing to the old one is the worst thing this could
    /// do.
    private func applyToGoals(_ criteria: AssistantReply.Criteria, saidBy text: String) {
        let campaign = NegotiationCampaign.shared
        var goals = campaign.goals
        let before = goals

        // The model is the first source and the sentence itself is the second.
        // It reads "Toronto" reliably and drops the number often enough that
        // people were told their goals had been filled in from what they said
        // while the bar above still read "No budget set yet" — the app calling
        // itself a liar in two lines of the same screen.
        if let price = criteria.price ?? Self.budget(in: text), price > 0 {
            goals.maxRent = price
            // A first ask under the ceiling. Opening at the limit concedes the
            // negotiation before it starts.
            goals.targetRent = (price * 0.9).rounded()
        }
        if let city = criteria.city?.nilIfEmpty {
            goals.city = city
        }

        var changed = goals
        changed.confirmedAt = before.confirmedAt
        guard changed != before else { return }

        goals.confirmedAt = nil
        campaign.goals = goals
        campaign.saveGoals()
    }

    /// Rooms the chat found and could not contact yet, because the goals were
    /// still waiting to be confirmed. Held so that tapping "These are right"
    /// finishes the job instead of leaving three rooms sitting on screen with
    /// nothing happening to them.
    private var awaitingConfirmation: [Listing] = []

    /// Called the moment the goals are confirmed.
    func startPending() async {
        let rooms = awaitingConfirmation
        awaitingConfirmation = []
        guard !rooms.isEmpty else { return }
        await contact(rooms)
    }

    /// A rent out of a sentence someone typed.
    ///
    /// Handles "$2,200", "under 2200" and "2.2k". Numbers attached to rooms
    /// are skipped: "2 bed" is not a budget, and reading it as one sets a
    /// ceiling of two dollars.
    static func budget(in text: String) -> Double? {
        let lowered = text.lowercased()
        let pattern = #"\$?\s?(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)\s?(k\b)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(lowered.startIndex..., in: lowered)
        var best: Double?

        for match in regex.matches(in: lowered, range: range) {
            guard let digits = Range(match.range(at: 1), in: lowered) else { continue }

            var value = Double(lowered[digits].replacingOccurrences(of: ",", with: "")) ?? 0
            if match.range(at: 2).location != NSNotFound { value *= 1000 }

            // What follows decides whether this was money at all.
            if let whole = Range(match.range, in: lowered) {
                let rest = lowered[whole.upperBound...].prefix(12)
                let noise = ["bed", "br", "bath", "room", "person", "people", "month", "week", "am", "pm"]
                if noise.contains(where: { rest.trimmingCharacters(in: .whitespaces).hasPrefix($0) }) { continue }
            }

            // A plausible monthly rent. Below this it is a bedroom count or a
            // date; above it, a salary or a phone number.
            guard value >= 300, value <= 20_000 else { continue }
            best = max(best ?? 0, value)
        }
        return best
    }

    /// Hands what the chat found to the campaign and says what happened.
    ///
    /// Gated on confirmed goals: those numbers are what the AI argues to, and
    /// several landlords would be messaged on them at once. If they are not
    /// confirmed the chat asks rather than silently doing nothing, because a
    /// negotiator that finds rooms and then goes quiet reads as broken.
    /// Shows what was found and asks before contacting anyone.
    ///
    /// It used to message every landlord the moment the goals happened to be
    /// confirmed — and a confirmation from an earlier round counted, so a new
    /// search contacted strangers with no tap at all. Messaging a landlord is
    /// not undoable and it goes out under the tenant's name, so every batch is
    /// asked about on its own.
    private func propose(_ found: [Listing]) async {
        guard !found.isEmpty else { return }

        let campaign = NegotiationCampaign.shared
        let me = (CurrentUser.shared.email ?? "").lowercased()

        // Three reasons a found room cannot be acted on, and each one used to
        // end in the same silence: rooms appeared in the chat and nothing was
        // ever said about them again. Silence reads as the app ignoring you.
        let mine = found.filter { ($0.userEmail ?? "").lowercased() == me }
        let running = found.filter { campaign.isTaken($0.id) }
        let fresh = found.filter {
            !campaign.isTaken($0.id) && ($0.userEmail ?? "").lowercased() != me
        }

        guard !fresh.isEmpty else {
            let reason: String
            if !running.isEmpty && mine.isEmpty {
                reason = running.count == 1
                    ? "I'm already negotiating on that one. You can read it under Negotiating above."
                    : "I'm already negotiating on all \(running.count) of those. You can read them under Negotiating above."
            } else if !mine.isEmpty && running.isEmpty {
                reason = mine.count == 1
                    ? "That one is your own listing, so there's nobody for me to message."
                    : "Those are your own listings, so there's nobody for me to message."
            } else {
                reason = "There's nothing new for me to do with those: some I'm already negotiating on, and the rest are your own listings."
            }
            messages.append(NegotiationMessage(author: .negotiator, text: reason, sentAt: Date()))
            return
        }

        // Nothing said a number, but they are looking at rooms with prices on
        // them. Proposing the dearest as the ceiling gives them something to
        // check and agree to, which is the whole job of the purple button: it
        // confirms, it does not collect.
        var goals = campaign.goals
        if !goals.isUsable, let proposed = Self.ceiling(from: fresh) {
            goals.maxRent = proposed
            goals.targetRent = (proposed * 0.9).rounded()
        }
        // This batch gets its own yes. Whatever was agreed to last time was
        // agreed to about different rooms.
        goals.confirmedAt = nil
        campaign.goals = goals
        campaign.saveGoals()

        awaitingConfirmation = fresh

        let howMany = fresh.count == 1 ? "this one" : "all \(fresh.count) of these"
        let whatToDo = campaign.goals.isUsable
            ? "check the goals at the top of this screen, I've filled them in from what you said, and tap \u{201C}These are right\u{201D}"
            : "tap \u{201C}Set your budget\u{201D} at the top and tell me your ceiling"

        messages.append(NegotiationMessage(
            author: .negotiator,
            text: "I can start negotiating on \(howMany) as soon as you say go. First, \(whatToDo), and I'll message them.",
            sentAt: Date()
        ))
    }

    /// Actually contacts them. Only ever reached from the confirm button.
    private func contact(_ rooms: [Listing]) async {
        let campaign = NegotiationCampaign.shared
        let started = await campaign.queueAndStart(rooms)
        guard started > 0 else { return }

        messages.append(NegotiationMessage(
            author: .negotiator,
            text: started == 1
                ? "I've messaged that landlord. You'll see the whole conversation under Negotiating above, and I'll keep answering them for you."
                : "I've messaged all \(started) landlords. You'll see each conversation under Negotiating above. I'll keep answering them for you and tell you who agrees.",
            sentAt: Date()
        ))
    }

    /// A ceiling worth proposing, from rooms already on screen.
    ///
    /// The dearest of them, because they asked to negotiate on all of them and
    /// a ceiling under the most expensive one rules it out before anyone has
    /// said a word. Rounded up so the number reads like a decision rather than
    /// a scrape.
    private static func ceiling(from rooms: [Listing]) -> Double? {
        let prices = rooms.compactMap { $0.price }.filter { $0 > 0 }
        guard let dearest = prices.max() else { return nil }
        return (dearest / 50).rounded(.up) * 50
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
