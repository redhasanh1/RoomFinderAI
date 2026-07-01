#if DEBUG
import Foundation
import Supabase

enum ParityProbe {
  static func run(_ client: SupabaseClient) async {
    do {
      let response = try await client
        .from("listings")      // or the exact view/RPC the website uses
        .select("id,title,created_at")
        .order("created_at", ascending: false)
        .range(from: 0, to: 4)
        .execute()
        
      // Print raw response
      let data = response.data
      if let raw = String(data: data, encoding: .utf8) {
        print("[PARITY][RAW] payload:", raw)
      } else {
        print("[PARITY][RAW] payload: <nil>")
      }
      
      // Try to decode as generic JSON
      if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        print("[PARITY][GENERIC] \(jsonArray.count) rows")
        for (i, row) in jsonArray.prefix(3).enumerated() {
          print("[PARITY][GENERIC] \(i):", row)
        }
      }
    } catch {
      print("[PARITY][ERROR]", error)
    }
  }
}
#endif