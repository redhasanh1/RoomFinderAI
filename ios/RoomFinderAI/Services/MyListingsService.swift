import Foundation

/// The rooms you have posted, and removing one.
@MainActor
final class MyListingsService: ObservableObject {

    @Published private(set) var listings: [Listing] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var task: Task<Void, Never>?

    func load() {
        task?.cancel()

        guard let email = AuthService.shared.profile?.email else {
            listings = []
            return
        }

        isLoading = true

        task = Task {
            defer { isLoading = false }

            var components = URLComponents(
                url: AppConfig.url("api/listings"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [.init(name: "userEmail", value: email)]

            var request = URLRequest(url: components.url!)
            request.cachePolicy = .reloadIgnoringLocalCacheData

            guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
            guard !Task.isCancelled else { return }

            let rows: [Listing]
            if let direct = try? JSONDecoder().decode([Listing].self, from: data) {
                rows = direct
            } else {
                rows = (try? JSONDecoder().decode(ListingsResponse.self, from: data))?.data ?? []
            }

            // The endpoint takes userEmail as a filter, but it has defaulted to
            // every listing before now when it did not recognise the parameter.
            // Showing someone else's rooms under "Your listings" with a delete
            // swipe on them is not a mistake worth risking, so they are matched
            // here as well.
            listings = rows.filter {
                ($0.userEmail ?? "").lowercased() == email.lowercased() && !$0.title.isEmpty
            }
        }
    }

    func delete(at offsets: IndexSet) async {
        guard let email = AuthService.shared.profile?.email else { return }

        let doomed = offsets.compactMap { listings.indices.contains($0) ? listings[$0] : nil }
        let previous = listings
        listings.remove(atOffsets: offsets)

        for listing in doomed {
            var components = URLComponents(
                url: AppConfig.url("api/listings/\(listing.id)"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [.init(name: "userEmail", value: email)]

            var request = URLRequest(url: components.url!)
            request.httpMethod = "DELETE"

            let ok = (try? await URLSession.shared.data(for: request))
                .map { ($0.1 as? HTTPURLResponse)?.statusCode ?? 500 } ?? 500
            if !(200..<300).contains(ok) {
                // Put the list back rather than leaving the screen claiming a
                // room is gone when the server still has it.
                listings = previous
                errorMessage = "Couldn't delete that listing. Try again."
                return
            }
        }
    }
}
