import Foundation

struct User: Identifiable, Codable, Hashable {
  let id: UUID
  let email: String
  let name: String?
  let created_at: String?
}