import Foundation
import Supabase

@MainActor
class AINegotiatorService: ObservableObject {
  private let supabaseService: SupabaseService
  private let openAI = OpenAIClient.shared
  
  init(supabase: SupabaseClient) {
    self.supabaseService = SupabaseService(supabase)
  }
  
  func ensureConversation(listingId: UUID, buyerEmail: String) async throws -> UUID {
    try await supabaseService.ensureConversation(listingId: listingId, buyerEmail: buyerEmail)
  }
  
  func sendFirstAIMessage(conversationId: UUID, listing: Listing, buyerBudget: Double?) async throws -> String {
    let systemPrompt = NegotiatorConfig.systemPrompt
    let userPrompt = """
      Property: \(listing.title ?? "Property")
      Listed Price: $\(listing.price ?? 0)
      Buyer Budget: $\(buyerBudget ?? NegotiatorConfig.defaultBudget)
      
      Start a negotiation conversation. Introduce yourself and suggest an opening strategy.
      """
    
    let response = try await openAI.textChat(system: systemPrompt, user: userPrompt)
    
    // Save message to database
    try await supabaseService.sendMessage(
      conversationId: conversationId,
      senderEmail: "ai-assistant@roomfinder.ai", 
      role: "assistant",
      content: response
    )
    
    return response
  }
  
  func sendMessage(conversationId: UUID, userMessage: String, buyerEmail: String) async throws -> String {
    // Save user message first
    try await supabaseService.sendMessage(
      conversationId: conversationId,
      senderEmail: buyerEmail,
      role: "user", 
      content: userMessage
    )
    
    // Get AI response
    let response = try await openAI.textChat(
      system: NegotiatorConfig.systemPrompt,
      user: userMessage
    )
    
    // Save AI response
    try await supabaseService.sendMessage(
      conversationId: conversationId,
      senderEmail: "ai-assistant@roomfinder.ai",
      role: "assistant",
      content: response
    )
    
    return response
  }
}