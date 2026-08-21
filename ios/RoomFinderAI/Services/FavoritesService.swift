import Foundation

/// The rooms someone has saved, fetched directly rather than through a web
/// view.
///
/// `/api/favorites` returns whole listing rows, not just their ids, so the
/// saved list decodes into exactly the same `Listing` the rest of the app
/// already draws. Nothing here needs its own card, its own image loading or
/// its own idea of what a room is.
@MainActor
final class FavoritesService: ObservableObject {

    @Published private(set) var listings: [Listing] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasLoadedOnce = false

    private var task: Task<Void, Never>?

    func load() {
        // A reload started while one is in flight supersedes it, otherwise a
        // slow first response can land after a fast second and put a removed
        // room back on screen.
        task?.cancel()

        guard let email = CurrentUser.shared.email else {
            listings = []
            errorMessage = nil
            hasLoadedOnce = true
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                var rows: [Listing]
                do {
                    rows = try await fetch(email: email)
                } catch let first as URLError where Self.isTransient(first) {
                    // One retry, for the same reason ListingsService does it:
                    // a dropped connection is not worth an error screen.
                    try await Task.sleep(for: .seconds(2))
                    try Task.checkCancellation()
                    rows = try await fetch(email: email)
                }
                guard !Task.isCancelled else { return }
                listings = rows
                errorMessage = nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let ns = error as NSError
                errorMessage = ns.code == NSURLErrorNotConnectedToInternet
                    ? "You're offline. Reconnect to see your saved rooms."
                    : "Couldn't load your saved rooms. Pull down to try again."
            }
            isLoading = false
            hasLoadedOnce = true
        }
    }

    /// Removes a room, on screen first.
    ///
    /// Waiting for the server to answer before the row disappears makes a tap
    /// on a plain delete feel broken on a slow connection. If the call fails
    /// the row comes back and the reason is shown, so nothing is silently
    /// dropped.
    func remove(_ listing: Listing) async {
        guard let email = CurrentUser.shared.email else { return }

        let index = listings.firstIndex(of: listing)
        listings.removeAll { $0.id == listing.id }

        var components = URLComponents(
            url: AppConfig.url("api/favorites/\(listing.id)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [.init(name: "userEmail", value: email)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else {
                throw URLError(.badServerResponse)
            }
        } catch {
            if let index, !listings.contains(listing) {
                listings.insert(listing, at: min(index, listings.count))
            }
            errorMessage = "Couldn't remove that room. Try again."
        }
    }

    private func fetch(email: String) async throws -> [Listing] {
        var components = URLComponents(
            url: AppConfig.url("api/favorites"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [.init(name: "userEmail", value: email)]

        var request = URLRequest(url: components.url!)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else {
            throw URLError(.badServerResponse)
        }

        // A bare array, unlike /api/listings/search which wraps its rows in an
        // envelope. Decoding the wrong shape here returns nothing rather than
        // failing loudly, so both are accepted.
        let rows: [Listing]
        if let direct = try? JSONDecoder().decode([Listing].self, from: data) {
            rows = direct
        } else {
            rows = (try? JSONDecoder().decode(ListingsResponse.self, from: data))?.data ?? []
        }

        // An untitled row has nothing to draw, the same rule the listings feed
        // applies. `available` is deliberately not filtered on: a room you
        // saved that has since been taken should still be visible, or it looks
        // like the app lost it.
        return rows.filter { !$0.title.isEmpty }
    }

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
}
