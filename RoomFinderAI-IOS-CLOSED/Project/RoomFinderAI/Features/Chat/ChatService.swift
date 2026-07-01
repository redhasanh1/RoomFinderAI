import Foundation
import Supabase

// MARK: - Supabase Response Models
struct SupabaseConversation: Codable {
    let id: String
    let listing_id: String?
    let sender_email: String
    let receiver_email: String
    let created_at: String
    let tenant_id: String?
    let landlord_id: String?
    let last_read_at: String?
}

struct SupabaseMessage: Codable {
    let id: String
    let conversation_id: String
    let sender_email: String
    let content: String
    let created_at: String
    let message_type: String
    let file_name: String?
    let file_url: String?
    let file_type: String?
    let file_size: Int?
    let is_read: Bool
    let read_at: String?
}

class ChatService: ObservableObject {
    var supabase: SupabaseClient
    private let currentUserEmail = "zacoda1@hotmail.com" // Current user
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    // MARK: - Conversation Management
    
    func fetchConversations() async throws -> [ChatConversation] {
        do {
            let response: [SupabaseConversation] = try await supabase
                .from("conversations")
                .select()
                .or("sender_email.eq.\(currentUserEmail),receiver_email.eq.\(currentUserEmail)")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            return response.map { supabaseConv in
                let otherUserEmail = supabaseConv.sender_email == currentUserEmail ? 
                                   supabaseConv.receiver_email : supabaseConv.sender_email
                
                let formatter = ISO8601DateFormatter()
                let createdDate = formatter.date(from: supabaseConv.created_at) ?? Date()
                
                return ChatConversation(
                    id: supabaseConv.id,
                    participantIds: [supabaseConv.sender_email, supabaseConv.receiver_email],
                    lastMessage: nil, // Will be populated separately
                    lastActivity: createdDate,
                    isRead: true,
                    conversationType: .direct,
                    title: otherUserEmail,
                    groupImage: nil
                )
            }
        } catch {
            print("❌ Error fetching conversations: \(error)")
            throw error
        }
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
        do {
            let response: [SupabaseMessage] = try await supabase
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            return response.map { supabaseMsg in
                let formatter = ISO8601DateFormatter()
                let messageDate = formatter.date(from: supabaseMsg.created_at) ?? Date()
                
                return ChatMessage(
                    id: supabaseMsg.id,
                    conversationId: supabaseMsg.conversation_id,
                    senderId: supabaseMsg.sender_email,
                    content: supabaseMsg.content,
                    messageType: ChatMessage.MessageType(rawValue: supabaseMsg.message_type) ?? .text,
                    timestamp: messageDate,
                    isRead: supabaseMsg.is_read,
                    replyToId: nil,
                    attachments: nil
                )
            }
        } catch {
            print("❌ Error fetching messages: \(error)")
            return [] // Return empty array instead of throwing
        }
    }
    
    func sendMessage(request: SendMessageRequest) async throws -> ChatMessage {
        let messageData: [String: Any] = [
            "conversation_id": request.conversationId,
            "sender_email": currentUserEmail,
            "content": request.content,
            "message_type": request.messageType.rawValue,
            "is_read": false
        ]
        
        do {
            let response: SupabaseMessage = try await supabase
                .from("messages")
                .insert(messageData)
                .select()
                .single()
                .execute()
                .value
            
            let formatter = ISO8601DateFormatter()
            let messageDate = formatter.date(from: response.created_at) ?? Date()
            
            return ChatMessage(
                id: response.id,
                conversationId: response.conversation_id,
                senderId: response.sender_email,
                content: response.content,
                messageType: ChatMessage.MessageType(rawValue: response.message_type) ?? .text,
                timestamp: messageDate,
                isRead: response.is_read,
                replyToId: nil,
                attachments: nil
            )
        } catch {
            print("❌ Error sending message: \(error)")
            throw error
        }
    }
    
    func markMessageAsRead(messageId: String) async throws {
        // Would update message status in Supabase
    }
    
    // MARK: - User Management
    
    func fetchUsers() async throws -> [ChatUser] {
        // For now, return contacts from conversations
        let conversations = try await fetchConversations()
        var uniqueEmails = Set<String>()
        var users: [ChatUser] = []
        
        for conv in conversations {
            for email in conv.participantIds {
                if email != currentUserEmail && !uniqueEmails.contains(email) {
                    uniqueEmails.insert(email)
                    users.append(ChatUser(
                        id: email,
                        email: email,
                        displayName: email.components(separatedBy: "@").first,
                        avatarUrl: nil,
                        isOnline: false,
                        lastSeen: nil,
                        userType: .tenant
                    ))
                }
            }
        }
        return users
    }
    
    func searchUsers(query: String) async throws -> [ChatUser] {
        let allUsers = try await fetchUsers()
        return allUsers.filter { user in
            user.displayNameOrEmail.localizedCaseInsensitiveContains(query)
        }
    }
}