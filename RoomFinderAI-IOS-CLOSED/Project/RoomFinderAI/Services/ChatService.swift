import Foundation
import Supabase

class ChatService: ObservableObject {
    var supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    // MARK: - Conversation Management
    
    func fetchConversations() async throws -> [ChatConversation] {
        // For now, return mock data until Supabase tables are set up
        return mockConversations()
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
            groupImage: nil
        )
        return conversation
    }
    
    // MARK: - Message Management
    
    func fetchMessages(for conversationId: String) async throws -> [ChatMessage] {
        // For now, return mock data
        return mockMessages(for: conversationId)
    }
    
    func sendMessage(request: SendMessageRequest) async throws -> ChatMessage {
        // Mock implementation - would use Supabase in production
        let message = ChatMessage(
            id: UUID().uuidString,
            conversationId: request.conversationId,
            senderId: "current_user_id", // Would get from auth
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
                conversationType: .landlord,
                title: "John Smith (Landlord)",
                groupImage: nil
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
                conversationType: .direct,
                title: "Sarah Wilson",
                groupImage: nil
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
                conversationType: .agent,
                title: "Mike Johnson (Agent)",
                groupImage: nil
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
                avatarUrl: nil,
                isOnline: true,
                lastSeen: Date(),
                userType: .landlord
            ),
            ChatUser(
                id: "user2",
                email: "sarah.wilson@email.com",
                displayName: "Sarah Wilson",
                avatarUrl: nil,
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-3600),
                userType: .tenant
            ),
            ChatUser(
                id: "user3",
                email: "mike.johnson@email.com",
                displayName: "Mike Johnson",
                avatarUrl: nil,
                isOnline: true,
                lastSeen: Date(),
                userType: .agent
            )
        ]
    }
}