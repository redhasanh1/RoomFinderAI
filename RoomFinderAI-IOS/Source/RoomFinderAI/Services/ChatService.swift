import Foundation
import Supabase

// MARK: - Database Models
struct DatabaseConversation: Codable {
    let id: String
    let listing_id: String
    let sender_email: String
    let receiver_email: String
    let created_at: String  // Changed from Date to String for proper Supabase decoding
}

struct DatabaseMessage: Codable {
    let id: String
    let sender_email: String
    let content: String
    let message_type: String
    let created_at: String  // Changed from Date to String for proper Supabase decoding
}

struct DatabaseMessageInsert: Codable {
    let id: String
    let conversation_id: String
    let sender_email: String
    let content: String
    let message_type: String
    let created_at: String
}

class ChatService: ObservableObject {
    var supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    // MARK: - Conversation Management
    
    func fetchPropertyConversations() async throws -> [ChatConversation] {
        // Get current user email from auth or settings
        let currentUserEmail = "zacoda1@hotmail.com" // You can make this dynamic later
        
        // Set user context for RLS (Row Level Security)
        _ = try supabase.rpc("set_current_user_email", params: ["email": currentUserEmail])
        
        // Query conversations where user is either sender or receiver
        let conversationsResponse: [DatabaseConversation] = try await supabase
            .from("conversations")
            .select("id, listing_id, sender_email, receiver_email, created_at")
            .or("sender_email.eq.\(currentUserEmail),receiver_email.eq.\(currentUserEmail)")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        var chatConversations: [ChatConversation] = []
        
        // For each conversation, get the latest message, listing, and user info
        for conversation in conversationsResponse {
            let otherUserEmail = conversation.sender_email == currentUserEmail 
                ? conversation.receiver_email 
                : conversation.sender_email
            
            // Get the latest message for this conversation
            let latestMessages: [DatabaseMessage] = try await supabase
                .from("messages")
                .select("id, sender_email, content, message_type, created_at")
                .eq("conversation_id", value: conversation.id)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            let latestMessage = latestMessages.first
            
            let chatMessage: ChatMessage? = latestMessage.map { msg in
                let formatter = ISO8601DateFormatter()
                let messageDate = formatter.date(from: msg.created_at) ?? Date()
                
                return ChatMessage(
                    id: msg.id,
                    conversationId: conversation.id,
                    senderId: msg.sender_email,
                    content: msg.content,
                    messageType: ChatMessage.MessageType(rawValue: msg.message_type) ?? .text,
                    timestamp: messageDate,
                    isRead: msg.sender_email == currentUserEmail,
                    replyToId: nil,
                    attachments: nil
                )
            }
            
            // Parse conversation date
            let formatter = ISO8601DateFormatter()
            let conversationDate = formatter.date(from: conversation.created_at) ?? Date()
            let lastActivityDate = latestMessage.flatMap { formatter.date(from: $0.created_at) } ?? conversationDate
            
            // Determine conversation type based on whether it has a listing_id
            let conversationType: ChatConversation.ConversationType = conversation.listing_id != nil ? .listing : .user
            
            // Create basic chat conversation
            let chatConversation = ChatConversation(
                id: conversation.id,
                participantIds: [conversation.sender_email, conversation.receiver_email],
                lastMessage: chatMessage,
                lastActivity: lastActivityDate,
                isRead: latestMessage?.sender_email == currentUserEmail ? true : false,
                conversationType: conversationType,
                title: otherUserEmail,
                groupImage: nil,
                listingId: conversation.listing_id
            )
            
            // Add the chat conversation to our results
            chatConversations.append(chatConversation)
        }
        
        // Sort by most recent activity
        chatConversations.sort { $0.lastActivity > $1.lastActivity }
        
        return chatConversations
    }
    
    // Keep the original method for backwards compatibility
    func fetchConversations() async throws -> [ChatConversation] {
        return try await fetchPropertyConversations()
    }
    
    func createConversation(request: CreateConversationRequest) async throws -> ChatConversation {
        // Mock implementation - would use Supabase in production
        let conversation = ChatConversation(
            id: UUID().uuidString,
            participantIds: request.participantIds,
            lastMessage: nil,
            lastActivity: Date(),
            isRead: true,
            conversationType: request.conversationType,
            title: request.title,
            groupImage: nil,
            listingId: nil
        )
        return conversation
    }
    
    // MARK: - Message Management
    
    func fetchMessages(for conversationId: String) async throws -> [ChatMessage] {
        let currentUserEmail = "zacoda1@hotmail.com"
        
        // Set user context for RLS (Row Level Security)
        _ = try supabase.rpc("set_current_user_email", params: ["email": currentUserEmail])
        
        // Query all messages for this conversation
        let messagesResponse: [DatabaseMessage] = try await supabase
            .from("messages")
            .select("id, sender_email, content, message_type, created_at")
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: true) // Oldest first for chat display
            .execute()
            .value
        
        // Convert to ChatMessage objects
        let chatMessages = messagesResponse.map { msg in
            let formatter = ISO8601DateFormatter()
            let messageDate = formatter.date(from: msg.created_at) ?? Date()
            
            return ChatMessage(
                id: msg.id,
                conversationId: conversationId,
                senderId: msg.sender_email,
                content: msg.content,
                messageType: ChatMessage.MessageType(rawValue: msg.message_type) ?? .text,
                timestamp: messageDate,
                isRead: true, // Assume messages are read when viewing conversation
                replyToId: nil,
                attachments: nil
            )
        }
        
        return chatMessages
    }
    
    func sendMessage(request: SendMessageRequest) async throws -> ChatMessage {
        let currentUserEmail = "zacoda1@hotmail.com" // Make this dynamic later
        let messageId = UUID().uuidString
        
        // Set user context for RLS (Row Level Security)
        _ = try supabase.rpc("set_current_user_email", params: ["email": currentUserEmail])
        
        // Insert message into database
        let messageData = DatabaseMessageInsert(
            id: messageId,
            conversation_id: request.conversationId,
            sender_email: currentUserEmail,
            content: request.content,
            message_type: request.messageType.rawValue,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await supabase
            .from("messages")
            .insert(messageData)
            .execute()
        
        // Return the created message
        let message = ChatMessage(
            id: messageId,
            conversationId: request.conversationId,
            senderId: currentUserEmail,
            content: request.content,
            messageType: request.messageType,
            timestamp: Date(),
            isRead: false,
            replyToId: request.replyToId,
            attachments: nil
        )
        return message
    }
    
    func markMessageAsRead(messageId: String) async throws {
        // Would update message status in Supabase
    }
    
    // MARK: - User Management
    
    func fetchUsers() async throws -> [ChatUser] {
        return mockUsers()
    }
    
    func searchUsers(query: String) async throws -> [ChatUser] {
        let allUsers = try await fetchUsers()
        return allUsers.filter { user in
            user.displayNameOrEmail.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Mock Data (for development)
    
    private func mockConversations() -> [ChatConversation] {
        return [
            ChatConversation(
                id: "conv1",
                participantIds: ["user1", "current_user"],
                lastMessage: ChatMessage(
                    id: "msg1",
                    conversationId: "conv1",
                    senderId: "user1",
                    content: "Hi! Is the apartment still available?",
                    messageType: .text,
                    timestamp: Date().addingTimeInterval(-3600),
                    isRead: false,
                    replyToId: nil,
                    attachments: nil
                ),
                lastActivity: Date().addingTimeInterval(-3600),
                isRead: false,
                conversationType: .listing,
                title: "John Smith (Landlord)",
                groupImage: nil,
                listingId: "550e8400-e29b-41d4-a716-446655440000"
            ),
            ChatConversation(
                id: "conv2",
                participantIds: ["user2", "current_user"],
                lastMessage: ChatMessage(
                    id: "msg2",
                    conversationId: "conv2",
                    senderId: "current_user",
                    content: "Thanks for the info!",
                    messageType: .text,
                    timestamp: Date().addingTimeInterval(-7200),
                    isRead: true,
                    replyToId: nil,
                    attachments: nil
                ),
                lastActivity: Date().addingTimeInterval(-7200),
                isRead: true,
                conversationType: .user,
                title: "Sarah Wilson",
                groupImage: nil,
                listingId: nil
            ),
            ChatConversation(
                id: "conv3",
                participantIds: ["user3", "current_user"],
                lastMessage: ChatMessage(
                    id: "msg3",
                    conversationId: "conv3",
                    senderId: "user3",
                    content: "📷 Image",
                    messageType: .image,
                    timestamp: Date().addingTimeInterval(-86400),
                    isRead: true,
                    replyToId: nil,
                    attachments: nil
                ),
                lastActivity: Date().addingTimeInterval(-86400),
                isRead: true,
                conversationType: .listing,
                title: "Mike Johnson (Agent)",
                groupImage: nil,
                listingId: "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
            )
        ]
    }
    
    private func mockMessages(for conversationId: String) -> [ChatMessage] {
        switch conversationId {
        case "conv1":
            return [
                ChatMessage(
                    id: "msg1_1",
                    conversationId: conversationId,
                    senderId: "current_user",
                    content: "Hello! I'm interested in your 2BR apartment listing.",
                    messageType: .text,
                    timestamp: Date().addingTimeInterval(-7200),
                    isRead: true,
                    replyToId: nil,
                    attachments: nil
                ),
                ChatMessage(
                    id: "msg1_2",
                    conversationId: conversationId,
                    senderId: "user1",
                    content: "Hi! Yes, it's still available. When would you like to schedule a viewing?",
                    messageType: .text,
                    timestamp: Date().addingTimeInterval(-5400),
                    isRead: true,
                    replyToId: nil,
                    attachments: nil
                ),
                ChatMessage(
                    id: "msg1_3",
                    conversationId: conversationId,
                    senderId: "current_user",
                    content: "How about this weekend? Saturday afternoon works best for me.",
                    messageType: .text,
                    timestamp: Date().addingTimeInterval(-3600),
                    isRead: true,
                    replyToId: nil,
                    attachments: nil
                ),
                ChatMessage(
                    id: "msg1_4",
                    conversationId: conversationId,
                    senderId: "user1",
                    content: "Perfect! Saturday at 2 PM works. I'll send you the address.",
                    messageType: .text,
                    timestamp: Date().addingTimeInterval(-1800),
                    isRead: false,
                    replyToId: nil,
                    attachments: nil
                )
            ]
        default:
            return []
        }
    }
    
    private func mockUsers() -> [ChatUser] {
        return [
            ChatUser(
                id: "user1",
                email: "john.smith@email.com",
                displayName: "John Smith",
                username: nil,
                avatarUrl: nil,
                isOnline: true,
                lastSeen: Date(),
                userType: .landlord
            ),
            ChatUser(
                id: "user2",
                email: "sarah.wilson@email.com",
                displayName: "Sarah Wilson",
                username: nil,
                avatarUrl: nil,
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-3600),
                userType: .tenant
            ),
            ChatUser(
                id: "user3",
                email: "mike.johnson@email.com",
                displayName: "Mike Johnson",
                username: nil,
                avatarUrl: nil,
                isOnline: true,
                lastSeen: Date(),
                userType: .agent
            )
        ]
    }
}