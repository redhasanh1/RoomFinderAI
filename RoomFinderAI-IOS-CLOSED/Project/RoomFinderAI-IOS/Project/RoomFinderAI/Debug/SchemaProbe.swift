#if DEBUG
import Foundation

enum SchemaProbe {
  static func run() async {
    guard
      let urlStr = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
      let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
      let url = URL(string: urlStr + "/rest/v1/listings?select=*&limit=1")
    else { print("[SCHEMA] bad config"); return }

    var req = URLRequest(url: url)
    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    req.setValue(key, forHTTPHeaderField: "apikey")

    do {
      let (data, resp) = try await URLSession.shared.data(for: req)
      let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
      print("[SCHEMA] status:", code)
      if let raw = String(data: data, encoding: .utf8) {
        print("[SCHEMA] sample row:", raw)
      }
    } catch {
      print("[SCHEMA][ERROR]", error.localizedDescription)
    }
  }
}
#endif