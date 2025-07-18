import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                // Segment Control
                Picker("Chat Type", selection: $selectedTab) {
                    Text("Messages").tag(0)
                    Text("AI Assistant").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    MessagesListView()
                        .tag(0)
                    
                    AIChatsListView()
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MessagesListView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var showingChatDetail = false
    @State private var selectedChat: Chat?
    
    var body: some View {
        VStack {
            if chatViewModel.isLoading && chatViewModel.chats.isEmpty {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if chatViewModel.chats.isEmpty {
                Spacer()
                EmptyStateView(
                    title: "No messages yet",
                    subtitle: "Start a conversation with a landlord to see your messages here",
                    icon: "message"
                )
                Spacer()
            } else {
                List(chatViewModel.chats) { chat in
                    Button(action: {
                        selectedChat = chat
                        showingChatDetail = true
                    }) {
                        ChatRowView(chat: chat)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await chatViewModel.refreshChats()
                }
            }
        }
        .sheet(isPresented: $showingChatDetail) {
            if let chat = selectedChat {
                ChatDetailView(chat: chat)
            }
        }
    }
}

struct AIChatsListView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var showingAIChat = false
    @State private var selectedAIChat: AIChat?
    
    var body: some View {
        VStack {
            if chatViewModel.aiChats.isEmpty {
                Spacer()
                EmptyStateView(
                    title: "No AI chats yet",
                    subtitle: "Start a conversation with our AI assistant to get personalized help",
                    icon: "brain.head.profile"
                )
                
                Button("Start AI Chat") {
                    chatViewModel.createNewAIChat()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.primaryBlue)
                .cornerRadius(12)
                .padding()
                
                Spacer()
            } else {
                List(chatViewModel.aiChats) { aiChat in
                    Button(action: {
                        selectedAIChat = aiChat
                        showingAIChat = true
                    }) {
                        AIChatRowView(aiChat: aiChat)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showingAIChat) {
            if let aiChat = selectedAIChat {
                AIChatDetailView(aiChat: aiChat)
            }
        }
    }
}

struct ChatRowView: View {
    let chat: Chat
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: URL(string: chat.participants.first?.avatar ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let lastMessage = chat.lastMessage {
                        Text(lastMessage.timestamp.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let lastMessage = chat.lastMessage {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Unread Badge
            if chat.unreadCount > 0 {
                Text("\(chat.unreadCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 8)
    }
}

struct AIChatRowView: View {
    let aiChat: AIChat
    
    var body: some View {
        HStack(spacing: 12) {
            // AI Avatar
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.primaryBlue)
                .frame(width: 50, height: 50)
                .background(Color.primaryBlue.opacity(0.1))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(aiChat.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(aiChat.updatedAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let lastMessage = aiChat.messages.last {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Status
                Text(aiChat.status.displayName)
                    .font(.caption)
                    .foregroundColor(.primaryBlue)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ChatDetailView: View {
    let chat: Chat
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                // Messages
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatViewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
                
                // Input
                MessageInputView()
            }
            .navigationTitle(chat.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Back") {
                    dismiss()
                }
            )
        }
        .onAppear {
            chatViewModel.selectChat(chat)
        }
    }
}

struct AIChatDetailView: View {
    let aiChat: AIChat
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                // Messages
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatViewModel.aiMessages) { message in
                            AIMessageBubble(message: message)
                        }
                        
                        if chatViewModel.isAIResponding {
                            AITypingIndicator()
                        }
                    }
                    .padding()
                }
                
                // Input
                AIMessageInputView()
            }
            .navigationTitle(aiChat.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Back") {
                    dismiss()
                }
            )
        }
        .onAppear {
            chatViewModel.selectAIChat(aiChat)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.senderId == "current_user_id" {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.primaryBlue)
                        .cornerRadius(18, corners: [.topLeft, .topRight, .bottomLeft])
                    
                    Text(message.timestamp.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
                    
                    Text(message.timestamp.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

struct AIMessageBubble: View {
    let message: AIMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.primaryBlue)
                        .cornerRadius(18, corners: [.topLeft, .topRight, .bottomLeft])
                    
                    Text(message.timestamp.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                        .foregroundColor(.primaryBlue)
                        .frame(width: 30, height: 30)
                        .background(Color.primaryBlue.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
                        
                        Text(message.timestamp.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
    }
}

struct MessageInputView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $chatViewModel.messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button(action: {
                chatViewModel.sendMessage()
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundColor(.primaryBlue)
            }
            .disabled(!chatViewModel.canSendMessage)
            .opacity(chatViewModel.canSendMessage ? 1.0 : 0.5)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct AIMessageInputView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask AI anything...", text: $chatViewModel.messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button(action: {
                chatViewModel.sendAIMessage()
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundColor(.primaryBlue)
            }
            .disabled(!chatViewModel.canSendMessage || chatViewModel.isAIResponding)
            .opacity(chatViewModel.canSendMessage && !chatViewModel.isAIResponding ? 1.0 : 0.5)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct AITypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.primaryBlue)
                    .frame(width: 30, height: 30)
                    .background(Color.primaryBlue.opacity(0.1))
                    .clipShape(Circle())
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 8, height: 8)
                            .offset(y: animationOffset)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animationOffset
                            )
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])
            }
            
            Spacer()
        }
        .onAppear {
            animationOffset = -4
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(ChatViewModel())
}