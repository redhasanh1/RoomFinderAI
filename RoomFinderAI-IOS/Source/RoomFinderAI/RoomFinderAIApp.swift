import SwiftUI
import Supabase

// MARK: - Secrets Configuration
enum Secrets {
  static let supabaseURL = "https://fkktwhjybuflxqzopaex.supabase.co"
  static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"

  // 🚀 OpenAI (inserted credentials)
  static let openAIKey = "sk-proj-CbQtehx5UM0V9mXWrdZnM-hP3l98a0ZVguNWb51K7G63M0dfChAziWYeIO_AOPE2cEnVGOcwyT3BlbkFJliQDGy85OmZ3UGhQS7RSltE9YKO_5qrdLaLEweqkbxs-dDtMy3FMf6Msuot00O58p9L9XQBucA"
  static let openAIOrgID: String? = "org-EPHQ1A3u0XIUZml6JABMgZzg"
  static let openAIModel = "gpt-4o-mini"

  static func assertValid() {
    precondition(supabaseURL.hasPrefix("https://"), "Supabase URL must start with https://")
    precondition(supabaseURL.contains(".supabase.co"), "Must use .supabase.co domain")
    precondition(URL(string: supabaseURL)?.host?.hasSuffix(".supabase.co") == true, "Invalid host in Supabase URL")
    precondition(!supabaseAnonKey.isEmpty, "Anon key is empty")
    
    // OpenAI validation (fail loudly if missing)
    precondition(!openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                 "OPENAI key is missing. Update Secrets.openAIKey")
    precondition(openAIKey.hasPrefix("sk-"), "Invalid OpenAI API key format. Must start with 'sk-'.")
  }
}

enum SupabaseFactory {
    static func makeClient() -> SupabaseClient {
        Secrets.assertValid()
        let url = URL(string: Secrets.supabaseURL)!
        return SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
    }
}

// MARK: - Environment Key
private struct SupabaseClientKey: EnvironmentKey {
    static let defaultValue: SupabaseClient = {
        let url = URL(string: "https://invalid.local")!
        return SupabaseClient(supabaseURL: url, supabaseKey: "invalid")
    }()
}

extension EnvironmentValues {
    var supabase: SupabaseClient {
        get { self[SupabaseClientKey.self] }
        set { self[SupabaseClientKey.self] = newValue }
    }
}

// MARK: - Models
struct MediaItem: Decodable, Equatable {
  let url: String?
}

struct HomePageListing: Identifiable, Decodable, Equatable {
  let id: UUID
  let title: String?
  let price: Int?
  let city: String?
  let house_type: String?
  let bedrooms: Int?
  let description: String?
  let created_at: String?
  let media: [MediaItem]?

  var coverURLString: String? { media?.first?.url }
}

// MARK: - Simple AI Negotiator View
struct SimpleAINegotiatorView: View {
  let listing: HomePageListing
  @State private var messageText = ""
  @State private var messages: [String] = []
  @State private var isLoading = false
  
  var body: some View {
    VStack {
      // Header
      HStack {
        VStack(alignment: .leading) {
          Text("Negotiating: \(listing.title ?? "Property")")
            .font(.headline)
          Text("$\(listing.price ?? 0)/mo")
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        Spacer()
      }
      .padding()
      
      // Messages
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(messages.indices, id: \.self) { index in
            Text(messages[index])
              .padding()
              .background(Color.gray.opacity(0.1))
              .cornerRadius(8)
          }
        }
        .padding()
      }
      
      Spacer()
      
      // Input
      HStack {
        TextField("Type your message...", text: $messageText)
          .textFieldStyle(RoundedBorderTextFieldStyle())
        
        Button("Send") {
          sendMessage()
        }
        .disabled(messageText.isEmpty || isLoading)
      }
      .padding()
    }
    .navigationTitle("AI Negotiator")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      // Add welcome message
      messages.append("👋 Hi! I'm your AI Negotiator. How can I help you with this property?")
    }
  }
  
  private func sendMessage() {
    guard !messageText.isEmpty else { return }
    
    let userMessage = messageText
    messages.append("You: \(userMessage)")
    messageText = ""
    isLoading = true
    
    Task {
      do {
        let aiResponse = try await getAIResponse(for: userMessage)
        await MainActor.run {
          messages.append("AI: \(aiResponse)")
          isLoading = false
        }
      } catch {
        await MainActor.run {
          messages.append("AI: Sorry, I'm having trouble connecting. Please try again.")
          isLoading = false
        }
      }
    }
  }
  
  private func getAIResponse(for message: String) async throws -> String {
    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")
    if let orgID = Secrets.openAIOrgID {
      request.setValue(orgID, forHTTPHeaderField: "OpenAI-Organization")
    }
    
    let body = [
      "model": Secrets.openAIModel,
      "messages": [
        [
          "role": "system",
          "content": "You are a helpful AI negotiator assistant helping with property rentals. Keep responses concise and helpful."
        ],
        [
          "role": "user", 
          "content": "Property: \(listing.title ?? "Unknown"), Price: $\(listing.price ?? 0)/mo. User message: \(message)"
        ]
      ],
      "max_tokens": 150
    ] as [String: Any]
    
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await URLSession.shared.data(for: request)
    
    struct OpenAIResponse: Decodable {
      struct Choice: Decodable {
        struct Message: Decodable {
          let content: String
        }
        let message: Message
      }
      let choices: [Choice]
    }
    
    let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
    return response.choices.first?.message.content ?? "I'm not sure how to help with that."
  }
}

// MARK: - Main Views
struct HomeScreen: View {
  @State private var listings: [HomePageListing] = []
  @State private var isLoading = true
  @State private var error: String?
  @Environment(\.supabase) private var supabase

  var body: some View {
    NavigationView {
      VStack {
        if isLoading {
          ProgressView("Loading listings...")
        } else if let error = error {
          VStack {
            Text("Error: \(error)")
              .foregroundColor(.red)
            Button("Retry") {
              loadListings()
            }
          }
        } else {
          List(listings) { listing in
            ListingCardView(listing: listing)
              .listRowSeparator(.hidden)
              .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
          }
          .listStyle(PlainListStyle())
        }
      }
      .navigationTitle("RoomFinder")
      .onAppear {
        loadListings()
      }
    }
  }

  private func loadListings() {
    isLoading = true
    error = nil
    
    Task {
      do {
        let response: [HomePageListing] = try await supabase
          .from("listings")
          .select("*")
          .execute()
          .value
        
        await MainActor.run {
          self.listings = response
          self.isLoading = false
        }
      } catch {
        await MainActor.run {
          self.error = error.localizedDescription
          self.isLoading = false
        }
      }
    }
  }
}

struct ListingCardView: View {
  let listing: HomePageListing
  @State private var imageURL: URL?
  @Environment(\.supabase) private var supabase

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Image
      AsyncImage(url: imageURL) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        placeholder
      }
      .frame(height: 200)
      .clipShape(RoundedRectangle(cornerRadius: 12))

      // Content
      VStack(alignment: .leading, spacing: 6) {
        Text(listing.title ?? "Untitled")
          .font(.headline)
          .lineLimit(2)

        HStack(spacing: 8) {
          if let price = listing.price { Text("$\(price)") }
          if let type = listing.house_type { Text("· \(type)") }
          if let bd = listing.bedrooms { Text("· \(bd) bd") }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)

        // Negotiate button
        HStack {
          Spacer()
          NavigationLink(destination: SimpleAINegotiatorView(listing: listing)) {
            HStack(spacing: 4) {
              Image(systemName: "brain")
              Text("Negotiate")
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
        }
      }
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.black.opacity(0.06)))
    .task {
      if let s = listing.coverURLString, let u = URL(string: s) { imageURL = u }
    }
  }

  private var placeholder: some View {
    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
  }
}

// MARK: - App
@main
struct MyApp: App {
  private let supabase = SupabaseFactory.makeClient()
  
  init() {
    // Assert OpenAI credentials are configured at startup (fail fast)
    Secrets.assertValid()
    
    // Debug: Confirm OpenAI integration is ready
    print("🚀 AI Negotiator ready with OpenAI credentials configured!")
  }
  
  var body: some Scene {
    WindowGroup {
      HomeScreen()
        .environment(\.supabase, supabase)
    }
  }
}