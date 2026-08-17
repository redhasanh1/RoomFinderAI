import Foundation

/// The inbox and the threads inside it.
///
/// Everything goes through the backend rather than Supabase directly: the app
/// has no database key, and the server checks the caller is actually in the
/// thread before returning or writing anything.
@MainActor
final class MessagingService: ObservableObject {

    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoadedOnce = false
    @Published var errorMessage: String?

    func loadConversations() async {
        guard let email = CurrentUser.email else {
            conversations = []
            hasLoadedOnce = true
            return
        }

        isLoading = true
        defer { isLoading = false; hasLoadedOnce = true }

        var components = URLComponents(url: AppConfig.url("api/conversations"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "userEmail", value: email)]

        do {
            var request = URLRequest(url: components.url!)
            request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            conversations = try JSONDecoder().decode(ConversationsResponse.self, from: data).data ?? []
            errorMessage = nil
        } catch {
            errorMessage = (error as? URLError)?.code == .notConnectedToInternet
                ? "You're offline. Reconnect to see your messages."
                : "Couldn't load your messages."
        }
    }

    func messages(in conversationId: String) async throws -> [ChatMessage] {
        guard let email = CurrentUser.email else { return [] }

        var components = URLComponents(url: AppConfig.url("api/messages"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "conversationId", value: conversationId),
            .init(name: "userEmail", value: email)
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ChatMessagesResponse.self, from: data).data ?? []
    }

    @discardableResult
    func send(_ text: String, in conversationId: String) async throws -> ChatMessage? {
        guard let email = CurrentUser.email else { return nil }

        var request = URLRequest(url: AppConfig.url("api/messages"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "conversationId": conversationId,
            "userEmail": email,
            "content": text
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct SendResponse: Decodable { let data: ChatMessage? }
        return try JSONDecoder().decode(SendResponse.self, from: data).data
    }
}
