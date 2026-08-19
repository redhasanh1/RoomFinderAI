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

    private let listing: Listing
    private var landlordEmail: String?

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
            phase = .failed("Sign in on the Profile tab first — messaging a landlord needs an account.")
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

            phase = awaitingOurReply ? .replying : .waitingForLandlord
        } catch {
            phase = .failed(readable(error))
        }
    }

    // MARK: - Continuing

    /// Re-reads the thread and answers if the landlord has said something.
    ///
    /// Pull-driven rather than a live subscription: the website keeps a socket
    /// open because its tab is already there, but an app that negotiates while
    /// closed needs push, and this at least means opening the screen catches up.
    func refresh() async {
        guard let me = CurrentUser.shared.email, conversationID != nil else { return }

        await loadMessages()
        if case .closed = phase { return }

        guard awaitingOurReply, let landlordLine = messages.last?.content else {
            phase = .waitingForLandlord
            return
        }

        phase = .replying
        do {
            let reply = try await composeReply(to: landlordLine)
            try await send(reply.message, as: me)
            await loadMessages()

            if reply.dealClosed {
                phase = .closed(price: reply.agreedPrice, viewing: reply.viewingWhen)
            } else {
                phase = .waitingForLandlord
            }
        } catch {
            phase = .failed(readable(error))
        }
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
            "userEmail": me
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
