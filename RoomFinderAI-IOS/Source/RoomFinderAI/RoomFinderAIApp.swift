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

// MARK: - Negotiator Config
enum NegotiatorConfig {
  static let openAIModel = Secrets.openAIModel
  static let aiEmail = "ai@roomfinder.com"
}

// Use existing Listing from Models/Listing.swift
typealias NegotiatorListing = Listing

struct Message: Identifiable, Decodable, Equatable {
  let id: UUID
  let conversation_id: UUID
  let sender_email: String
  let role: String
  let content: String
  let created_at: String
}

struct MarketStats: Decodable {
  let averagePrice: Double
  let totalListings: Int
  let priceRange: String
}

// MARK: - OpenAI Client
class OpenAIClient {
  static let shared = OpenAIClient()
  
  func textChat(model: String, system: String, user: String) async throws -> String {
    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")
    if let orgID = Secrets.openAIOrgID {
      request.setValue(orgID, forHTTPHeaderField: "OpenAI-Organization")
    }
    
    let body = [
      "model": model,
      "messages": [
        ["role": "system", "content": system],
        ["role": "user", "content": user]
      ],
      "max_tokens": 200
    ] as [String: Any]
    
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let http = response as? HTTPURLResponse else {
      throw NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
    
    guard (200...299).contains(http.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? ""
      let hint: String
      switch http.statusCode {
      case 401: hint = "Invalid OpenAI key or org id."
      case 429: hint = "Rate limited. Try again shortly."
      default: hint = "OpenAI HTTP \(http.statusCode)"
      }
      throw NSError(domain: "OpenAI", code: http.statusCode,
        userInfo: [NSLocalizedDescriptionKey: "\(hint)\n\(body)"])
    }
    
    struct OpenAIResponse: Decodable {
      struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
      }
      let choices: [Choice]
    }
    
    let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
    return decoded.choices.first?.message.content ?? "No response"
  }
  
  func healthPing() async -> String {
    do {
      _ = try await textChat(model: NegotiatorConfig.openAIModel,
                             system: "You are health check. Reply with 'pong'.",
                             user: "ping")
      return "OpenAI: OK"
    } catch { return "OpenAI: \(error.localizedDescription)" }
  }
}

// MARK: - Debug Info View
struct DebugInfoView: View {
  @Environment(\.supabase) private var supabase
  @State private var openAIStatus = "Checking…"

  var body: some View {
    List {
      Section("Config") {
        Text("Supabase URL: \(Secrets.supabaseURL)")
        Text("OpenAI Model: \(NegotiatorConfig.openAIModel)")
      }
      Section("Status") {
        Text(openAIStatus)
      }
    }
    .task {
      openAIStatus = await OpenAIClient.shared.healthPing()
    }
    .navigationTitle("Debug")
  }
}

// MARK: - AI Negotiator Service
class AINegotiatorService {
  private let supabase: SupabaseClient
  private let openAI = OpenAIClient.shared
  
  init(supabase: SupabaseClient) {
    self.supabase = supabase
  }
  
  func getMarketData(city: String?, houseType: String?, bedrooms: Int?) async throws -> MarketStats? {
    // Simple fallback market data for demo
    let avgPrice: Double = 1200
    let totalCount = 50
    
    return MarketStats(
      averagePrice: avgPrice,
      totalListings: totalCount,
      priceRange: "$1000 - $1500"
    )
  }
  
  func getAIMarketData(city: String?, houseType: String?, bedrooms: Int?, budget: Double?) async throws -> MarketStats {
    let prompt = "Provide realistic market data for \(city ?? "unknown city") \(houseType ?? "properties") with \(bedrooms ?? 1) bedrooms. Budget: $\(budget ?? 1000). Return: average_price,total_listings,price_range"
    
    let response = try await openAI.textChat(
      model: NegotiatorConfig.openAIModel,
      system: "You are a real estate market analyst. Provide realistic rental market data.",
      user: prompt
    )
    
    // Parse AI response or provide fallback
    return MarketStats(
      averagePrice: budget ?? 1200,
      totalListings: 50,
      priceRange: "$\(Int((budget ?? 1200) * 0.8)) - $\(Int((budget ?? 1200) * 1.3))"
    )
  }
  
  func firstMessage(listing: Listing, stats: MarketStats, budget: Double?) async throws -> String {
    let budgetText = budget.map { "Your budget is $\(Int($0))" } ?? "No specific budget mentioned"
    let prompt = """
    Property: \(listing.title ?? "Unknown") at $\(Int(listing.price ?? 0))/month
    Market average: $\(Int(stats.averagePrice))
    \(budgetText)
    
    Write a friendly opening message as an AI negotiator to help find the best deal.
    """
    
    return try await openAI.textChat(
      model: NegotiatorConfig.openAIModel,
      system: "You are a professional AI negotiator helping with rental properties. Be helpful and strategic.",
      user: prompt
    )
  }
  
  func sendMessage(conversationId: UUID, senderEmail: String, role: String, content: String) async throws {
    try await supabase
      .from("messages")
      .insert([
        "conversation_id": conversationId.uuidString,
        "sender_email": senderEmail,
        "role": role,
        "content": content
      ])
      .execute()
  }
}

// MARK: - AI Negotiator Bootstrap
struct AINegotiatorBootstrap: View {
  @Environment(\.supabase) private var supabase
  let listing: Listing
  let buyerEmail: String
  let buyerBudget: Double?

  @State private var conversationId: UUID?

  var body: some View {
    Group {
      if let cid = conversationId {
        AINegotiatorView(conversationId: cid, listing: listing, budget: buyerBudget, userEmail: buyerEmail)
      } else {
        ProgressView("Preparing negotiation…").task { await prepare() }
      }
    }
    .navigationBarTitleDisplayMode(.inline)
  }

  private func prepare() async {
    // Create new conversation ID for demo
    conversationId = UUID()
  }
}

// MARK: - AI Negotiator View
struct AINegotiatorView: View {
  let conversationId: UUID
  let listing: Listing
  let budget: Double?
  let userEmail: String
  
  @Environment(\.supabase) private var supabase
  @State private var messages: [Message] = []
  @State private var messageText = ""
  @State private var isLoading = false
  @State private var error: String?
  @State private var service: AINegotiatorService?
  @State private var market: MarketStats?
  
  var body: some View {
    VStack {
      // Header with property info
      VStack(alignment: .leading, spacing: 4) {
        Text(listing.title ?? "Property")
          .font(.headline)
        HStack {
          Text("$\(Int(listing.price ?? 0))/mo")
            .font(.title3)
            .fontWeight(.semibold)
          Spacer()
          if let market = market {
            Text("Avg: $\(Int(market.averagePrice))")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
      .padding()
      .background(Color(.secondarySystemBackground))
      
      // Messages
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(messages) { message in
            MessageBubble(message: message, isUser: message.role == "user")
          }
        }
        .padding()
      }
      
      if let error = error {
        Text("Error: \(error)")
          .foregroundColor(.red)
          .padding(.horizontal)
      }
      
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
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        NavigationLink(destination: DebugInfoView()) {
          Image(systemName: "info.circle")
        }
      }
    }
    .task {
      await startNegotiation()
    }
  }
  
  private func startNegotiation() async {
    service = AINegotiatorService(supabase: supabase)
    
    // Initialize empty messages for demo
    await MainActor.run {
      self.messages = []
    }
    
    // Get market data
    market = try? await service?.getMarketData(city: listing.city, houseType: listing.houseType, bedrooms: listing.bedrooms)
    if market == nil {
      market = try? await service?.getAIMarketData(city: listing.city, houseType: listing.houseType, bedrooms: listing.bedrooms, budget: budget)
    }
    
    // Send first AI message if none exists
    if messages.first(where: { $0.role == "assistant" }) == nil, 
       let m = market,
       let service = service {
      do {
        let text = try await service.firstMessage(listing: listing, stats: m, budget: budget)
        try await service.sendMessage(conversationId: conversationId, senderEmail: NegotiatorConfig.aiEmail, role: "assistant", content: text)
      } catch {
        await MainActor.run {
          self.error = "Failed to send first message: \(error.localizedDescription)"
        }
      }
    }
  }
  
  private func sendMessage() {
    guard !messageText.isEmpty, let service = service else { return }
    
    let text = messageText
    messageText = ""
    isLoading = true
    error = nil
    
    Task {
      do {
        // Send user message
        try await service.sendMessage(conversationId: conversationId, senderEmail: userEmail, role: "user", content: text)
        
        // Generate AI response
        let aiPrompt = """
        Conversation about \(listing.title ?? "property") at $\(Int(listing.price ?? 0))/month.
        Market average: $\(Int(market?.averagePrice ?? 1000))
        User just said: \(text)
        
        Respond as a helpful AI negotiator.
        """
        
        let aiResponse = try await OpenAIClient.shared.textChat(
          model: NegotiatorConfig.openAIModel,
          system: "You are an expert rental negotiator. Help find the best deal while being respectful.",
          user: aiPrompt
        )
        
        try await service.sendMessage(conversationId: conversationId, senderEmail: NegotiatorConfig.aiEmail, role: "assistant", content: aiResponse)
        
      } catch {
        await MainActor.run {
          self.error = error.localizedDescription
        }
      }
      
      await MainActor.run {
        isLoading = false
      }
    }
  }
}

struct MessageBubble: View {
  let message: Message
  let isUser: Bool
  
  var body: some View {
    HStack {
      if isUser { Spacer() }
      
      VStack(alignment: isUser ? .trailing : .leading) {
        Text(message.content)
          .padding(12)
          .background(isUser ? Color.blue : Color(.secondarySystemBackground))
          .foregroundColor(isUser ? .white : .primary)
          .cornerRadius(16)
        
        Text(isUser ? "You" : "AI Negotiator")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      if !isUser { Spacer() }
    }
  }
}

// MARK: - App Tabs
struct AppTabs: View {
  var body: some View {
    TabView {
      NavigationView { HomeScreen() }
        .tabItem { Label("Home", systemImage: "house") }

      NavigationView { ListingsScreen() }
        .tabItem { Label("Search", systemImage: "magnifyingglass") }

      NavigationView { Text("Messages (coming soon)").font(.title2).foregroundColor(.secondary) }
        .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }

      NavigationView { Text("Profile (coming soon)").font(.title2).foregroundColor(.secondary) }
        .tabItem { Label("Profile", systemImage: "person") }
    }
  }
}

// MARK: - Grand Home Screen
struct HomeScreen: View {
  @State private var featuredListings: [HomePageListing] = []
  @State private var isLoading = true
  @Environment(\.supabase) private var supabase

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        // Header
        VStack(alignment: .leading, spacing: 8) {
          Text("Find Your Perfect Room")
            .font(.largeTitle)
            .fontWeight(.bold)
          Text("Discover amazing rental opportunities")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        
        // Quick Actions
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            NavigationLink(destination: ListingsScreen()) {
              VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                  .font(.title2)
                  .foregroundColor(.blue)
                
                VStack(spacing: 4) {
                  Text("Search Rooms")
                    .font(.subheadline)
                    .fontWeight(.medium)
                  Text("Browse all listings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .frame(width: 120, height: 100)
              .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
              .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            
            VStack(spacing: 8) {
              Image(systemName: "heart")
                .font(.title2)
                .foregroundColor(.red)
              
              VStack(spacing: 4) {
                Text("Favorites")
                  .font(.subheadline)
                  .fontWeight(.medium)
                Text("Your saved listings")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
            .frame(width: 120, height: 100)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
            
            VStack(spacing: 8) {
              Image(systemName: "calculator")
                .font(.title2)
                .foregroundColor(.green)
              
              VStack(spacing: 4) {
                Text("Mortgage Calc")
                  .font(.subheadline)
                  .fontWeight(.medium)
                Text("Calculate payments")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
            .frame(width: 120, height: 100)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
          }
          .padding(.horizontal)
        }
        
        // Featured Listings
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("Featured Listings")
              .font(.title2)
              .fontWeight(.semibold)
            Spacer()
            NavigationLink("View All", destination: ListingsScreen())
              .font(.subheadline)
              .foregroundColor(.blue)
          }
          .padding(.horizontal)
          
          if isLoading {
            HStack {
              Spacer()
              ProgressView("Loading featured listings...")
              Spacer()
            }
            .padding()
          } else {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 16) {
                ForEach(featuredListings.prefix(5)) { listing in
                  NavigationLink(destination: ListingDetailView(listing: convertToListing(listing))) {
                    FeaturedListingCard(listing: listing)
                  }
                  .buttonStyle(.plain)
                }
              }
              .padding(.horizontal)
            }
          }
        }
        
        // Recent Activity
        VStack(alignment: .leading, spacing: 12) {
          Text("Recent Activity")
            .font(.title2)
            .fontWeight(.semibold)
            .padding(.horizontal)
          
          VStack(spacing: 8) {
            ActivityRow(icon: "plus.circle.fill", title: "New listing in Downtown", time: "2 min ago", color: .green)
            ActivityRow(icon: "heart.fill", title: "Property saved to favorites", time: "1 hour ago", color: .red)
            ActivityRow(icon: "message.fill", title: "New message received", time: "3 hours ago", color: .blue)
          }
          .padding(.horizontal)
        }
        
        Spacer(minLength: 100)
      }
      .padding(.vertical)
    }
    .navigationTitle("")
    .navigationBarHidden(true)
    .onAppear {
      loadFeaturedListings()
    }
  }

  private func loadFeaturedListings() {
    isLoading = true
    Task {
      do {
        let response: [HomePageListing] = try await supabase
          .from("listings")
          .select("*")
          .limit(5)
          .execute()
          .value
        
        await MainActor.run {
          self.featuredListings = response
          self.isLoading = false
        }
      } catch {
        await MainActor.run {
          self.isLoading = false
        }
      }
    }
  }
  
  private func convertToListing(_ homeListing: HomePageListing) -> Listing {
    return Listing(
      id: homeListing.id.uuidString,
      title: homeListing.title ?? "Untitled",
      price: Double(homeListing.price ?? 0),
      city: homeListing.city ?? "",
      street: "",
      postalCode: "",
      houseType: homeListing.house_type ?? "Apartment",
      bedrooms: homeListing.bedrooms ?? 1,
      utilities: "Not specified",
      description: homeListing.description,
      media: homeListing.media?.compactMap { $0.url },
      userEmail: "",
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}

// Using existing QuickActionCard from SharedComponents.swift

// Using existing FeaturedListingCard from DashboardView.swift

struct ActivityRow: View {
  let icon: String
  let title: String
  let time: String
  let color: Color
  
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundColor(color)
        .frame(width: 20)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline)
        Text(time)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Listings Screen
struct ListingsScreen: View {
  @State private var listings: [HomePageListing] = []
  @State private var isLoading = true
  @State private var error: String?
  @Environment(\.supabase) private var supabase

  var body: some View {
    VStack {
      if isLoading {
        ProgressView("Loading listings...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = error {
        VStack {
          Text("Error: \(error)")
            .foregroundColor(.red)
          Button("Retry") {
            loadListings()
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(listings) { listing in
          NavigationLink(destination: ListingDetailView(listing: convertToListing(listing))) {
            ListingCardView(listing: listing)
          }
          .buttonStyle(.plain)
          .listRowSeparator(.hidden)
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(PlainListStyle())
      }
    }
    .navigationTitle("Search Listings")
    .onAppear {
      loadListings()
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
  
  private func convertToListing(_ homeListing: HomePageListing) -> Listing {
    return Listing(
      id: homeListing.id,
      title: homeListing.title,
      price: homeListing.price.map(Double.init),
      city: homeListing.city,
      house_type: homeListing.house_type,
      bedrooms: homeListing.bedrooms,
      description: homeListing.description,
      created_at: homeListing.created_at,
      media: homeListing.media
    )
  }
}

// MARK: - Listing Detail View
struct ListingDetailView: View {
  let listing: Listing
  @State private var budgetText = ""
  @State private var userEmail = "test-user@example.com"

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // Property image and basic info
        VStack(alignment: .leading, spacing: 12) {
          Text(listing.title ?? "Untitled Property")
            .font(.title2)
            .fontWeight(.bold)
          
          HStack {
            Text("$\(Int(listing.price ?? 0))/month")
              .font(.title)
              .fontWeight(.semibold)
              .foregroundColor(.blue)
            
            Spacer()
            
            VStack(alignment: .trailing) {
              Text(listing.house_type ?? "")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
              
              if let bedrooms = listing.bedrooms {
                Text("\(bedrooms) bedroom\(bedrooms == 1 ? "" : "s")")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
          
          if let city = listing.city {
            HStack {
              Image(systemName: "location")
                .foregroundColor(.secondary)
              Text(city)
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }
        }
        
        Divider()
        
        // Description
        VStack(alignment: .leading, spacing: 8) {
          Text("Description")
            .font(.headline)
          Text(listing.description ?? "No description available.")
            .font(.body)
            .foregroundStyle(.secondary)
        }
        
        Divider()
        
        // Budget input
        VStack(alignment: .leading, spacing: 8) {
          Text("Your Budget (Optional)")
            .font(.subheadline)
          TextField("Enter your budget", text: $budgetText)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
        }
        
        // Negotiate button
        NavigationLink(destination: AINegotiatorBootstrap(
          listing: listing,
          buyerEmail: userEmail,
          buyerBudget: Double(budgetText)
        )) {
          HStack {
            Image(systemName: "brain")
            Text("Start Negotiation with AI")
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(12)
        }
        
        Spacer(minLength: 100)
      }
      .padding()
    }
    .navigationTitle("Property Details")
    .navigationBarTitleDisplayMode(.inline)
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
  private let supabase = SupabaseClient(
    supabaseURL: URL(string: Secrets.supabaseURL)!,
    supabaseKey: Secrets.supabaseAnonKey
  )
  
  init() {
    Secrets.assertValid()
    print("🚀 AI Negotiator ready with OpenAI credentials configured!")
  }

  var body: some Scene {
    WindowGroup {
      AppTabs()
        .environment(\.supabase, supabase)
    }
  }
}