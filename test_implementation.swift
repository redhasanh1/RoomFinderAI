import Foundation

// Test our configuration reading
let urlStr = "https://fkktwhjybuflxqzopaex.supabase.co"
let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"

// Test URL construction
let testURL = URL(string: urlStr + "/rest/v1/listings?select=id,title,created_at&order=created_at.desc&limit=5")!
print("[TEST] URL:", testURL.absoluteString)

// Test host extraction
let host = testURL.host!
let ref = host.split(separator: ".").first!
print("[TEST] host=\(host) ref=\(ref)")

// Test key prefix
let keyPrefix = String(key.prefix(8))
print("[TEST] anon-prefix=\(keyPrefix)")

// Test basic JSON decoding structure
let sampleJSON = """
[{"id": "1", "title": "Test Listing", "price": 1200.50, "city": "Toronto", "created_at": "2025-08-14T12:00:00Z", "cover_image": null, "category": "apartment"}]
"""

struct TestListing: Codable {
    let id: String
    let title: String?
    let price: Double?
    let city: String?
    let created_at: String?
    let cover_image: String?
    let category: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) { id = s }
        else { id = UUID().uuidString }
        title = try? c.decode(String.self, forKey: .title)
        price = try? c.decode(Double.self, forKey: .price)
        city = try? c.decode(String.self, forKey: .city)
        created_at = try? c.decode(String.self, forKey: .created_at)
        cover_image = try? c.decode(String.self, forKey: .cover_image)
        category = try? c.decode(String.self, forKey: .category)
    }
}

do {
    let data = sampleJSON.data(using: .utf8)!
    let listings = try JSONDecoder().decode([TestListing].self, from: data)
    print("[TEST] Decoded \(listings.count) listings")
    print("[TEST] First listing: id=\(listings[0].id), title=\(listings[0].title ?? "nil"), price=\(listings[0].price ?? 0)")
} catch {
    print("[TEST] Decode error:", error)
}

print("[TEST] Implementation validation complete!")