import Foundation

/// Loads the roommate marketplace from `/api/roommate-profiles`.
@MainActor
final class RoommateService: ObservableObject {

    @Published private(set) var profiles: [RoommateProfile] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasLoadedOnce = false

    private var task: Task<Void, Never>?

    func load(kind: RoommateProfile.Kind?, city: String = "") {
        task?.cancel()
        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                var results = try await fetch(kind: kind, city: city)
                // One retry for a request that never really got an answer —
                // the same reason the listings tab does it.
                if results.isEmpty && Task.isCancelled == false {
                    results = (try? await fetch(kind: kind, city: city)) ?? []
                }
                guard !Task.isCancelled else { return }
                profiles = results
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = (error as? URLError)?.code == .notConnectedToInternet
                    ? "You're offline. Reconnect to see people."
                    : "Couldn't load people. Pull down to try again."
            }
            isLoading = false
            hasLoadedOnce = true
        }
    }

    private func fetch(kind: RoommateProfile.Kind?, city: String) async throws -> [RoommateProfile] {
        var components = URLComponents(
            url: AppConfig.url("api/roommate-profiles"),
            resolvingAgainstBaseURL: false
        )!

        var items: [URLQueryItem] = []
        // Who is asking, so the server can drop people this account has
        // blocked. It cannot be done here: the payload carries no email to
        // match a block list against.
        if let me = CurrentUser.shared.email?.nilIfEmpty {
            items.append(.init(name: "userEmail", value: me))
        }
        if let kind { items.append(.init(name: "userType", value: kind.rawValue)) }
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCity.isEmpty { items.append(.init(name: "city", value: trimmedCity)) }
        components.queryItems = items.isEmpty ? nil : items

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(RoommateProfilesResponse.self, from: data)
        // A profile with no name is a half-finished signup, not a person to
        // show to someone choosing who to live with.
        return (decoded.data ?? []).filter { $0.name?.nilIfEmpty != nil }
    }
}
