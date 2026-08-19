import Foundation

/// Talks to the listings API directly, with no web view involved.
@MainActor
final class ListingsService: ObservableObject {

    @Published private(set) var listings: [Listing] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasLoadedOnce = false

    private var task: Task<Void, Never>?

    /// `/api/listings/search` handles the query and the numeric filters
    /// server-side; everything else is applied to the returned rows.
    func load(query: String = "", maxPrice: Double? = nil, bedrooms: Int? = nil) {
        // A new search supersedes one still in flight, otherwise results can
        // arrive out of order and the list shows the previous query's rows.
        task?.cancel()

        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                var results: [Listing]
                do {
                    results = try await fetch(query: query, maxPrice: maxPrice, bedrooms: bedrooms)
                } catch let first as URLError where Self.isTransient(first) {
                    // One retry, because the alternative is showing an error
                    // screen for a request that would have worked a second
                    // later — a hotel wifi hiccup or the server waking up.
                    try await Task.sleep(for: .seconds(2))
                    try Task.checkCancellation()
                    results = try await fetch(query: query, maxPrice: maxPrice, bedrooms: bedrooms)
                }
                guard !Task.isCancelled else { return }
                listings = results
                errorMessage = nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let ns = error as NSError
                errorMessage = ns.code == NSURLErrorNotConnectedToInternet
                    ? "You're offline. Reconnect to see rooms."
                    : "Couldn't load rooms. Pull down to try again."
            }
            isLoading = false
            hasLoadedOnce = true
        }
    }

    /// Failures worth one more attempt: the request never really got an
    /// answer. A 4xx or a decode failure would fail again identically.
    private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .badServerResponse,
             .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    /// A plain search with no published state attached.
    ///
    /// The instance method above drives a screen: it cancels the previous
    /// search, flips loading flags and swallows errors into a message. A caller
    /// that just wants the rows — the negotiation campaign looking for every
    /// room inside a budget — needs none of that and does need to know when it
    /// failed.
    static func search(query: String = "", maxPrice: Double? = nil, bedrooms: Int? = nil) async throws -> [Listing] {
        try await ListingsService().fetch(query: query, maxPrice: maxPrice, bedrooms: bedrooms)
    }

    private func fetch(query: String, maxPrice: Double?, bedrooms: Int?) async throws -> [Listing] {
        var components = URLComponents(
            url: AppConfig.url("api/listings/search"),
            resolvingAgainstBaseURL: false
        )!

        var items: [URLQueryItem] = []
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { items.append(.init(name: "q", value: trimmed)) }
        if let maxPrice { items.append(.init(name: "max_price", value: String(Int(maxPrice)))) }
        if let bedrooms { items.append(.init(name: "bedrooms", value: String(bedrooms))) }
        components.queryItems = items.isEmpty ? nil : items

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadRevalidatingCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ListingsResponse.self, from: data)
        let rows = decoded.data ?? []

        // Rows the website hides are hidden here too: `available` is the flag
        // the site filters on, and an untitled row has nothing to display.
        return rows.filter { ($0.available ?? true) && !$0.title.isEmpty }
    }
}
