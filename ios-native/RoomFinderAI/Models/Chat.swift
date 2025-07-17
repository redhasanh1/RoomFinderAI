import Foundation

struct Chat: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let participants: [User]
    let listingId: String?
    let lastMessage: Message?
    let unreadCount: Int
    let isGroupChat: Bool
    let createdAt: Date
    let updatedAt: Date
    let status: ChatStatus
    
    enum CodingKeys: String, CodingKey {
        case id, title, participants
        case listingId = "listing_id"
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
        case isGroupChat = "is_group_chat"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case status
    }
}

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let chatId: String
    let senderId: String
    let senderName: String
    let content: String
    let messageType: MessageType
    let attachments: [MessageAttachment]
    let replyTo: String?
    let timestamp: Date
    let editedAt: Date?
    let isRead: Bool
    let isDelivered: Bool
    let reactions: [MessageReaction]
    
    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case content
        case messageType = "message_type"
        case attachments
        case replyTo = "reply_to"
        case timestamp
        case editedAt = "edited_at"
        case isRead = "is_read"
        case isDelivered = "is_delivered"
        case reactions
    }
}

enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case document = "document"
    case audio = "audio"
    case video = "video"
    case system = "system"
    case ai = "ai"
    case location = "location"
    
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .document: return "Document"
        case .audio: return "Audio"
        case .video: return "Video"
        case .system: return "System"
        case .ai: return "AI"
        case .location: return "Location"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "text.bubble"
        case .image: return "photo"
        case .document: return "doc"
        case .audio: return "waveform"
        case .video: return "video"
        case .system: return "gear"
        case .ai: return "brain"
        case .location: return "location"
        }
    }
}

struct MessageAttachment: Identifiable, Codable, Equatable {
    let id: String
    let fileName: String
    let fileSize: Int
    let fileType: String
    let url: String
    let thumbnailUrl: String?
    let uploadedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case fileName = "file_name"
        case fileSize = "file_size"
        case fileType = "file_type"
        case url
        case thumbnailUrl = "thumbnail_url"
        case uploadedAt = "uploaded_at"
    }
}

struct MessageReaction: Identifiable, Codable, Equatable {
    let id: String
    let messageId: String
    let userId: String
    let userName: String
    let emoji: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case userId = "user_id"
        case userName = "user_name"
        case emoji
        case createdAt = "created_at"
    }
}

enum ChatStatus: String, Codable, CaseIterable {
    case active = "active"
    case archived = "archived"
    case blocked = "blocked"
    case deleted = "deleted"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .archived: return "Archived"
        case .blocked: return "Blocked"
        case .deleted: return "Deleted"
        }
    }
}

struct SendMessageRequest: Codable {
    let chatId: String
    let content: String
    let messageType: MessageType
    let replyTo: String?
    let attachments: [String]?
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case content
        case messageType = "message_type"
        case replyTo = "reply_to"
        case attachments
    }
}

struct CreateChatRequest: Codable {
    let participantIds: [String]
    let listingId: String?
    let title: String?
    let isGroupChat: Bool
    
    enum CodingKeys: String, CodingKey {
        case participantIds = "participant_ids"
        case listingId = "listing_id"
        case title
        case isGroupChat = "is_group_chat"
    }
}

struct AIChat: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let title: String
    let messages: [AIMessage]
    let context: AIContext?
    let createdAt: Date
    let updatedAt: Date
    let status: AIChatStatus
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, messages, context
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case status
    }
}

struct AIMessage: Identifiable, Codable, Equatable {
    let id: String
    let role: AIMessageRole
    let content: String
    let timestamp: Date
    let metadata: AIMessageMetadata?
    
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, metadata
    }
}

enum AIMessageRole: String, Codable, CaseIterable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .user: return "You"
        case .assistant: return "AI Assistant"
        case .system: return "System"
        }
    }
}

struct AIMessageMetadata: Codable, Equatable {
    let tokens: Int?
    let model: String?
    let temperature: Double?
    let confidence: Double?
    let processingTime: Double?
    
    enum CodingKeys: String, CodingKey {
        case tokens, model, temperature, confidence
        case processingTime = "processing_time"
    }
}

struct AIContext: Codable, Equatable {
    let listingId: String?
    let searchQuery: String?
    let userPreferences: UserPreferences?
    let conversationHistory: [String]?
    let currentStep: String?
    
    enum CodingKeys: String, CodingKey {
        case listingId = "listing_id"
        case searchQuery = "search_query"
        case userPreferences = "user_preferences"
        case conversationHistory = "conversation_history"
        case currentStep = "current_step"
    }
}

enum AIChatStatus: String, Codable, CaseIterable {
    case active = "active"
    case completed = "completed"
    case paused = "paused"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .paused: return "Paused"
        case .archived: return "Archived"
        }
    }
}

struct AINegotiationRequest: Codable {
    let listingId: String
    let userMessage: String
    let context: AIContext?
    let negotiationGoal: String?
    let maxBudget: Double?
    
    enum CodingKeys: String, CodingKey {
        case listingId = "listing_id"
        case userMessage = "user_message"
        case context
        case negotiationGoal = "negotiation_goal"
        case maxBudget = "max_budget"
    }
}

struct AINegotiationResponse: Codable {
    let response: String
    let suggestions: [String]
    let nextSteps: [String]
    let confidence: Double
    let negotiationStrategy: String?
    
    enum CodingKeys: String, CodingKey {
        case response, suggestions
        case nextSteps = "next_steps"
        case confidence
        case negotiationStrategy = "negotiation_strategy"
    }
}