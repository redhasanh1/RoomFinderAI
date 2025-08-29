import Foundation
import Supabase

@MainActor
final class AINegotiatorViewModel: ObservableObject {
  @Published var messages: [ChatMessage] = []
  @Published var isLoading = false
  @Published var error: String?
  
  private let service: AINegotiatorService
  private let listing: Listing
  private let buyerEmail: String
  private let buyerBudget: Double?
  private var conversationId: UUID?
  
  init(supabase: SupabaseClient, listing: Listing, buyerEmail: String, buyerBudget: Double?) {
    self.service = AINegotiatorService(supabase: supabase)
    self.listing = listing
    self.buyerEmail = buyerEmail
    self.buyerBudget = buyerBudget
  }
  
  func startNegotiation() async {
    isLoading = true
    error = nil
    
    do {
      // Ensure conversation exists
      let convId = try await service.ensureConversation(listingId: listing.id, buyerEmail: buyerEmail)
      conversationId = convId
      
      // Send first AI message
      let firstMessage = try await service.sendFirstAIMessage(
        conversationId: convId,
        listing: listing,
        buyerBudget: buyerBudget
      )
      
      messages.append(ChatMessage(content: firstMessage, isFromUser: false))
      
    } catch {
      self.error = error.localizedDescription
      print("❌ Negotiation start error:", error)
    }
    
    isLoading = false
  }
  
  func sendMessage(_ content: String) async {
    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let convId = conversationId else { return }
    
    // Add user message immediately
    messages.append(ChatMessage(content: content, isFromUser: true))
    isLoading = true
    
    do {
      let response = try await service.sendMessage(
        conversationId: convId,
        userMessage: content,
        buyerEmail: buyerEmail
      )
      
      messages.append(ChatMessage(content: response, isFromUser: false))
      
    } catch {
      self.error = error.localizedDescription
      print("❌ Send message error:", error)
    }
    
    isLoading = false
  }
}

struct ChatMessage: Identifiable {
  let id = UUID()
  let content: String
  let isFromUser: Bool
  let timestamp = Date()
}