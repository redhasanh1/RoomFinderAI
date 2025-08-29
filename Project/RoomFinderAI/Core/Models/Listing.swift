import Foundation

struct MediaItem: Codable, Hashable {
  let url: String?
}

struct Listing: Identifiable, Codable, Hashable {
  let id: UUID
  let title: String?
  let price: Int?
  let city: String?
  let house_type: String?
  let bedrooms: Int?
  let description: String?
  let created_at: String?
  let media: [MediaItem]?
  var coverURLString: String? { media?.first?.url }
}