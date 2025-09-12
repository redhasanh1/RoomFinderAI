import Foundation

// MARK: - Chat Data Models

struct ChatConversation: Identifiable, Codable {
    let id: String
    let participantIds: [String]
    let lastMessage: ChatMessage?
    let lastActivity: Date
    let isRead: Bool
    let conversationType: ConversationType
    let title: String?
    let groupImage: String?
    
    enum ConversationType: String, Codable {
        case direct = "direct"
        case group = "group"
        case landlord = "landlord"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case participantIds = "participant_ids"
        case lastMessage = "last_message"
        case lastActivity = "last_activity"
        case isRead = "is_read"
        case conversationType = "conversation_type"
        case title
        case groupImage = "group_image"
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let messageType: MessageType
    let timestamp: Date
    let isRead: Bool
    let replyToId: String?
    let attachments: [ChatAttachment]?
    
    enum MessageType: String, Codable {
        case text = "text"
        case image = "image"
        case file = "file"
        case system = "system"
        case propertyCard = "property_card"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case timestamp
        case isRead = "is_read"
        case replyToId = "reply_to_id"
        case attachments
    }
}

struct ChatAttachment: Identifiable, Codable {
    let id: String
    let messageId: String
    let fileName: String
    let fileSize: Int
    let mimeType: String
    let url: String
    let thumbnailUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case fileName = "file_name"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case url
        case thumbnailUrl = "thumbnail_url"
    }
}

struct ChatUser: Identifiable, Codable {
    let id: String
    let email: String
    let displayName: String?
    let avatarUrl: String?
    let isOnline: Bool
    let lastSeen: Date?
    let userType: UserType
    
    enum UserType: String, Codable {
        case tenant = "tenant"
        case landlord = "landlord"
        case agent = "agent"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
        case userType = "user_type"
    }
    
    var displayNameOrEmail: String {
        return displayName ?? email
    }
}

// MARK: - Chat Service Request/Response Models

struct CreateConversationRequest: Codable {
    let participantIds: [String]
    let conversationType: ChatConversation.ConversationType
    let title: String?
    
    enum CodingKeys: String, CodingKey {
        case participantIds = "participant_ids"
        case conversationType = "conversation_type"
        case title
    }
}

struct SendMessageRequest: Codable {
    let conversationId: String
    let content: String
    let messageType: ChatMessage.MessageType
    let replyToId: String?
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case content
        case messageType = "message_type"
        case replyToId = "reply_to_id"
    }
}

// MARK: - Chat Extensions

extension ChatMessage {
    var isFromCurrentUser: Bool {
        // Check if sender is the current user (zacoda1@hotmail.com)
        return senderId == "zacoda1@hotmail.com"
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

extension ChatConversation {
    var displayTitle: String {
        return title ?? "Chat"
    }
    
    var lastMessagePreview: String {
        guard let lastMessage = lastMessage else {
            return "No messages yet"
        }
        
        switch lastMessage.messageType {
        case .text:
            return lastMessage.content
        case .image:
            return "📷 Image"
        case .file:
            return "📎 File"
        case .system:
            return lastMessage.content
        case .propertyCard:
            return "🏠 Property"
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActivity, relativeTo: Date())
    }
}