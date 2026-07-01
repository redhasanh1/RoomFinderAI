import Foundation

struct Conversation: Identifiable, Codable, Hashable {
  let id: UUID
  let listing_id: UUID?
  let buyer_email: String?
  let seller_email: String?
  let created_at: String?
}

struct Message: Identifiable, Codable, Hashable {
  let id: UUID
  let conversation_id: UUID
  let sender_email: String
  let role: String
  let content: String
  let created_at: String
}