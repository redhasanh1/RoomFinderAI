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

    @Published private(set) var messages: [NegotiationMessage] = []
    @Published private(set) var isThinking = false
    @Published var errorMessage: String?

    var goals = NegotiationGoals()

    var hasStarted: Bool { !messages.isEmpty }

    func reset() {
        messages.removeAll()
        errorMessage = nil
    }

    /// Sends what the tenant said and appends the AI's reply.
    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(NegotiationMessage(author: .you, text: trimmed, sentAt: Date()))

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

            var message = NegotiationMessage(
                author: .negotiator,
                text: reply.response,
                sentAt: Date()
            )

            // When the AI read this as a search, actually run it — a reply
            // saying "let me find those" followed by nothing is the single
            // most annoying thing an assistant can do.
            if let criteria = reply.criteria, criteria.wantsSearch {
                message.listings = await searchRooms(criteria)
            }

            messages.append(message)
        } catch {
            errorMessage = (error as? URLError)?.code == .notConnectedToInternet
                ? "You're offline. Reconnect to keep talking."
                : "The negotiator couldn't reply. Please try again."
        }
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
