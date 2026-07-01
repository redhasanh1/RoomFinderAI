import Foundation

struct CardListing: Identifiable, Decodable, Equatable {
  let id: UUID
  let title: String?
  let price: Int?
  let house_type: String?
  let bedrooms: Int?
  let description: String?
  let created_at: String?
  
  // Media field - array of storage paths or URLs
  let media: [String]?
  
  // Computed property to get first image path/URL
  var coverImagePath: String? {
    media?.first
  }
}