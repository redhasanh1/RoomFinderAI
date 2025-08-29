import Foundation

struct Chat: Identifiable, Codable {
    let id: String
    let userId: String
    let title: String
    let messages: [Message]
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool
    let metadata: ChatMetadata?
    
    init(id: String = UUID().uuidString, userId: String, title: String, messages: [Message] = [], createdAt: Date = Date(), updatedAt: Date = Date(), isActive: Bool = true, metadata: ChatMetadata? = nil) {
        self.id = id
        self.userId = userId
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
        self.metadata = metadata
    }
}

struct ChatMetadata: Codable {
    let category: ChatCategory
    let tags: [String]
    let priority: ChatPriority
    let relatedListingIds: [String]
    
    init(category: ChatCategory = .general, tags: [String] = [], priority: ChatPriority = .normal, relatedListingIds: [String] = []) {
        self.category = category
        self.tags = tags
        self.priority = priority
        self.relatedListingIds = relatedListingIds
    }
}

enum ChatCategory: String, Codable, CaseIterable {
    case general = "general"
    case roomSearch = "room_search"
    case budgetAdvice = "budget_advice"
    case locationGuide = "location_guide"
    case negotiation = "negotiation"
    case roommate = "roommate"
    case legal = "legal"
    case maintenance = "maintenance"
    
    var displayName: String {
        switch self {
        case .general:
            return "General"
        case .roomSearch:
            return "Room Search"
        case .budgetAdvice:
            return "Budget Advice"
        case .locationGuide:
            return "Location Guide"
        case .negotiation:
            return "Negotiation"
        case .roommate:
            return "Roommate"
        case .legal:
            return "Legal"
        case .maintenance:
            return "Maintenance"
        }
    }
    
    var icon: String {
        switch self {
        case .general:
            return "bubble.left.and.bubble.right"
        case .roomSearch:
            return "magnifyingglass"
        case .budgetAdvice:
            return "dollarsign.circle"
        case .locationGuide:
            return "map"
        case .negotiation:
            return "handshake"
        case .roommate:
            return "person.2"
        case .legal:
            return "doc.text"
        case .maintenance:
            return "wrench"
        }
    }
}

enum ChatPriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .normal:
            return "Normal"
        case .high:
            return "High"
        case .urgent:
            return "Urgent"
        }
    }
}

// Chat session management
class ChatSession: ObservableObject {
    @Published var currentChat: Chat?
    @Published var chatHistory: [Chat] = []
    
    func startNewChat(userId: String, title: String? = nil) -> Chat {
        let chat = Chat(
            userId: userId,
            title: title ?? "New Chat",
            metadata: ChatMetadata()
        )
        currentChat = chat
        return chat
    }
    
    func addMessage(_ message: Message, to chatId: String) {
        // TODO: Implement message addition to chat
    }
    
    func saveChat(_ chat: Chat) {
        // TODO: Implement chat saving
        if !chatHistory.contains(where: { $0.id == chat.id }) {
            chatHistory.append(chat)
        }
    }
    
    func loadChatHistory(for userId: String) {
        // TODO: Implement chat history loading
    }
}