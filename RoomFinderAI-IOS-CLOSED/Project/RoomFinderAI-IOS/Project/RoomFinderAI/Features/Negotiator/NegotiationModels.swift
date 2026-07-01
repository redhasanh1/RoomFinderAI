import Foundation

// MARK: - Negotiation Listing Model
struct NegotiationListing: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String?
    let price: Int?
    let city: String?
    let bedrooms: Int?
    let houseType: String?
    let description: String?
    let media: [MediaItem]?
    let createdAt: String?
    
    var displayTitle: String {
        return title ?? "Untitled Listing"
    }
    
    var displayPrice: String {
        guard let price = price else { return "Price not available" }
        return "$\(price)"
    }
    
    var displayLocation: String {
        return city ?? "Location not specified"
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, price, city, bedrooms, description, media
        case houseType = "house_type"
        case createdAt = "created_at"
    }
}

// MARK: - Conversation Model
struct NegotiationConversation: Identifiable, Codable, Equatable {
    let id: UUID
    let senderEmail: String?
    let receiverEmail: String?
    let listingId: UUID?
    let createdAt: String?
    let updatedAt: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case senderEmail = "sender_email"
        case receiverEmail = "receiver_email"
        case listingId = "listing_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Message Model
struct NegotiationMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let conversationId: UUID
    let senderEmail: String
    let content: String
    let createdAt: String?
    let isRead: Bool?
    
    var isFromAI: Bool {
        return senderEmail == NegotiatorConfig.aiUserEmail
    }
    
    var displaySender: String {
        return isFromAI ? "AI Assistant" : "You"
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, content
        case conversationId = "conversation_id"
        case senderEmail = "sender_email"
        case createdAt = "created_at"
        case isRead = "is_read"
    }
}

// MARK: - Chat Message (UI Model)
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let type: MessageType
    
    enum MessageType: String, CaseIterable {
        case text = "text"
        case system = "system"
        case typing = "typing"
        case error = "error"
    }
    
    init(content: String, isFromUser: Bool, type: MessageType = .text) {
        self.content = content
        self.isFromUser = isFromUser
        self.type = type
        self.timestamp = Date()
    }
}

// MARK: - Negotiation State
enum NegotiationState: String, Codable, CaseIterable {
    case initial = "initial"
    case negotiating = "negotiating"
    case counterOffer = "counter_offer"
    case accepted = "accepted"
    case rejected = "rejected"
    case finalized = "finalized"
    
    var displayName: String {
        switch self {
        case .initial: return "Starting"
        case .negotiating: return "Negotiating"
        case .counterOffer: return "Counter Offer"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        case .finalized: return "Deal Closed"
        }
    }
    
    var isCompleted: Bool {
        return self == .accepted || self == .rejected || self == .finalized
    }
}

// MARK: - Analysis Result (from OpenAI)
struct AnalysisResult: Codable, Equatable {
    let sentiment: String?
    let priceOffered: Double?
    let acceptsOffer: Bool
    let makesCounterOffer: Bool
    let shouldRespond: Bool
    let isFinalized: Bool
    let agreedPrice: Double?
    let responseStrategy: String?
    let suggestedResponse: String?
    let negotiationPhase: String?
    
    // Support both camelCase (web format) and snake_case
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try camelCase first, then snake_case
        self.sentiment = try container.decodeIfPresent(String.self, forKey: .sentiment)
        self.priceOffered = try container.decodeIfPresent(Double.self, forKey: .priceOffered) 
            ?? try container.decodeIfPresent(Double.self, forKey: .priceOfferedSnake)
        self.acceptsOffer = try container.decodeIfPresent(Bool.self, forKey: .acceptsOffer) 
            ?? try container.decodeIfPresent(Bool.self, forKey: .acceptsOfferSnake) ?? false
        self.makesCounterOffer = try container.decodeIfPresent(Bool.self, forKey: .makesCounterOffer) 
            ?? try container.decodeIfPresent(Bool.self, forKey: .makesCounterOfferSnake) ?? false
        self.shouldRespond = try container.decodeIfPresent(Bool.self, forKey: .shouldRespond) 
            ?? try container.decodeIfPresent(Bool.self, forKey: .shouldRespondSnake) ?? false
        self.isFinalized = try container.decodeIfPresent(Bool.self, forKey: .isFinalized) 
            ?? try container.decodeIfPresent(Bool.self, forKey: .isFinalizedSnake) ?? false
        self.agreedPrice = try container.decodeIfPresent(Double.self, forKey: .agreedPrice) 
            ?? try container.decodeIfPresent(Double.self, forKey: .agreedPriceSnake)
        self.responseStrategy = try container.decodeIfPresent(String.self, forKey: .responseStrategy) 
            ?? try container.decodeIfPresent(String.self, forKey: .responseStrategySnake)
        self.suggestedResponse = try container.decodeIfPresent(String.self, forKey: .suggestedResponse) 
            ?? try container.decodeIfPresent(String.self, forKey: .suggestedResponseSnake)
        self.negotiationPhase = try container.decodeIfPresent(String.self, forKey: .negotiationPhase) 
            ?? try container.decodeIfPresent(String.self, forKey: .negotiationPhaseSnake)
    }
    
    private enum CodingKeys: String, CodingKey {
        case sentiment
        // CamelCase keys (web format)
        case priceOffered
        case acceptsOffer
        case makesCounterOffer
        case shouldRespond
        case isFinalized
        case agreedPrice
        case responseStrategy
        case suggestedResponse
        case negotiationPhase
        // Snake_case keys (alternate format)
        case priceOfferedSnake = "price_offered"
        case acceptsOfferSnake = "accepts_offer"
        case makesCounterOfferSnake = "makes_counter_offer"
        case shouldRespondSnake = "should_respond"
        case isFinalizedSnake = "is_finalized"
        case agreedPriceSnake = "agreed_price"
        case responseStrategySnake = "response_strategy"
        case suggestedResponseSnake = "suggested_response"
        case negotiationPhaseSnake = "negotiation_phase"
    }
}

// MARK: - Negotiation Context
struct NegotiationContext: Codable, Equatable {
    let listing: NegotiationListing
    let userBudget: Double?
    let userEmail: String
    let conversationId: UUID
    let currentState: NegotiationState
    let marketStats: MarketStats?
    let messageHistory: [NegotiationMessage]
    let lastOffer: Double? // Track last AI offer for better context
    
    init(listing: NegotiationListing, userBudget: Double?, userEmail: String, 
         conversationId: UUID, currentState: NegotiationState = .initial,
         marketStats: MarketStats? = nil, messageHistory: [NegotiationMessage] = [],
         lastOffer: Double? = nil) {
        self.listing = listing
        self.userBudget = userBudget
        self.userEmail = userEmail
        self.conversationId = conversationId
        self.currentState = currentState
        self.marketStats = marketStats
        self.messageHistory = messageHistory
        self.lastOffer = lastOffer
    }
}

// MARK: - Negotiation Session (Active UI State)
class NegotiationSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var context: NegotiationContext
    @Published var chatMessages: [ChatMessage] = []
    @Published var isTyping: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    init(context: NegotiationContext) {
        self.context = context
        // Initialize with system message
        let welcomeMessage = ChatMessage(
            content: "Hello! I'm your AI negotiation assistant. I'll help you negotiate a better deal for \(context.listing.displayTitle).",
            isFromUser: false,
            type: .system
        )
        self.chatMessages = [welcomeMessage]
    }
    
    func addMessage(_ message: ChatMessage) {
        DispatchQueue.main.async {
            // Remove typing indicator if present
            self.chatMessages.removeAll { $0.type == .typing }
            self.chatMessages.append(message)
        }
    }
    
    func showTypingIndicator() {
        DispatchQueue.main.async {
            let typingMessage = ChatMessage(
                content: "AI Assistant is typing...",
                isFromUser: false,
                type: .typing
            )
            self.chatMessages.append(typingMessage)
            self.isTyping = true
        }
    }
    
    func hideTypingIndicator() {
        DispatchQueue.main.async {
            self.chatMessages.removeAll { $0.type == .typing }
            self.isTyping = false
        }
    }
    
    func updateState(_ newState: NegotiationState) {
        DispatchQueue.main.async {
            self.context = NegotiationContext(
                listing: self.context.listing,
                userBudget: self.context.userBudget,
                userEmail: self.context.userEmail,
                conversationId: self.context.conversationId,
                currentState: newState,
                marketStats: self.context.marketStats,
                messageHistory: self.context.messageHistory
            )
        }
    }
}

// MARK: - OpenAI Request/Response Models
struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    let temperature: Float
    
    private enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finishReason: String?
    
    private enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Error Types
enum NegotiationError: LocalizedError {
    case invalidConfiguration
    case missingAPIKey
    case networkError(String)
    case parsingError(String)
    case supabaseError(String)
    case openAIError(String)
    case invalidInput(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid configuration. Please check your API keys."
        case .missingAPIKey:
            return "Missing OpenAI API key. Please configure your credentials."
        case .networkError(let message):
            return "Network error: \(message)"
        case .parsingError(let message):
            return "Failed to parse response: \(message)"
        case .supabaseError(let message):
            return "Database error: \(message)"
        case .openAIError(let message):
            return "OpenAI API error: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}

// MARK: - Success Types
enum NegotiationSuccess {
    case messageGenerated(String)
    case dealAccepted(Double)
    case counterOfferMade(Double)
    case negotiationComplete
    
    var message: String {
        switch self {
        case .messageGenerated(let msg):
            return msg
        case .dealAccepted(let price):
            return "Great! Deal accepted at $\(Int(price))"
        case .counterOfferMade(let price):
            return "Counter offer received: $\(Int(price))"
        case .negotiationComplete:
            return "Negotiation completed successfully!"
        }
    }
}