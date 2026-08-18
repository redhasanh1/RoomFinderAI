import Foundation

/// Every photo for one listing, when the listings API only hands back the first.
///
/// `/api/listings/search` returns `imageUrls` now, but a server running an
/// older build sends only `imageUrl`, and a room with six photos then looks
/// like a room with one. Rather than have the gallery silently depend on
/// which build happens to be deployed, this fills the gap by reading the
/// listing's own media directly.
///
/// It is a fallback and nothing more: when the API provides the full set this
/// never runs. It reads a single row by id, so there is no listing out and
/// nothing to enumerate.
@MainActor
final class ListingGalleryService {

    private struct Config: Decodable {
        let SUPABASE_URL: String?
        let SUPABASE_ANON_KEY: String?
    }

    /// Config and results are both cached: reopening a listing should not
    /// re-fetch what has not changed.
    private static var cachedConfig: Config?
    private static var cache: [String: [URL]] = [:]

    private func loadConfig() async -> Config? {
        if let cached = Self.cachedConfig { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: AppConfig.url("api/config")),
              let decoded = try? JSONDecoder().decode(Config.self, from: data),
              let url = decoded.SUPABASE_URL, !url.isEmpty,
              let key = decoded.SUPABASE_ANON_KEY, !key.isEmpty else { return nil }
        Self.cachedConfig = decoded
        return decoded
    }

    /// The listing's photos in order, or an empty array if they cannot be read.
    ///
    /// Never throws: a gallery that cannot load its extra photos should leave
    /// the one it already has on screen, not fail the whole detail view.
    func photos(for listingID: String) async -> [URL] {
        if let cached = Self.cache[listingID] { return cached }

        guard let config = await loadConfig(),
              let base = config.SUPABASE_URL,
              let key = config.SUPABASE_ANON_KEY,
              var components = URLComponents(string: "\(base)/rest/v1/listings") else { return [] }

        components.queryItems = [
            .init(name: "id", value: "eq.\(listingID)"),
            .init(name: "select", value: "media")
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { return [] }

        // media holds two shapes: plain URL strings written by this app, and
        // { url } objects written by the website.
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let media = rows.first?["media"] as? [Any] else { return [] }

        let urls: [URL] = media.compactMap { entry in
            if let string = entry as? String { return URL(string: string) }
            if let object = entry as? [String: Any], let string = object["url"] as? String {
                return URL(string: string)
            }
            return nil
        }

        Self.cache[listingID] = urls
        return urls
    }
}
