import Foundation

struct MessageResponse: Codable, Equatable {
    let messages: [Message]
    let hasNextPage: Bool
    let hasPreviousPage: Bool
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case messages
        case hasNextPage = "has_next_page"
        case hasPreviousPage = "has_previous_page"
        case totalCount = "total_count"
    }
}

struct ChatResponse: Codable, Equatable {
    let chats: [Chat]
    let hasNextPage: Bool
    let hasPreviousPage: Bool
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case chats
        case hasNextPage = "has_next_page"
        case hasPreviousPage = "has_previous_page"
        case totalCount = "total_count"
    }
}

struct MarkAsReadRequest: Codable, Equatable {
    let messageIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case messageIds = "message_ids"
    }
}

struct TypingIndicator: Codable, Equatable {
    let chatId: String
    let userId: String
    let userName: String
    let isTyping: Bool
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case userId = "user_id"
        case userName = "user_name"
        case isTyping = "is_typing"
        case timestamp
    }
}

struct FileUploadRequest: Codable, Equatable {
    let fileName: String
    let fileType: String
    let fileSize: Int
    let chatId: String
    
    enum CodingKeys: String, CodingKey {
        case fileName = "file_name"
        case fileType = "file_type"
        case fileSize = "file_size"
        case chatId = "chat_id"
    }
}

struct FileUploadResponse: Codable, Equatable {
    let uploadUrl: String
    let fileId: String
    let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case uploadUrl = "upload_url"
        case fileId = "file_id"
        case expiresAt = "expires_at"
    }
}

struct MessageSearchRequest: Codable, Equatable {
    let query: String
    let chatId: String?
    let messageType: MessageType?
    let dateFrom: Date?
    let dateTo: Date?
    let limit: Int
    let offset: Int
    
    enum CodingKeys: String, CodingKey {
        case query
        case chatId = "chat_id"
        case messageType = "message_type"
        case dateFrom = "date_from"
        case dateTo = "date_to"
        case limit, offset
    }
}

struct MessageSearchResponse: Codable, Equatable {
    let messages: [Message]
    let totalCount: Int
    let hasNextPage: Bool
    
    enum CodingKeys: String, CodingKey {
        case messages
        case totalCount = "total_count"
        case hasNextPage = "has_next_page"
    }
}