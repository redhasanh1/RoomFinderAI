import Foundation

/// Negotiates with a real landlord, in the app.
///
/// The negotiator tab briefs an assistant about what someone wants. This is the
/// other thing entirely: it opens a thread with the person who owns the room,
/// sends messages on the tenant's behalf, and shows what was actually said.
/// That machinery only existed on the website, so the app could talk *about* a
/// room but never *for* it.
///
/// The wording and the tactics come from `/api/negotiate/reply`, the same
/// endpoint the site uses, so both clients argue the same way and the price
/// ceiling is enforced in one place.
@MainActor
final class LandlordNegotiationService: ObservableObject {

    enum Phase: Equatable {
        case idle
        case starting
        case waitingForLandlord
        case replying
        case closed(price: Int?, viewing: String?)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var conversationID: String?

    /// What the tenant is negotiating for. Sent with every turn so the model
    /// argues to the same limits the website would.
    var goals = NegotiationGoals()

    /// Held across suspension points so two callers cannot answer at once.
    private var isReplying = false

    let listing: Listing
    private var landlordEmail: String?

    var listingID: String { listing.id }

    init(listing: Listing) {
        self.listing = listing
        if let price = listing.price, price > 0 {
            goals.maxRent = price
            goals.targetRent = (price * 0.9).rounded()
        }
        if let city = listing.location?.nilIfEmpty { goals.city = city }
    }

    var canStart: Bool { conversationID == nil && phase == .idle }

    /// True when the last thing said came from the landlord, so there is
    /// something to answer.
    var awaitingOurReply: Bool {
        guard let last = messages.last else { return false }
        return !isOurs(last)
    }

    // MARK: - Starting

    /// Opens the thread and sends first contact.
    func start() async {
        guard let me = CurrentUser.shared.email else {
            phase = .failed("Sign in on the Profile tab first. Messaging a landlord needs an account.")
            return
        }

        phase = .starting
        do {
            let conversation = try await openConversation(listingID: listing.id, me: me)
            conversationID = conversation.id
            landlordEmail = conversation.landlordEmail

            await loadMessages()

            // A thread that already has messages is one being resumed, not
            // started, so first contact must not be sent again.
            if messages.isEmpty {
                let opener = try await composeReply(to: nil)
                try await send(opener.message, as: me)
                await loadMessages()
            }

            phase = .waitingForLandlord
            // A thread resumed mid-exchange may already be owed an answer.
            // Setting .replying here instead would park the screen on
            // "Writing a reply…" with nothing on its way to write one.
            if awaitingOurReply { await refresh() }
        } catch {
            phase = .failed(readable(error))
        }
    }

    /// Picks up an existing thread without saying anything.
    ///
    /// Called when the screen opens. Without it, coming back to a negotiation
    /// already in progress showed the "Start negotiating" primer, as if none of
    /// it had happened.
    func resume() async {
        guard let me = CurrentUser.shared.email, conversationID == nil else { return }
        guard let conversation = try? await openConversation(listingID: listing.id, me: me) else { return }

        conversationID = conversation.id
        landlordEmail = conversation.landlordEmail
        await loadMessages()

        // An empty thread is a negotiation that has not started, so leave the
        // primer and its button alone.
        guard !messages.isEmpty else { return }

        if let done = Self.savedOutcome(for: conversation.id) {
            phase = .closed(price: done.price, viewing: done.viewing)
            return
        }

        phase = .waitingForLandlord
        if awaitingOurReply { await refresh() }
    }

    /// Answers the landlord on its own for as long as the screen is open.
    ///
    /// A negotiation where the tenant has to keep pressing a button to find out
    /// whether anyone replied is the tenant doing the work again. This is still
    /// polling rather than a socket, because the app also has to catch up after
    /// being closed, and one path is easier to trust than two.
    func pollWhileWaiting() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            if Task.isCancelled { return }
            if case .closed = phase { return }
            if case .waitingForLandlord = phase { await refresh() }
        }
    }

    // MARK: - Continuing

    /// Re-reads the thread and answers if the landlord has said something.
    ///
    /// Re-reads the thread. The answering happens on the server.
    func refresh() async {
        guard CurrentUser.shared.email != nil, conversationID != nil else { return }

        // Two pollers watch the same thread — the campaign and whichever screen
        // is open — and one read at a time is enough.
        guard !isReplying else { return }
        isReplying = true
        defer { isReplying = false }

        await loadMessages()
        if case .closed = phase { return }

        // Replying is the server's job now.
        //
        // This used to compose and send the answer itself, which meant the
        // negotiation only moved while the app was open and on this screen:
        // lock the phone and the landlord's message sat there until you came
        // back. The server answers on a timer whether the app is running or
        // not, so this only reads the thread and reports where it got to.
        // Answering here as well would send two different replies to the same
        // landlord message.
        guard awaitingOurReply else {
            phase = .waitingForLandlord
            return
        }
        phase = .replying
    }

    // MARK: - Pieces

    private struct Conversation: Decodable {
        let id: String
        let landlordEmail: String?
    }

    private func openConversation(listingID: String, me: String) async throws -> Conversation {
        var request = URLRequest(url: AppConfig.url("api/conversations"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "listingId": listingID,
            "userEmail": me,
            // Marks the thread as one the AI runs, so the server stops pushing
            // the tenant about replies their negotiator answers by itself.
            // "Message host" leaves this off and keeps its notifications.
            "managedByAI": true,
            // Sent once, kept with the conversation. The server answers
            // landlords while this app is closed, and it cannot argue to a
            // ceiling it was never told.
            "goals": goals.negotiationPayload
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        struct Envelope: Decodable {
            let success: Bool
            let data: Conversation?
            let message: String?
        }
        let decoded = try? JSONDecoder().decode(Envelope.self, from: data)

        guard (200..<300).contains(http.statusCode), let conversation = decoded?.data else {
            // The server's own words: "that's your own listing" is far more
            // use than a status code.
            throw NegotiationFailure(message: decoded?.message ?? "Couldn't start that conversation.")
        }
        return conversation
    }

    private struct Reply: Decodable {
        let message: String
        let dealClosed: Bool
        let agreedPrice: Int?
        let viewingWhen: String?
    }

    /// Asks the server what to say next, given everything said so far.
    private func composeReply(to landlordLine: String?) async throws -> Reply {
        let history = messages.map { message -> [String: String] in
            ["sender": isOurs(message) ? "ai" : "landlord", "content": message.content ?? ""]
        }

        var body: [String: Any] = [
            "listing": [
                "price": listing.price ?? 0,
                "title": listing.title,
                "city": listing.location ?? ""
            ],
            "tenantParams": goals.negotiationPayload,
            "messageHistory": history
        ]
        body["lastLandlordMessage"] = landlordLine ?? ""

        var request = URLRequest(url: AppConfig.url("api/negotiate/reply"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The model reads the whole transcript; this is the slow call.
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw NegotiationFailure(
                message: code == 429
                    ? "Too many messages at once. Give it a moment."
                    : "The negotiator couldn't work out what to say (error \(code))."
            )
        }
        return try JSONDecoder().decode(Reply.self, from: data)
    }

    private func send(_ text: String, as me: String) async throws {
        guard let conversationID else { return }

        var request = URLRequest(url: AppConfig.url("api/messages"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "conversationId": conversationID,
            "userEmail": me,
            "content": text
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NegotiationFailure(message: "That message didn't send. Try again.")
        }
    }

    private func loadMessages() async {
        guard let conversationID, let me = CurrentUser.shared.email else { return }

        var components = URLComponents(url: AppConfig.url("api/messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "conversationId", value: conversationID),
            .init(name: "userEmail", value: me)
        ]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url) else { return }

        struct Envelope: Decodable { let data: [ChatMessage]? }
        if let decoded = try? JSONDecoder().decode(Envelope.self, from: data) {
            messages = decoded.data ?? []
        }
    }

    /// Ours covers both the tenant's own address and the AI's, since the
    /// website sends under one and the app under the other.
    private func isOurs(_ message: ChatMessage) -> Bool {
        let sender = (message.senderEmail ?? "").lowercased()
        if sender.contains("ai-negotiator") { return true }
        return sender == (CurrentUser.shared.email ?? "").lowercased()
    }

    // MARK: - Remembering the outcome

    /// Only `/api/negotiate/reply` can judge that a deal is done, and it judges
    /// from a message being sent. Reopening the screen sends nothing, so the
    /// verdict has to be kept here or the finished negotiation reads as still
    /// waiting on a landlord who has nothing left to say.
    private static func key(_ conversationID: String) -> String {
        "negotiationClosed.\(conversationID)"
    }

    private static func remember(price: Int?, viewing: String?, for conversationID: String) {
        var stored: [String: Any] = [:]
        if let price { stored["price"] = price }
        if let viewing { stored["viewing"] = viewing }
        UserDefaults.standard.set(stored, forKey: key(conversationID))
    }

    private static func savedOutcome(for conversationID: String) -> (price: Int?, viewing: String?)? {
        guard let stored = UserDefaults.standard.dictionary(forKey: key(conversationID)) else { return nil }
        return (stored["price"] as? Int, stored["viewing"] as? String)
    }

    private func readable(_ error: Error) -> String {
        if let failure = error as? NegotiationFailure { return failure.message }
        if let urlError = error as? URLError {
            return urlError.code == .notConnectedToInternet
                ? "You're offline. Reconnect and try again."
                : "Couldn't reach the negotiator (\(urlError.code.rawValue))."
        }
        return "Something went wrong. Try again."
    }
}

struct NegotiationFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
