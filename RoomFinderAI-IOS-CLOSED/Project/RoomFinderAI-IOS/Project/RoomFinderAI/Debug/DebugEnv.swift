#if DEBUG
import Foundation
import Supabase

enum DebugEnv {
  static func log(_ client: SupabaseClient) {
    // Get URL from bundle config since client properties are internal
    let urlStr = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "nil"
    let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? "nil"
    let keyPrefix = key == "nil" ? "nil" : String(key.prefix(8))
    
    // Extract host and ref from URL string
    var host = "unknown-host"
    var ref = "unknown-ref"
    if let url = URL(string: urlStr), let hostStr = url.host {
      host = hostStr
      ref = hostStr.components(separatedBy: ".").first ?? hostStr
    }
    
    // Get current user ID if available
    let uid = "anon" // Will be updated when auth is checked

    print("[ENV] host=\(host) ref=\(ref)")
    print("[ENV] url=\(urlStr)")
    print("[ENV] anon-prefix=\(keyPrefix)")
    if !host.contains("fkktwhjybuflxqzopaex") {
      print("[ENV][ERROR] Wrong project ref, expected fkktwhjybuflxqzopaex")
    }
    print("[AUTH] user=\(uid)")
  }
}
#endif