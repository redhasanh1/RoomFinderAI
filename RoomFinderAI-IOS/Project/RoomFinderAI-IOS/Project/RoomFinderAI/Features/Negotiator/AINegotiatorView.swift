import SwiftUI
import Supabase

// MARK: - AI Negotiator View
struct AINegotiatorView: View {
    @StateObject private var viewModel: AINegotiatorViewModel
    @Environment(\.supabase) private var supabase
    @State private var showingExportSheet = false
    @State private var exportedText = ""
    
    // Parameters for automatic negotiation start
    private let autoStartParams: AutoStartParams?
    
    private struct AutoStartParams {
        let conversationId: UUID
        let listing: NegotiationListing
        let budget: Double
        let userEmail: String
    }
    
    init(supabase: SupabaseClient) {
        self._viewModel = StateObject(wrappedValue: AINegotiatorViewModel(supabase: supabase))
        self.autoStartParams = nil
    }
    
    init(conversationId: UUID, listing: Listing, budget: Double, userEmail: String) {
        // Convert Listing to NegotiationListing
        let negotiationListing = NegotiationListing(
            id: UUID(uuidString: listing.id) ?? UUID(),
            title: listing.title,
            price: Int(listing.price),
            city: listing.city,
            bedrooms: listing.bedrooms,
            houseType: listing.houseType,
            description: listing.description,
            media: nil, // Will be loaded separately if needed
            createdAt: nil
        )
        
        // Create a mock Supabase client (this will be replaced by the environment)
        let mockSupabase = SupabaseClient(
            supabaseURL: URL(string: "https://placeholder.supabase.co")!,
            supabaseKey: "placeholder-key"
        )
        
        self._viewModel = StateObject(wrappedValue: AINegotiatorViewModel(supabase: mockSupabase))
        self.autoStartParams = AutoStartParams(
            conversationId: conversationId,
            listing: negotiationListing,
            budget: budget,
            userEmail: userEmail
        )
    }
    
    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // Left Sidebar - Found Listings
                sidebarView
                    .frame(width: 280)
                
                Divider()
                
                // Main Chat Interface
                chatView
            }
        }
        .navigationTitle("AI Negotiation Assistant")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingExportSheet) {
            exportView
        }
        .onAppear {
            // Use the environment supabase client
            viewModel.updateSupabaseClient(supabase)
            
            // Auto-start negotiation if parameters were provided
            if let params = autoStartParams {
                Task {
                    await viewModel.start(
                        conversationId: params.conversationId,
                        listing: params.listing,
                        budget: params.budget,
                        userEmail: params.userEmail
                    )
                }
            }
        }
    }
    
    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sidebar Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Found Listings")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if viewModel.foundListings.isEmpty {
                    Text("Use the AI chat to search for properties!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("\(viewModel.foundListings.count) properties found")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Found Listings
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.foundListings) { listing in
                        FoundListingCard(listing: listing) {
                            startNegotiation(for: listing)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
            
            // Market Stats (if available)
            if let stats = viewModel.marketStats {
                marketStatsView(stats)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Chat View
    private var chatView: some View {
        VStack(spacing: 0) {
            // Chat Header
            chatHeader
            
            Divider()
            
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatMessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if viewModel.isLoading {
                            ProgressView("Processing...")
                                .padding()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    // Auto-scroll to bottom when new message arrives
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Message Input
            messageInputView
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Chat Header
    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Negotiation Assistant")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Ready to Help")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Clear Chat") {
                    viewModel.clearChat()
                }
                .foregroundColor(.secondary)
                
                Button("Save Chat") {
                    exportedText = viewModel.exportChatHistory()
                    showingExportSheet = true
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Message Input
    private var messageInputView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                TextField("Type your message here...", text: $viewModel.messageText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                    .disabled(viewModel.isLoading)
                
                Button {
                    Task {
                        await viewModel.sendUserMessage(viewModel.messageText)
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            viewModel.canSendMessage ? Color.blue : Color.gray,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .disabled(!viewModel.canSendMessage || viewModel.isLoading)
            }
            
            HStack {
                Text("Press Enter to send • Max \(NegotiatorConfig.maxMessageLength) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(viewModel.characterCount)
                    .font(.caption)
                    .foregroundColor(viewModel.isCharacterLimitExceeded ? .red : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Market Stats View
    private func marketStatsView(_ stats: MarketStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Market Data")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(spacing: 4) {
                HStack {
                    Text("Average:")
                    Spacer()
                    Text(stats.averagePrice)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Range:")
                    Spacer()
                    Text(stats.priceRange)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Sample:")
                    Spacer()
                    Text("\(stats.count) listings")
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if let analysis = stats.analysis {
                Text(analysis)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Export View
    private var exportView: some View {
        NavigationView {
            ScrollView {
                Text(exportedText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("Chat Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingExportSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func startNegotiation(for listing: NegotiationListing) {
        Task {
            let conversationId = UUID()
            let userEmail = "user@example.com" // This would come from SafeAuthAdapter in production
            
            await viewModel.start(
                conversationId: conversationId,
                listing: listing,
                budget: viewModel.userBudget,
                userEmail: userEmail
            )
        }
    }
}

// MARK: - Found Listing Card
struct FoundListingCard: View {
    let listing: NegotiationListing
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(listing.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                
                // Price and Location
                HStack {
                    Text(listing.displayPrice)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text(listing.displayLocation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Details
                if let bedrooms = listing.bedrooms, let houseType = listing.houseType {
                    Text("\(bedrooms) bed • \(houseType)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Action indicator
                HStack {
                    Text("Tap to negotiate")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                userBubble
            } else {
                aiBubble
                Spacer()
            }
        }
    }
    
    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
    
    private var aiBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.type != .typing {
                Text("AI Assistant")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if message.type == .typing {
                    typingIndicator
                } else {
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
                }
            }
            
            if message.type != .typing {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
    }
    
    private var typingIndicator: some View {
        HStack(spacing: 8) {
            Text("Assistant is typing")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(typingScale)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: typingScale
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            withAnimation {
                typingScale = 1.2
            }
        }
    }
    
    @State private var typingScale: CGFloat = 0.8
}

// MARK: - Preview
struct AINegotiatorView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock Supabase client for preview
        let mockSupabase = SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "mock-key"
        )
        
        AINegotiatorView(supabase: mockSupabase)
            .previewDisplayName("AI Negotiator")
    }
}