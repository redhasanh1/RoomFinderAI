import Foundation

// MARK: - AI Chat Types
struct AIChat: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool
    let context: String?
    
    init(id: String = UUID().uuidString, title: String, createdAt: Date = Date(), updatedAt: Date = Date(), isActive: Bool = true, context: String? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
        self.context = context
    }
}

struct AIMessage: Identifiable, Codable, Equatable {
    let id: String
    let chatId: String
    let content: String
    let role: AIMessageRole
    let createdAt: Date
    let tokens: Int?
    let model: String?
    
    init(id: String = UUID().uuidString, chatId: String, content: String, role: AIMessageRole, createdAt: Date = Date(), tokens: Int? = nil, model: String? = nil) {
        self.id = id
        self.chatId = chatId
        self.content = content
        self.role = role
        self.createdAt = createdAt
        self.tokens = tokens
        self.model = model
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

// MARK: - Regular Chat Types
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

struct SendMessageRequest: Codable, Equatable {
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

struct CreateChatRequest: Codable, Equatable {
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

