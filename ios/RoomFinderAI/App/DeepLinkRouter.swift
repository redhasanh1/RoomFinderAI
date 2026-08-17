import Foundation

/// Single entry point for links arriving from outside the app: universal links
/// from email, `roomfinderai://` custom-scheme links, and push payloads.
///
/// It is a standalone object rather than a method on `AppState` because links
/// can arrive before SwiftUI has built anything — a cold launch from a push
/// notification is exactly that case. Pending links are replayed once the
/// scene attaches.
@MainActor
final class DeepLinkRouter: ObservableObject {

    static let shared = DeepLinkRouter()

    private weak var state: AppState?
    private var pending: URL?

    private init() {}

    func attach(_ state: AppState) {
        self.state = state
        if let url = pending {
            pending = nil
            handle(url)
        }
    }

    func handle(_ url: URL) {
        guard let target = normalize(url) else { return }
        guard let state else {
            pending = target
            return
        }
        state.open(target)
    }

    /// Accepts three shapes and reduces them to one canonical site URL:
    ///   https://www.roomfinderai.com/listings.html?id=1
    ///   roomfinderai://listings.html?id=1
    ///   listings.html?id=1
    private func normalize(_ url: URL) -> URL? {
        if AppConfig.isInternal(url) { return url }

        guard url.scheme?.lowercased() == AppConfig.urlScheme else { return nil }

        // For a custom scheme the "host" is the first path segment, so
        // roomfinderai://listings.html?id=1 parses as host "listings.html".
        var path = url.host ?? ""
        if !url.path.isEmpty { path += url.path }
        if path.isEmpty { path = "index.html" }
        if let query = url.query, !query.isEmpty { path += "?" + query }

        return AppConfig.url(path)
    }
}
