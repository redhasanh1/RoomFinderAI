import Foundation
import SwiftUI
import Supabase

// MARK: - AI Negotiator ViewModel
@MainActor
class AINegotiatorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var isTyping = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var foundListings: [NegotiationListing] = []
    @Published var currentSession: NegotiationSession?
    @Published var marketStats: MarketStats?
    
    // MARK: - Input State
    @Published var messageText = ""
    @Published var userBudget: Double?
    
    // MARK: - Private Properties
    private let negotiatorService: AINegotiatorService
    private let safeAuth: SafeAuthAdapter
    private var conversationId: UUID?
    private var listing: NegotiationListing?
    private var userEmail: String?
    
    // MARK: - Initialization
    init(supabase: SupabaseClient, config: OpenAIRequestConfig = .default) {
        self.negotiatorService = AINegotiatorService(supabase: supabase, config: config)
        self.safeAuth = SafeAuthAdapter()
        setupWelcomeMessage()
    }
    
    private func setupWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: """
            Welcome to AI Negotiation Assistant! 
            
            I can help you:
            • Find great properties and negotiate better deals
            • Write professional messages to landlords
            • Analyze market data for your area
            • Provide negotiation strategy and tips
            
            Try saying: "Find me a 1-bedroom apartment in [city] under $[budget]" or "Help me negotiate with my landlord"
            """,
            isFromUser: false,
            type: .system
        )
        messages = [welcomeMessage]
    }
    
    // MARK: - Public Interface
    func start(conversationId: UUID, listing: NegotiationListing, budget: Double?, userEmail: String) async {
        self.conversationId = conversationId
        self.listing = listing
        self.userBudget = budget
        self.userEmail = userEmail
        
        isLoading = true
        error = nil
        
        do {
            // Ensure AI user exists
            try await negotiatorService.ensureAIUserExists()
            
            // Get market data
            let stats = try await negotiatorService.getMarketData(
                location: listing.city,
                houseType: listing.houseType,
                bedrooms: listing.bedrooms
            )
            self.marketStats = stats
            
            // Create negotiation session
            let context = NegotiationContext(
                listing: listing,
                userBudget: budget,
                userEmail: userEmail,
                conversationId: conversationId,
                marketStats: stats
            )
            
            self.currentSession = NegotiationSession(context: context)
            
            // Setup realtime listener
            try await negotiatorService.setupMessageListener(conversationId: conversationId) { [weak self] message in
                Task { @MainActor in
                    await self?.handleIncomingMessage(message)
                }
            }
            
            // Generate initial negotiation message
            let initialMessage = try await negotiatorService.generateNegotiationMessage(
                listing: listing,
                userBudget: budget,
                marketData: stats
            )
            
            // Add system message about the listing
            addSystemMessage("Found listing: \(listing.displayTitle) at \(listing.displayLocation) for \(listing.displayPrice)")
            
            // Add suggested initial message
            addMessage(ChatMessage(
                content: "Here's a suggested negotiation message:\n\n\"\(initialMessage)\"\n\nWould you like me to send this, or would you prefer to modify it?",
                isFromUser: false
            ))
            
            foundListings = [listing]
            
        } catch {
            self.error = error.localizedDescription
            addErrorMessage("Failed to initialize negotiation: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func sendUserMessage(_ message: String) async {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(content: message, isFromUser: true)
        addMessage(userMessage)
        
        // Clear input
        messageText = ""
        
        // Show typing indicator
        showTyping()
        
        do {
            await processUserMessage(message)
        } catch {
            hideTyping()
            self.error = error.localizedDescription
            addErrorMessage("Error processing message: \(error.localizedDescription)")
        }
    }
    
    func retry() async {
        error = nil
        if let session = currentSession {
            await start(
                conversationId: session.context.conversationId,
                listing: session.context.listing,
                budget: session.context.userBudget,
                userEmail: session.context.userEmail
            )
        }
    }
    
    func clearChat() {
        messages.removeAll()
        foundListings.removeAll()
        currentSession = nil
        marketStats = nil
        error = nil
        setupWelcomeMessage()
    }
    
    // MARK: - Message Processing
    private func processUserMessage(_ message: String) async {
        let lowercased = message.lowercased()
        
        // Handle different types of user input
        if lowercased.contains("find") && (lowercased.contains("apartment") || lowercased.contains("house") || lowercased.contains("room")) {
            await handlePropertySearch(message)
        } else if currentSession != nil {
            await handleNegotiationMessage(message)
        } else {
            await handleGeneralQuery(message)
        }
        
        hideTyping()
    }
    
    private func handlePropertySearch(_ query: String) async {
        do {
            let searchResults = try await searchProperties(query: query)
            
            if !searchResults.isEmpty {
                foundListings = searchResults
                addMessage(ChatMessage(
                    content: "I found \(searchResults.count) properties matching your criteria! Check the \"Found Listings\" section. Would you like me to help you negotiate for any of these properties?",
                    isFromUser: false
                ))
            } else {
                addMessage(ChatMessage(
                    content: "I couldn't find any properties matching your criteria. Try adjusting your search terms or budget.",
                    isFromUser: false
                ))
            }
        } catch {
            addErrorMessage("Search failed: \(error.localizedDescription)")
        }
    }
    
    private func handleNegotiationMessage(_ message: String) async {
        guard let session = currentSession,
              let conversationId = conversationId else {
            addErrorMessage("No active negotiation session")
            return
        }
        
        do {
            // Send the user's message to the conversation
            let userMessageData: [String: Any] = [
                "conversation_id": conversationId.uuidString,
                "sender_email": userEmail ?? "user@example.com",
                "content": message,
                "created_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            // This is a user message, not an AI message
            // The AI will respond when it receives the landlord's reply
            addMessage(ChatMessage(
                content: "Message ready to send: \"\(message)\"\n\nI'll wait for the landlord's response and then help you with the next step.",
                isFromUser: false
            ))
            
        } catch {
            addErrorMessage("Failed to process negotiation message: \(error.localizedDescription)")
        }
    }
    
    private func handleGeneralQuery(_ query: String) async {
        do {
            // Use OpenAI to generate a helpful response for general queries
            let response = try await generateGeneralResponse(query: query)
            addMessage(ChatMessage(content: response, isFromUser: false))
        } catch {
            addErrorMessage("Failed to process query: \(error.localizedDescription)")
        }
    }
    
    private func handleIncomingMessage(_ message: NegotiationMessage) async {
        guard let session = currentSession else { return }
        
        // Add the landlord's message to chat
        addMessage(ChatMessage(
            content: "Landlord replied: \"\(message.content)\"",
            isFromUser: false
        ))
        
        showTyping()
        
        do {
            // Analyze the reply
            let analysis = try await negotiatorService.analyzeReply(
                replyContent: message.content,
                context: session.context
            )
            
            // Update negotiation state based on analysis
            if analysis.isFinalized {
                session.updateState(.finalized)
                if let price = analysis.agreedPrice {
                    addMessage(ChatMessage(
                        content: "🎉 Great news! The landlord accepted your offer at $\(Int(price)). The negotiation is complete!",
                        isFromUser: false,
                        type: .system
                    ))
                } else {
                    addMessage(ChatMessage(
                        content: "The landlord has accepted your offer! The negotiation is complete.",
                        isFromUser: false,
                        type: .system
                    ))
                }
            } else if analysis.makesCounterOffer {
                session.updateState(.counterOffer)
                
                // Generate counter response
                let counterResponse = try await negotiatorService.generateCounterResponse(
                    analysis: analysis,
                    context: session.context
                )
                
                addMessage(ChatMessage(
                    content: "I suggest this counter-response:\n\n\"\(counterResponse)\"\n\nShall I send this or would you like to modify it?",
                    isFromUser: false
                ))
            } else if !analysis.acceptsOffer {
                // Generate a follow-up response
                let followUpResponse = try await negotiatorService.generateMarketBasedResponse(
                    context: session.context
                )
                
                addMessage(ChatMessage(
                    content: "Here's a market-based response:\n\n\"\(followUpResponse)\"\n\nWould you like me to send this?",
                    isFromUser: false
                ))
            }
            
        } catch {
            addErrorMessage("Failed to analyze landlord's reply: \(error.localizedDescription)")
        }
        
        hideTyping()
    }
    
    // MARK: - Property Search
    private func searchProperties(query: String) async throws -> [NegotiationListing] {
        // Parse query to extract search parameters
        let searchParams = parseSearchQuery(query)
        
        // Build Supabase query  
        var supabaseQuery = negotiatorService.supabase
            .from("listings")
            .select("id,title,price,city,bedrooms,house_type,description,media,created_at")
            .not("price", operator: "is", value: "null")
            .limit(10)
        
        // Apply filters
        if let location = searchParams.location {
            supabaseQuery = supabaseQuery.or("city.ilike.%\(location)%,title.ilike.%\(location)%")
        }
        
        if let maxPrice = searchParams.maxPrice {
            supabaseQuery = supabaseQuery.lte("price", value: maxPrice)
        }
        
        if let houseType = searchParams.houseType {
            supabaseQuery = supabaseQuery.eq("house_type", value: houseType)
        }
        
        if let bedrooms = searchParams.bedrooms {
            supabaseQuery = supabaseQuery.eq("bedrooms", value: bedrooms)
        }
        
        let response = try await supabaseQuery.execute()
        return try JSONDecoder().decode([NegotiationListing].self, from: response.data)
    }
    
    private func parseSearchQuery(_ query: String) -> (location: String?, maxPrice: Int?, houseType: String?, bedrooms: Int?) {
        let lowercased = query.lowercased()
        
        // Extract location (everything after "in" and before price/type keywords)
        var location: String?
        if let inRange = lowercased.range(of: " in ") {
            let afterIn = String(lowercased[inRange.upperBound...])
            let locationEnd = afterIn.range(of: " under")?.lowerBound ?? 
                             afterIn.range(of: " for")?.lowerBound ?? 
                             afterIn.range(of: " apartment")?.lowerBound ??
                             afterIn.range(of: " house")?.lowerBound ??
                             afterIn.endIndex
            location = String(afterIn[..<locationEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract price
        var maxPrice: Int?
        let priceRegex = try? NSRegularExpression(pattern: "under \\$?([0-9,]+)", options: [.caseInsensitive])
        if let match = priceRegex?.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
           let range = Range(match.range(at: 1), in: query) {
            let priceString = String(query[range]).replacingOccurrences(of: ",", with: "")
            maxPrice = Int(priceString)
        }
        
        // Extract house type
        var houseType: String?
        if lowercased.contains("apartment") { houseType = "apartment" }
        else if lowercased.contains("house") { houseType = "house" }
        else if lowercased.contains("condo") { houseType = "condo" }
        else if lowercased.contains("studio") { houseType = "studio" }
        
        // Extract bedrooms
        var bedrooms: Int?
        let bedroomRegex = try? NSRegularExpression(pattern: "([0-9]+)[- ]bedroom", options: [.caseInsensitive])
        if let match = bedroomRegex?.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
           let range = Range(match.range(at: 1), in: query) {
            bedrooms = Int(String(query[range]))
        }
        
        return (location: location, maxPrice: maxPrice, houseType: houseType, bedrooms: bedrooms)
    }
    
    private func generateGeneralResponse(query: String) async throws -> String {
        // For general queries, provide helpful negotiation advice
        let response = """
        I'm your AI Negotiation Assistant! Here are some ways I can help:
        
        🔍 **Property Search**: Say "Find me a [type] in [location] under $[budget]"
        📝 **Negotiation Help**: I can write professional messages to landlords
        📊 **Market Analysis**: I'll provide data-driven negotiation strategies
        💡 **Tips & Advice**: Get expert negotiation tactics
        
        What would you like help with today?
        """
        
        return response
    }
    
    // MARK: - UI Helper Methods
    private func addMessage(_ message: ChatMessage) {
        messages.append(message)
    }
    
    private func addSystemMessage(_ content: String) {
        let systemMessage = ChatMessage(content: content, isFromUser: false, type: .system)
        addMessage(systemMessage)
    }
    
    private func addErrorMessage(_ content: String) {
        let errorMessage = ChatMessage(content: content, isFromUser: false, type: .error)
        addMessage(errorMessage)
    }
    
    private func showTyping() {
        isTyping = true
        let typingMessage = ChatMessage(content: "AI Assistant is typing...", isFromUser: false, type: .typing)
        addMessage(typingMessage)
    }
    
    private func hideTyping() {
        isTyping = false
        // Remove typing messages
        messages.removeAll { $0.type == .typing }
    }
    
    // MARK: - Validation
    var canSendMessage: Bool {
        return !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
               messageText.count <= NegotiatorConfig.maxMessageLength
    }
    
    var characterCount: String {
        return "\(messageText.count)/\(NegotiatorConfig.maxMessageLength)"
    }
    
    var isCharacterLimitExceeded: Bool {
        return messageText.count > NegotiatorConfig.maxMessageLength
    }
    
    // MARK: - Export
    func exportChatHistory() -> String {
        let chatData = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "listing": currentSession?.context.listing.displayTitle ?? "N/A",
            "messages": messages.map { message in
                [
                    "sender": message.isFromUser ? "User" : "AI Assistant",
                    "content": message.content,
                    "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
                    "type": message.type.rawValue
                ]
            }
        ] as [String: Any]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: chatData, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "Failed to export chat history"
        }
        
        return jsonString
    }
    
    // MARK: - Cleanup
    deinit {
        negotiatorService.teardownMessageListener()
    }
}