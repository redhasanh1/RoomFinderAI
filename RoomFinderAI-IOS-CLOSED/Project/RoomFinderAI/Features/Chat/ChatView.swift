import SwiftUI
import Supabase

struct ChatView: View {
    @Environment(\.supabase) private var supabase
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Chat Hub")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Choose how you want to communicate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Chat Options
                    VStack(spacing: 16) {
                        // AI Negotiator Card
                        NavigationLink(destination: AINegotiatorView(supabase: supabase)) {
                            ChatOptionCard(
                                title: "AI Negotiator",
                                subtitle: "Smart property search & negotiation assistance",
                                description: "Let our AI help you find properties, negotiate prices, and contact landlords automatically",
                                icon: "brain.head.profile",
                                iconColor: .blue,
                                backgroundColor: Color.blue.opacity(0.1),
                                features: ["Property Search", "Price Negotiation", "Automated Contact"]
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Normal Chat Card
                        NavigationLink(destination: NormalChatView()) {
                            ChatOptionCard(
                                title: "Direct Messages",
                                subtitle: "Chat directly with landlords & other users",
                                description: "Send messages, share photos, and communicate directly with property owners and other users",
                                icon: "message.fill",
                                iconColor: .green,
                                backgroundColor: Color.green.opacity(0.1),
                                features: ["Direct Messaging", "Photo Sharing", "Real-time Chat"]
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                    
                    // Quick Stats or Recent Activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 20) {
                            StatCard(title: "AI Conversations", value: "0", icon: "brain")
                            StatCard(title: "Messages", value: "0", icon: "message")
                            StatCard(title: "Active Chats", value: "0", icon: "person.2")
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Chat Option Card
struct ChatOptionCard: View {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let iconColor: Color
    let backgroundColor: Color
    let features: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and title
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 50, height: 50)
                    .background(backgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Description
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            
            // Features
            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(iconColor)
                        
                        Text(feature)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Normal Chat View
struct NormalChatView: View {
    @StateObject private var chatService: ChatService
    @State private var conversations: [ChatConversation] = []
    @State private var isLoading = true
    @State private var showingNewChatSheet = false
    @Environment(\.supabase) private var supabase
    
    init() {
        // Initialize with a placeholder - will be updated with environment supabase
        let mockSupabase = SupabaseClient(
            supabaseURL: URL(string: "https://placeholder.supabase.co")!,
            supabaseKey: "placeholder-key"
        )
        self._chatService = StateObject(wrappedValue: ChatService(supabase: mockSupabase))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading conversations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if conversations.isEmpty {
                emptyStateView
            } else {
                conversationListView
            }
        }
        .navigationTitle("Property Messages")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewChatSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingNewChatSheet) {
            NewChatView(chatService: chatService)
        }
        .onAppear {
            chatService.supabase = supabase
            loadConversations()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Messages Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a conversation with landlords or other users")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Start New Chat") {
                showingNewChatSheet = true
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var conversationListView: some View {
        List {
            ForEach(conversations) { conversation in
                NavigationLink(destination: IndividualChatView(conversation: conversation, chatService: chatService)) {
                    ConversationRowView(conversation: conversation)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            loadConversations()
        }
    }
    
    private func loadConversations() {
        Task {
            isLoading = true
            do {
                conversations = try await chatService.fetchConversations()
            } catch {
                print("Error loading conversations: \(error)")
                conversations = []
            }
            isLoading = false
        }
    }
}

// MARK: - Conversation Row View
struct ConversationRowView: View {
    let conversation: ChatConversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                
                Image(systemName: avatarIcon)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(conversation.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(conversation.lastMessagePreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if !conversation.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var avatarIcon: String {
        switch conversation.conversationType {
        case .landlord:
            return "house.fill"
        case .agent:
            return "person.badge.key.fill"
        case .direct, .group:
            return "person.fill"
        }
    }
}

// MARK: - Individual Chat View
struct IndividualChatView: View {
    let conversation: ChatConversation
    let chatService: ChatService
    
    @State private var messages: [ChatMessage] = []
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var propertyData: (listing: Listing?, user: User?)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Property Header (if available) - temporarily disabled
            // if let propertyData = propertyData {
            //     PropertyChatHeader(listing: propertyData.listing, user: propertyData.user)
            //     Divider()
            // }
            
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if isLoading {
                            ProgressView("Loading messages...")
                                .padding()
                        } else {
                            ForEach(messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
        }
        .navigationTitle(conversation.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMessages()
            loadPropertyConversation()
        }
    }
    
    private func loadMessages() {
        Task {
            isLoading = true
            do {
                messages = try await chatService.fetchMessages(for: conversation.id)
            } catch {
                print("Error loading messages: \(error)")
                messages = []
            }
            isLoading = false
        }
    }
    
    private func loadPropertyConversation() {
        // Temporarily disabled - will implement property data loading later
    }
    
    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        let request = SendMessageRequest(
            conversationId: conversation.id,
            content: content,
            messageType: .text,
            replyToId: nil
        )
        
        messageText = ""
        
        Task {
            do {
                let newMessage = try await chatService.sendMessage(request: request)
                messages.append(newMessage)
            } catch {
                print("Error sending message: \(error)")
            }
        }
    }
}

// MARK: - Chat Bubble View
struct ChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
                currentUserBubble
            } else {
                otherUserBubble
                Spacer()
            }
        }
    }
    
    private var currentUserBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .clipShape(
                    .rect(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 6,
                        topTrailingRadius: 18
                    )
                )
            
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
    }
    
    private var otherUserBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .clipShape(
                    .rect(
                        topLeadingRadius: 6,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: 18
                    )
                )
            
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
    }
}


// MARK: - New Chat View
struct NewChatView: View {
    let chatService: ChatService
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var users: [ChatUser] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                    .onChange(of: searchText) { newValue in
                        searchUsers(query: newValue)
                    }
                
                if isLoading {
                    ProgressView("Searching users...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if users.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No users found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if searchText.isEmpty {
                            Text("Start typing to search for users")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(users) { user in
                        UserRowView(user: user) {
                            startConversation(with: user)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            searchUsers(query: "")
        }
    }
    
    private func searchUsers(query: String) {
        Task {
            isLoading = true
            do {
                if query.isEmpty {
                    users = try await chatService.fetchUsers()
                } else {
                    users = try await chatService.searchUsers(query: query)
                }
            } catch {
                print("Error searching users: \(error)")
                users = []
            }
            isLoading = false
        }
    }
    
    private func startConversation(with user: ChatUser) {
        Task {
            do {
                let request = CreateConversationRequest(
                    participantIds: [user.id, "current_user_id"],
                    conversationType: .direct,
                    title: user.displayNameOrEmail
                )
                _ = try await chatService.createConversation(request: request)
                dismiss()
            } catch {
                print("Error creating conversation: \(error)")
            }
        }
    }
}

// MARK: - User Row View
struct UserRowView: View {
    let user: ChatUser
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 45, height: 45)
                    
                    Image(systemName: userTypeIcon)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayNameOrEmail)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(user.userType.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(userTypeColor.opacity(0.2))
                            .foregroundColor(userTypeColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        if user.isOnline {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Online")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var userTypeIcon: String {
        switch user.userType {
        case .landlord:
            return "house.fill"
        case .agent:
            return "person.badge.key.fill"
        case .tenant:
            return "person.fill"
        }
    }
    
    private var userTypeColor: Color {
        switch user.userType {
        case .landlord:
            return .blue
        case .agent:
            return .purple
        case .tenant:
            return .green
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search users...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationView {
        ChatView()
    }
}