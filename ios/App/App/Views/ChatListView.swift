import SwiftUI

struct ChatListView: View {
    @State private var conversations: [Conversation] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { conversation in
                conversation.listing?.title.localizedCaseInsensitiveContains(searchText) == true ||
                conversation.senderEmail.localizedCaseInsensitiveContains(searchText) ||
                conversation.receiverEmail.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                if !conversations.isEmpty {
                    searchBar
                }
                
                // Content
                if isLoading {
                    loadingView
                } else if conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadConversations()
            }
            .task {
                await loadConversations()
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search conversations...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading conversations...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Messages Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start browsing properties to begin conversations with landlords")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            NavigationLink(destination: SearchView()) {
                Text("Browse Properties")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Conversations List
    
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredConversations) { conversation in
                    NavigationLink(destination: ChatDetailView(conversation: conversation)) {
                        ConversationRowView(conversation: conversation)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
    
    // MARK: - Load Data
    
    @MainActor
    private func loadConversations() async {
        isLoading = true
        
        do {
            // Call your existing web function
            let result = try await WebBridge.shared.callWebFunction("iosChatSystem.getConversations")
            
            if let conversationsResult = result as? [String: Any],
               let conversationsArray = conversationsResult["data"] as? [[String: Any]] {
                self.conversations = parseConversations(from: conversationsArray)
            }
            
        } catch {
            print("Error loading conversations: \(error)")
        }
        
        isLoading = false
    }
    
    private func parseConversations(from array: [[String: Any]]) -> [Conversation] {
        return array.compactMap { dict in
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let conversation = try? JSONDecoder().decode(Conversation.self, from: data) else {
                return nil
            }
            return conversation
        }
    }
}

// MARK: - Conversation Row View

struct ConversationRowView: View {
    let conversation: Conversation
    @State private var lastMessage = ""
    @State private var unreadCount = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Property Image
            AsyncImage(url: URL(string: conversation.listing?.imageUrl ?? "")) { image in
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
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Conversation Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.listing?.title ?? "Property Discussion")
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let lastMessageAt = conversation.lastMessageAt {
                        Text(formatDate(lastMessageAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(conversation.listing?.location ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(lastMessage.isEmpty ? "Start a conversation" : lastMessage)
                        .font(.subheadline)
                        .foregroundColor(lastMessage.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .task {
            await loadLastMessage()
        }
    }
    
    @MainActor
    private func loadLastMessage() async {
        // This would typically load the last message from the conversation
        // For now, we'll use a placeholder
        lastMessage = "Tap to start chatting..."
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Simple date formatting - you can make this more sophisticated
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        guard let date = formatter.date(from: dateString) else {
            return ""
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return timeFormatter.string(from: date)
        } else if calendar.isYesterday(date) {
            return "Yesterday"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "MMM d"
            return dayFormatter.string(from: date)
        }
    }
}

#Preview {
    ChatListView()
}