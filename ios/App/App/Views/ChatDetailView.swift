import SwiftUI

struct ChatDetailView: View {
    let conversation: Conversation?
    let property: Property?
    
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var isLoading = true
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss
    
    // Initialize with either conversation or property
    init(conversation: Conversation) {
        self.conversation = conversation
        self.property = conversation.listing
    }
    
    init(property: Property) {
        self.conversation = nil
        self.property = property
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Property Header
            if let property = property {
                propertyHeader(property)
            }
            
            // Messages
            messagesView
            
            // Message Input
            messageInput
        }
        .navigationTitle(property?.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
        }
    }
    
    // MARK: - Property Header
    
    private func propertyHeader(_ property: Property) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: property.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "house")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(property.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(property.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            NavigationLink(destination: PropertyDetailView(property: property)) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if messages.isEmpty {
                        emptyMessagesView
                    } else {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                if let lastMessage = messages.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var emptyMessagesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Start the conversation")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Send a message to begin chatting about this property")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
    
    // MARK: - Message Input
    
    private var messageInput: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Text Input
                TextField("Type a message...", text: $newMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                
                // Send Button
                Button(action: {
                    sendMessage()
                }) {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .frame(width: 36, height: 36)
                .background(newMessage.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
                .disabled(newMessage.isEmpty || isSending)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Functions
    
    @MainActor
    private func loadMessages() async {
        guard let conversationId = conversation?.id else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        do {
            // Call your existing web function
            let result = try await WebBridge.shared.callWebFunction(
                "iosChatSystem.getMessages",
                with: ["conversationId": conversationId]
            )
            
            if let messagesResult = result as? [String: Any],
               let messagesArray = messagesResult["data"] as? [[String: Any]] {
                self.messages = parseMessages(from: messagesArray)
            }
            
        } catch {
            print("Error loading messages: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageText = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        newMessage = ""
        isSending = true
        
        Task {
            do {
                var conversationId = conversation?.id
                
                // If no conversation exists, create one first
                if conversationId == nil, let property = property {
                    let createResult = try await WebBridge.shared.callWebFunction(
                        "iosChatSystem.getOrCreateConversation",
                        with: [
                            "listingId": property.id,
                            "receiverEmail": property.userEmail ?? "owner@example.com"
                        ]
                    )
                    
                    if let convResult = createResult as? [String: Any],
                       let convData = convResult["data"] as? [String: Any],
                       let newConvId = convData["id"] as? String {
                        conversationId = newConvId
                    }
                }
                
                // Send the message
                if let convId = conversationId {
                    let result = try await WebBridge.shared.callWebFunction(
                        "iosChatSystem.sendMessage",
                        with: [
                            "conversationId": convId,
                            "content": messageText
                        ]
                    )
                    
                    // Reload messages to show the new one
                    await loadMessages()
                }
                
            } catch {
                print("Error sending message: \(error)")
            }
            
            isSending = false
        }
    }
    
    private func parseMessages(from array: [[String: Any]]) -> [Message] {
        return array.compactMap { dict in
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let message = try? JSONDecoder().decode(Message.self, from: data) else {
                return nil
            }
            return message
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    
    // This would typically come from the current user's email
    private let currentUserEmail = "current@user.com" // You'd get this from your auth system
    
    private var isFromCurrentUser: Bool {
        message.senderEmail == currentUserEmail
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private func formatTime(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        guard let date = formatter.date(from: dateString) else {
            return ""
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
}

#Preview {
    ChatDetailView(property: Property(
        id: "1",
        title: "Beautiful 2BR Apartment",
        description: "A stunning apartment",
        price: 2500,
        location: "Downtown",
        category: "apartment",
        bedrooms: 2,
        bathrooms: 2,
        imageUrl: nil,
        featured: false,
        createdAt: nil,
        userEmail: "owner@example.com"
    ))
}