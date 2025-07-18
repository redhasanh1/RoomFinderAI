import Foundation
import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var currentChat: Chat?
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isTyping = false
    
    // AI Chat Properties
    @Published var aiChats: [AIChat] = []
    @Published var currentAIChat: AIChat?
    @Published var aiMessages: [AIMessage] = []
    @Published var isAIResponding = false
    
    // Message Input
    @Published var messageText = ""
    @Published var selectedAttachments: [URL] = []
    
    private let supabaseService = SupabaseService.shared
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadInitialData()
        setupMessageInputBinding()
    }
    
    private func setupMessageInputBinding() {
        $messageText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.handleTypingIndicator(isTyping: !text.isEmpty)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadInitialData() {
        Task {
            await loadChats()
            await loadAIChats()
        }
    }
    
    func selectChat(_ chat: Chat) {
        currentChat = chat
        Task {
            await loadMessages(for: chat.id)
        }
    }
    
    func selectAIChat(_ aiChat: AIChat) {
        currentAIChat = aiChat
        aiMessages = aiChat.messages
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let chatId = currentChat?.id else { return }
        
        Task {
            await sendMessageToChat(chatId: chatId, content: messageText)
        }
    }
    
    func sendAIMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            await sendMessageToAI(content: messageText)
        }
    }
    
    func createNewChat(with participantIds: [String], listingId: String? = nil) {
        Task {
            await createChat(participantIds: participantIds, listingId: listingId)
        }
    }
    
    func createNewAIChat(title: String = "New AI Chat") {
        Task {
            await createAIChat(title: title)
        }
    }
    
    func loadMoreMessages() {
        guard let chatId = currentChat?.id else { return }
        
        Task {
            await loadMessages(for: chatId, append: true)
        }
    }
    
    func refreshChats() {
        Task {
            await loadChats()
        }
    }
    
    func markMessagesAsRead(messageIds: [String]) {
        Task {
            await markAsRead(messageIds: messageIds)
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadChats() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let userId = getCurrentUserId() else {
                throw ChatError.userNotAuthenticated
            }
            
            chats = try await supabaseService.fetchChats(userEmail: userId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    @MainActor
    private func loadAIChats() async {
        do {
            guard let userId = getCurrentUserId() else {
                throw ChatError.userNotAuthenticated
            }
            
            aiChats = try await supabaseService.fetchAIChats(userId: userId)
        } catch {
            print("Error loading AI chats: \(error)")
        }
    }
    
    @MainActor
    private func loadMessages(for chatId: String, append: Bool = false) async {
        if !append {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let page = append ? (messages.count / 50) + 1 : 1
            let response = try await supabaseService.fetchMessages(conversationId: chatId, page: page)
            
            if append {
                messages.insert(contentsOf: response.messages, at: 0)
            } else {
                messages = response.messages
            }
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    @MainActor
    private func sendMessageToChat(chatId: String, content: String) async {
        let tempMessage = createTempMessage(content: content)
        messages.append(tempMessage)
        messageText = ""
        
        do {
            let request = SendMessageRequest(
                chatId: chatId,
                content: content,
                messageType: .text,
                replyTo: nil,
                attachments: selectedAttachments.isEmpty ? nil : selectedAttachments.map { $0.absoluteString }
            )
            
            let sentMessage = try await supabaseService.sendMessage(request: request)
            
            // Replace temp message with actual message
            if let index = messages.firstIndex(where: { $0.id == tempMessage.id }) {
                messages[index] = sentMessage
            }
            
            // Update chat's last message
            updateChatLastMessage(chatId: chatId, message: sentMessage)
            
            selectedAttachments.removeAll()
        } catch {
            // Remove temp message on error
            messages.removeAll { $0.id == tempMessage.id }
            messageText = content
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    private func sendMessageToAI(content: String) async {
        guard let currentAIChat = currentAIChat else { return }
        
        let userMessage = AIMessage(
            id: UUID().uuidString,
            role: .user,
            content: content,
            timestamp: Date(),
            metadata: nil
        )
        
        aiMessages.append(userMessage)
        messageText = ""
        isAIResponding = true
        
        do {
            let aiMessage = try await supabaseService.sendAIMessage(chatId: currentAIChat.id, message: content)
            
            // Simulate AI response (in real app, this would be handled by the backend)
            let aiResponse = AIMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: generateAIResponse(for: content),
                timestamp: Date(),
                metadata: AIMessageMetadata(
                    tokens: 150,
                    model: "gpt-4",
                    temperature: 0.7,
                    confidence: 0.85,
                    processingTime: 1.2
                )
            )
            
            aiMessages.append(aiResponse)
            isAIResponding = false
        } catch {
            isAIResponding = false
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    private func createChat(participantIds: [String], listingId: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let request = CreateChatRequest(
                participantIds: participantIds,
                listingId: listingId,
                title: nil,
                isGroupChat: participantIds.count > 2
            )
            
            let newChat = try await supabaseService.createChat(request: request)
            chats.insert(newChat, at: 0)
            currentChat = newChat
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    @MainActor
    private func createAIChat(title: String) async {
        guard let userId = getCurrentUserId() else { return }
        
        let newAIChat = AIChat(
            id: UUID().uuidString,
            userId: userId,
            title: title,
            messages: [],
            context: nil,
            createdAt: Date(),
            updatedAt: Date(),
            status: .active
        )
        
        aiChats.insert(newAIChat, at: 0)
        currentAIChat = newAIChat
        aiMessages = []
    }
    
    @MainActor
    private func markAsRead(messageIds: [String]) async {
        do {
            let request = MarkAsReadRequest(messageIds: messageIds)
            // This would typically call the Supabase service to mark messages as read
            
            // Update local state
            for messageId in messageIds {
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[index] = Message(
                        id: messages[index].id,
                        chatId: messages[index].chatId,
                        senderId: messages[index].senderId,
                        senderName: messages[index].senderName,
                        content: messages[index].content,
                        messageType: messages[index].messageType,
                        attachments: messages[index].attachments,
                        replyTo: messages[index].replyTo,
                        timestamp: messages[index].timestamp,
                        editedAt: messages[index].editedAt,
                        isRead: true,
                        isDelivered: messages[index].isDelivered,
                        reactions: messages[index].reactions
                    )
                }
            }
        } catch {
            print("Error marking messages as read: \(error)")
        }
    }
    
    private func handleTypingIndicator(isTyping: Bool) {
        guard let chatId = currentChat?.id else { return }
        
        self.isTyping = isTyping
        
        // In a real app, this would send typing indicator to other participants
        // via real-time subscriptions
    }
    
    private func createTempMessage(content: String) -> Message {
        return Message(
            id: UUID().uuidString,
            chatId: currentChat?.id ?? "",
            senderId: getCurrentUserId() ?? "",
            senderName: "You",
            content: content,
            messageType: .text,
            attachments: [],
            replyTo: nil,
            timestamp: Date(),
            editedAt: nil,
            isRead: false,
            isDelivered: false,
            reactions: []
        )
    }
    
    private func updateChatLastMessage(chatId: String, message: Message) {
        if let index = chats.firstIndex(where: { $0.id == chatId }) {
            chats[index] = Chat(
                id: chats[index].id,
                title: chats[index].title,
                participants: chats[index].participants,
                listingId: chats[index].listingId,
                lastMessage: message,
                unreadCount: chats[index].unreadCount,
                isGroupChat: chats[index].isGroupChat,
                createdAt: chats[index].createdAt,
                updatedAt: Date(),
                status: chats[index].status
            )
        }
    }
    
    private func generateAIResponse(for userMessage: String) -> String {
        // This is a placeholder for AI response generation
        // In a real app, this would be handled by the backend API
        let responses = [
            "I'd be happy to help you with that! Let me find some suitable options for you.",
            "Based on your preferences, I can suggest several properties that might interest you.",
            "That's a great question! Here are some things to consider...",
            "I understand your requirements. Let me search for properties that match your criteria.",
            "I can help you negotiate better terms. Here's what I recommend..."
        ]
        
        return responses.randomElement() ?? "I'm here to help you find the perfect place!"
    }
    
    private func getCurrentUserId() -> String? {
        // This would typically get the current user's ID from the auth service
        return "current_user_id"
    }
    
    // MARK: - Computed Properties
    
    var hasUnreadMessages: Bool {
        return chats.contains { $0.unreadCount > 0 }
    }
    
    var totalUnreadCount: Int {
        return chats.reduce(0) { $0 + $1.unreadCount }
    }
    
    var canSendMessage: Bool {
        return !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    var hasError: Bool {
        return errorMessage != nil
    }
    
    // MARK: - File Attachments
    
    func addAttachment(_ url: URL) {
        selectedAttachments.append(url)
    }
    
    func removeAttachment(_ url: URL) {
        selectedAttachments.removeAll { $0 == url }
    }
    
    func clearAttachments() {
        selectedAttachments.removeAll()
    }
}

enum ChatError: Error {
    case userNotAuthenticated
    case chatNotFound
    case messageNotFound
    case invalidMessageContent
    case networkError
    
    var localizedDescription: String {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .chatNotFound:
            return "Chat not found"
        case .messageNotFound:
            return "Message not found"
        case .invalidMessageContent:
            return "Invalid message content"
        case .networkError:
            return "Network error occurred"
        }
    }
}