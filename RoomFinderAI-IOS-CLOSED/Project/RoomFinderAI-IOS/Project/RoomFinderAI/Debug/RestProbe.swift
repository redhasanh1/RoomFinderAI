#if DEBUG
import Foundation

enum RestProbe {
    static func run() async {
        guard
            let urlStr = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: urlStr + "/rest/v1/listings?select=id,title,created_at&order=created_at.desc&limit=5")
        else { print("[REST] bad config"); return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue(key, forHTTPHeaderField: "apikey")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            print("[REST] status:", code)
            print("[REST] body:", String(data: data, encoding: .utf8) ?? "<nil>")
        } catch {
            print("[REST][ERROR]", error.localizedDescription)
        }
    }
}
#endif