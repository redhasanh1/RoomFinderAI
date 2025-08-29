import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let content: String
    let sender: MessageSender
    let timestamp: Date
    let messageType: MessageType
    let metadata: MessageMetadata?
    
    init(id: String = UUID().uuidString, content: String, sender: MessageSender, timestamp: Date = Date(), messageType: MessageType = .text, metadata: MessageMetadata? = nil) {
        self.id = id
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
        self.messageType = messageType
        self.metadata = metadata
    }
    
    // For backwards compatibility with ChatMessage
    var isUser: Bool {
        return sender == .user
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
}

enum MessageSender: String, Codable {
    case user = "user"
    case ai = "ai"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .user:
            return "You"
        case .ai:
            return "AI Assistant"
        case .system:
            return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .user:
            return "person.circle.fill"
        case .ai:
            return "brain"
        case .system:
            return "gear"
        }
    }
}

enum MessageType: String, Codable {
    case text = "text"
    case image = "image"
    case listing = "listing"
    case map = "map"
    case document = "document"
    case suggestion = "suggestion"
    case error = "error"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .image:
            return "Image"
        case .listing:
            return "Listing"
        case .map:
            return "Map"
        case .document:
            return "Document"
        case .suggestion:
            return "Suggestion"
        case .error:
            return "Error"
        case .system:
            return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .text:
            return "text.bubble"
        case .image:
            return "photo"
        case .listing:
            return "house"
        case .map:
            return "map"
        case .document:
            return "doc"
        case .suggestion:
            return "lightbulb"
        case .error:
            return "exclamationmark.triangle"
        case .system:
            return "gear"
        }
    }
}

struct MessageMetadata: Codable {
    let confidence: Double?
    let processingTime: Double?
    let relatedListingIds: [String]
    let suggestedActions: [String]
    let tags: [String]
    
    init(confidence: Double? = nil, processingTime: Double? = nil, relatedListingIds: [String] = [], suggestedActions: [String] = [], tags: [String] = []) {
        self.confidence = confidence
        self.processingTime = processingTime
        self.relatedListingIds = relatedListingIds
        self.suggestedActions = suggestedActions
        self.tags = tags
    }
}

// For backwards compatibility, keep the ChatMessage struct
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
    
    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
    }
    
    // Convert to new Message format
    func toMessage() -> Message {
        return Message(
            id: id.uuidString,
            content: content,
            sender: isUser ? .user : .ai,
            timestamp: timestamp
        )
    }
}

// Convert from new Message to old ChatMessage format
extension Message {
    func toChatMessage() -> ChatMessage {
        return ChatMessage(content: content, isUser: sender == .user)
    }
}