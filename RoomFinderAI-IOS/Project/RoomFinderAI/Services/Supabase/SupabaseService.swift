import Foundation
import Supabase

struct SupabaseService {
  let client: SupabaseClient
  init(_ client: SupabaseClient) { self.client = client }

  // Listings
  func fetchListings(limit: Int = 50) async throws -> [Listing] {
    try await client.database
      .from("listings")
      .select("id,title,price,city,house_type,bedrooms,description,created_at,media")
      .order("created_at", ascending: false)
      .limit(limit)
      .execute().value
  }

  // Conversations
  func ensureConversation(listingId: UUID, buyerEmail: String) async throws -> UUID {
    if let rows: [[String:Any]] = try? await client.database
      .from("conversations").select("id")
      .eq("listing_id", value: listingId.uuidString)
      .eq("buyer_email", value: buyerEmail)
      .limit(1).execute().value,
       let idStr = rows.first?["id"] as? String,
       let id = UUID(uuidString: idStr) { return id }

    let inserted: [[String:Any]] = try await client.database
      .from("conversations")
      .insert(["listing_id": listingId.uuidString, "buyer_email": buyerEmail],
              returning: .representation)
      .select("id")
      .execute().value
    guard let idStr = inserted.first?["id"] as? String,
          let id = UUID(uuidString: idStr) else {
      throw NSError(domain: "Supabase", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create conversation"])
    }
    return id
  }

  func sendMessage(conversationId: UUID, senderEmail: String, role: String, content: String) async throws {
    _ = try await client.database.from("messages").insert([
      "conversation_id": conversationId.uuidString,
      "sender_email": senderEmail,
      "role": role,
      "content": content
    ]).execute()
  }
}