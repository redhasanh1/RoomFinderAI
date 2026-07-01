import SwiftUI
import Supabase

struct AINegotiatorView: View {
  let listing: Listing
  let buyerEmail: String
  let buyerBudget: Double?
  
  @Environment(\.supabase) private var supabase
  @Environment(\.dismiss) private var dismiss
  @StateObject private var vm: AINegotiatorViewModel
  @State private var messageText = ""
  @State private var showingDebug = false
  
  init(listing: Listing, buyerEmail: String, buyerBudget: Double?) {
    self.listing = listing
    self.buyerEmail = buyerEmail
    self.buyerBudget = buyerBudget
    
    // Initialize with default - will be updated in task
    self._vm = StateObject(wrappedValue: AINegotiatorViewModel(
      supabase: SupabaseKey.defaultValue,
      listing: listing,
      buyerEmail: buyerEmail, 
      buyerBudget: buyerBudget
    ))
  }
  
  var body: some View {
    NavigationView {
      VStack {
        // Messages
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(vm.messages) { message in
                MessageBubbleView(message: message)
                  .id(message.id)
              }
              
              if vm.isLoading {
                HStack {
                  ProgressView()
                    .scaleEffect(0.8)
                  Text("AI is thinking...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
              }
            }
            .padding()
          }
          .onChange(of: vm.messages.count) { _ in
            if let lastMessage = vm.messages.last {
              withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
              }
            }
          }
        }
        
        // Input
        HStack {
          TextField("Type your message...", text: $messageText, axis: .vertical)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .lineLimit(1...4)
          
          Button("Send") {
            Task {
              await vm.sendMessage(messageText)
              messageText = ""
            }
          }
          .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)
          .buttonStyle(.borderedProminent)
        }
        .padding()
      }
      .navigationTitle("AI Negotiator")
      .navigationBarTitleDisplayMode(.inline) 
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Done") { dismiss() }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("ⓘ") { showingDebug = true }
        }
      }
      .sheet(isPresented: $showingDebug) {
        DebugInfoView()
      }
      .task {
        await vm.startNegotiation()
      }
    }
  }
}

struct MessageBubbleView: View {
  let message: ChatMessage
  
  var body: some View {
    HStack {
      if message.isFromUser { Spacer() }
      
      VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
        Text(message.content)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(message.isFromUser ? Color.blue : Color(.systemGray5))
          .foregroundColor(message.isFromUser ? .white : .primary)
          .clipShape(RoundedRectangle(cornerRadius: 16))
        
        Text(message.timestamp, style: .time)
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      
      if !message.isFromUser { Spacer() }
    }
  }
}

struct AINegotiatorViewPreview: View {
  var body: some View {
    Text("AI Negotiator Hub")
      .font(.title)
      .foregroundColor(.secondary)
  }
}