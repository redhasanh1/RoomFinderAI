import SwiftUI
import Supabase

// MARK: - Secrets Configuration
enum Secrets {
  static let supabaseURL = "https://fkktwhjybuflxqzopaex.supabase.co"
  static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"

  static func assertValid() {
    precondition(supabaseURL.hasPrefix("https://"), "Supabase URL must start with https://")
    precondition(supabaseURL.contains(".supabase.co"), "Must use .supabase.co domain")
    precondition(URL(string: supabaseURL)?.host?.hasSuffix(".supabase.co") == true, "Invalid host in Supabase URL")
    precondition(!supabaseAnonKey.isEmpty, "Anon key is empty")
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
  let media: [MediaItem]?     // jsonb array

  var coverURLString: String? { media?.first?.url }
}

// MARK: - Storage URL Helper
enum StorageURL {
  static func publicURL(supabase: SupabaseClient, bucket: String, path: String) -> URL? {
    // If path is already a full URL, return it
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
      return URL(string: path)
    }
    
    do {
      let publicURL = try supabase.storage.from(bucket).getPublicURL(path: path)
      return publicURL
    } catch {
      print("PublicURL error:", error)
      return nil
    }
  }

  static func signedURL(supabase: SupabaseClient, bucket: String, path: String) async -> URL? {
    // If path is already a full URL, return it
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
      return URL(string: path)
    }
    
    do {
      let signedURL = try await supabase.storage.from(bucket).createSignedURL(path: path, expiresIn: 3600)
      return signedURL
    } catch {
      print("SignedURL error:", error)
      return nil
    }
  }
}

// MARK: - Shared UI Components
struct ListingCardView: View {
  let listing: HomePageListing
  @State private var imageURL: URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.12))
        if let imageURL {
          AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty: ProgressView().scaleEffect(0.9)
            case .success(let img): img.resizable().scaledToFill()
            case .failure: placeholder
            @unknown default: placeholder
            }
          }
        } else { placeholder }
      }
      .frame(height: 160)
      .clipShape(RoundedRectangle(cornerRadius: 16))

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

struct ListingsScreen: View {
  @Environment(\.supabase) private var supabase
  @State private var items: [HomePageListing] = []
  @State private var errorText: String?
  @State private var isLoading = false
  @State private var page = 0
  private let pageSize = 20

  var body: some View {
    Group {
      if isLoading && items.isEmpty { ProgressView("Loading…") }
      else if let err = errorText, items.isEmpty {
        VStack(spacing: 8) {
          Text("Error").font(.title3.bold()).foregroundStyle(.red)
          Text(err).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
          Button("Retry") { Task { await reload() } }.buttonStyle(.borderedProminent)
        }.padding()
      } else {
        List {
          ForEach(items) { ListingCardView(listing: $0) }
          if isLoading { HStack { Spacer(); ProgressView(); Spacer() } }
        }
        .listStyle(.plain)
        .refreshable { await reload() }
        .onAppear { Task { await loadMoreIfNeeded() } }
      }
    }
    .navigationTitle("Listings")
    .task { if items.isEmpty { await reload() } }
  }

  private func reload() async {
    page = 0; items.removeAll(); await loadMoreIfNeeded()
  }

  private func loadMoreIfNeeded() async {
    guard !isLoading else { return }
    isLoading = true; defer { isLoading = false }
    do {
      let resp = try await supabase
        .from("listings")
        .select("id,title,price,house_type,bedrooms,description,created_at,media")
        .order("id", ascending: true)
        .range(from: page * pageSize, to: page * pageSize + (pageSize - 1))
        .execute()
      let pageItems = try JSONDecoder().decode([HomePageListing].self, from: resp.data)
      if !pageItems.isEmpty { items += pageItems; page += 1 }
      errorText = nil
    } catch { errorText = String(describing: error) }
  }
}

// MARK: - Home Screen
struct HomeScreen: View {
  @Environment(\.supabase) private var supabase
  @State private var featuredListings: [HomePageListing] = []
  @State private var isLoading = false
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          welcomeHeader
          quickActionsGrid
          recentActivitySection
          featuredListingsSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
      }
      .navigationTitle("Home")
      .task { await loadFeaturedListings() }
    }
  }
  
  private var welcomeHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Welcome, Guest")
          .font(.title2.bold())
        Text("Find your perfect room")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
  }
  
  private var quickActionsGrid: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
      QuickActionCard(title: "AI Assistant", subtitle: "Get smart recommendations", icon: "brain", color: .blue) {}
      QuickActionCard(title: "Search Rooms", subtitle: "Find your perfect match", icon: "magnifyingglass", color: .green) {}
      QuickActionCard(title: "Messages", subtitle: "Chat with hosts", icon: "message", color: .orange) {}
      QuickActionCard(title: "Favorites", subtitle: "Your saved listings", icon: "heart", color: .red) {}
    }
  }
  
  private var recentActivitySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recent Activity")
          .font(.headline)
        Spacer()
      }
      
      VStack(spacing: 8) {
        ActivityRow(icon: "eye", text: "Viewed 3 listings today", time: "2h ago")
        ActivityRow(icon: "heart", text: "Saved 2 favorites", time: "1d ago")
        ActivityRow(icon: "message", text: "New message from host", time: "2d ago")
      }
    }
  }
  
  private var featuredListingsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Featured Listings")
          .font(.headline)
        Spacer()
        Button("See All") {}
          .font(.subheadline)
          .foregroundStyle(.blue)
      }
      
      if isLoading {
        ProgressView()
          .frame(height: 200)
      } else if featuredListings.isEmpty {
        Text("No featured listings available")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(height: 100)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 16) {
            ForEach(featuredListings.prefix(10)) { listing in
              ListingCardView(listing: listing)
                .frame(width: 280)
            }
          }
          .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
      }
    }
  }
  
  private func loadFeaturedListings() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    
    do {
      let resp = try await supabase
        .from("listings")
        .select("id,title,price,house_type,bedrooms,description,created_at,media")
        .order("created_at", ascending: false)
        .limit(10)
        .execute()
      featuredListings = try JSONDecoder().decode([HomePageListing].self, from: resp.data)
    } catch {
      print("Featured listings error:", error)
    }
  }
}

struct ActivityRow: View {
  let icon: String
  let text: String
  let time: String
  
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.subheadline)
        .foregroundStyle(.blue)
        .frame(width: 20)
      Text(text)
        .font(.subheadline)
      Spacer()
      Text(time)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - AI Negotiator Screen
struct AINegotiatorScreen: View {
  @Environment(\.supabase) private var supabase
  @State private var messages: [AIMessage] = []
  @State private var messageText = ""
  @State private var isTyping = false
  @State private var foundListings: [HomePageListing] = []
  
  struct AIMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp = Date()
  }
  
  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 0) {
        // Left Sidebar - Found Listings (collapsed on small screens)
        if geometry.size.width > 600 {
          VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
              Text("Found Listings")
                .font(.headline)
                .fontWeight(.semibold)
              
              if foundListings.isEmpty {
                Text("Use the AI chat to search for properties!")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .multilineTextAlignment(.leading)
              } else {
                Text("\(foundListings.count) properties found")
                  .font(.caption)
                  .foregroundColor(.blue)
              }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            
            ScrollView {
              LazyVStack(spacing: 8) {
                ForEach(foundListings) { listing in
                  AIListingCard(listing: listing)
                }
              }
              .padding(.horizontal, 12)
            }
            
            Spacer()
          }
          .frame(width: min(250, geometry.size.width * 0.35))
          .background(Color(.systemGray6))
          
          Divider()
        }
        
        // Main Chat Interface
        VStack(spacing: 0) {
          // Chat Header
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
            
            // Show found listings count on small screens
            if geometry.size.width <= 600 && !foundListings.isEmpty {
              Text("\(foundListings.count) found")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.trailing, 8)
            }
            
            Button("Clear Chat") {
              clearChat()
            }
            .foregroundColor(.secondary)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(Color(.systemBackground))
          
          Divider()
          
          // Chat Messages
          ScrollViewReader { proxy in
            ScrollView {
              LazyVStack(spacing: 12) {
                ForEach(messages) { message in
                  AIChatBubble(message: message)
                    .id(message.id)
                }
                
                if isTyping {
                  AITypingIndicator()
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
          VStack(spacing: 8) {
            HStack(spacing: 12) {
              TextField("Type your message here...", text: $messageText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...4)
                .onSubmit {
                  sendMessage()
                }
              
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
            
            HStack {
              Text("Press Enter to send • Try: \"Find me a 1BR apartment in NYC under $2000\"")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(Color(.systemGray6))
        }
      }
    }
    .navigationTitle("AI Negotiator")
    .onAppear {
      setupWelcomeMessage()
    }
  }
  
  private func setupWelcomeMessage() {
    if messages.isEmpty {
      let welcomeMessage = AIMessage(
        content: """
        Welcome to AI Negotiation Assistant! 🏠
        
        I can help you:
        • Find great properties and negotiate better deals
        • Write professional messages to landlords  
        • Analyze market data for your area
        • Provide negotiation strategy and tips
        
        Try saying: "Find me a 1-bedroom apartment in [city] under $[budget]" or "Help me negotiate with my landlord"
        """,
        isFromUser: false
      )
      messages.append(welcomeMessage)
    }
  }
  
  private func sendMessage() {
    let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else { return }
    
    // Add user message
    let userMessage = AIMessage(content: trimmedText, isFromUser: true)
    messages.append(userMessage)
    
    // Clear input
    messageText = ""
    
    // Show typing indicator
    isTyping = true
    
    // Simulate AI processing and response
    Task {
      await processUserMessage(trimmedText)
    }
  }
  
  private func processUserMessage(_ message: String) async {
    let lowercased = message.lowercased()
    
    // Simulate processing delay
    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
    
    await MainActor.run {
      isTyping = false
      
      if lowercased.contains("find") && (lowercased.contains("apartment") || lowercased.contains("house") || lowercased.contains("room")) {
        handlePropertySearch(message)
      } else if lowercased.contains("negotiate") || lowercased.contains("landlord") {
        handleNegotiationHelp()
      } else if lowercased.contains("market") || lowercased.contains("price") {
        handleMarketAnalysis()
      } else {
        handleGeneralQuery()
      }
    }
  }
  
  private func handlePropertySearch(_ query: String) {
    // Simulate property search and add mock listings
    Task {
      do {
        // Search real listings from database
        let searchResults = try await searchProperties(query: query)
        
        await MainActor.run {
          foundListings = searchResults
          
          if !searchResults.isEmpty {
            let response = AIMessage(
              content: "🔍 Great! I found \(searchResults.count) properties matching your criteria. Check the \"Found Listings\" section on the left.\n\nWould you like me to help you write a negotiation message for any of these properties?",
              isFromUser: false
            )
            messages.append(response)
          } else {
            let response = AIMessage(
              content: "I searched our database but couldn't find properties matching those exact criteria. Try adjusting your search terms or budget.\n\nFor example: \"Find me a 1BR apartment in Manhattan under $3000\"",
              isFromUser: false
            )
            messages.append(response)
          }
        }
      } catch {
        await MainActor.run {
          let response = AIMessage(
            content: "I'm having trouble searching properties right now. Please try again in a moment.",
            isFromUser: false
          )
          messages.append(response)
        }
      }
    }
  }
  
  private func handleNegotiationHelp() {
    let response = AIMessage(
      content: """
      💼 I'd be happy to help you negotiate with your landlord!
      
      Here are some proven strategies:
      
      **Research First:**
      • Check local rental prices for similar properties
      • Note any property issues or needed repairs
      • Consider your rental history and payment record
      
      **Negotiation Tips:**
      • Be polite and professional
      • Present market data to justify your request
      • Offer something in return (longer lease, property improvements)
      • Time your request well (before lease renewal)
      
      Would you like me to help you write a specific negotiation message? Just tell me about your situation!
      """,
      isFromUser: false
    )
    messages.append(response)
  }
  
  private func handleMarketAnalysis() {
    let response = AIMessage(
      content: """
      📊 I can provide market analysis for any area!
      
      **What I can analyze:**
      • Average rental prices by neighborhood
      • Price trends over time  
      • Comparison with similar properties
      • Market competitiveness
      
      Just tell me the area and property type you're interested in. For example:
      "Analyze the market for 1-bedroom apartments in Brooklyn"
      """,
      isFromUser: false
    )
    messages.append(response)
  }
  
  private func handleGeneralQuery() {
    let responses = [
      """
      🤖 I'm here to help with rental negotiations and property searches!
      
      **Popular commands:**
      • "Find me apartments in [city] under $[budget]"
      • "Help me negotiate my rent"
      • "Write a message to my landlord"
      • "Analyze the market in [area]"
      
      What would you like help with today?
      """,
      """
      💡 Here are some ways I can assist you:
      
      **Property Search:** I'll find listings matching your criteria
      **Negotiation Strategy:** Expert advice for better deals
      **Market Research:** Data-driven insights for your area
      **Message Writing:** Professional communications with landlords
      
      Try being specific about what you need!
      """
    ]
    
    let response = AIMessage(content: responses.randomElement()!, isFromUser: false)
    messages.append(response)
  }
  
  private func searchProperties(query: String) async throws -> [HomePageListing] {
    // Parse search query
    let searchParams = parseSearchQuery(query)
    
    // For now, let's use a simple approach and get all listings, then filter in code
    // This ensures compatibility with the current Supabase version
    let resp = try await supabase
      .from("listings")
      .select("id,title,price,city,bedrooms,house_type,description,created_at,media")
      .order("created_at", ascending: false)
      .limit(50)  // Get more results to filter from
      .execute()
    
    let allListings = try JSONDecoder().decode([HomePageListing].self, from: resp.data)
    
    // Filter results in code based on search parameters
    var filteredListings = allListings
    
    // Filter out listings without price
    filteredListings = filteredListings.filter { $0.price != nil && $0.price! > 0 }
    
    // Apply location filter
    if let location = searchParams.location?.lowercased() {
      filteredListings = filteredListings.filter { listing in
        let titleMatch = listing.title?.lowercased().contains(location) ?? false
        let cityMatch = listing.city?.lowercased().contains(location) ?? false
        return titleMatch || cityMatch
      }
    }
    
    // Apply price filter
    if let maxPrice = searchParams.maxPrice {
      filteredListings = filteredListings.filter { listing in
        if let price = listing.price {
          return price <= maxPrice
        }
        return false
      }
    }
    
    // Apply house type filter
    if let houseType = searchParams.houseType?.lowercased() {
      filteredListings = filteredListings.filter { listing in
        listing.house_type?.lowercased() == houseType
      }
    }
    
    // Apply bedroom filter
    if let bedrooms = searchParams.bedrooms {
      filteredListings = filteredListings.filter { listing in
        listing.bedrooms == bedrooms
      }
    }
    
    return Array(filteredListings.prefix(10))  // Return max 10 results
  }
  
  private func parseSearchQuery(_ query: String) -> (location: String?, maxPrice: Int?, houseType: String?, bedrooms: Int?) {
    let lowercased = query.lowercased()
    
    // Extract location
    var location: String?
    if let inRange = lowercased.range(of: " in ") {
      let afterIn = String(lowercased[inRange.upperBound...])
      let locationEnd = afterIn.range(of: " under")?.lowerBound ?? 
                       afterIn.range(of: " for")?.lowerBound ?? 
                       afterIn.range(of: " apartment")?.lowerBound ??
                       afterIn.range(of: " house")?.lowerBound ??
                       afterIn.endIndex
      location = String(afterIn[..<locationEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Extract price
    var maxPrice: Int?
    let priceRegex = try? NSRegularExpression(pattern: "under \\$?([0-9,]+)", options: [.caseInsensitive])
    if let match = priceRegex?.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
       let range = Range(match.range(at: 1), in: query) {
      let priceString = String(query[range]).replacingOccurrences(of: ",", with: "")
      maxPrice = Int(priceString)
    }
    
    // Extract house type
    var houseType: String?
    if lowercased.contains("apartment") { houseType = "apartment" }
    else if lowercased.contains("house") { houseType = "house" }
    else if lowercased.contains("condo") { houseType = "condo" }
    else if lowercased.contains("studio") { houseType = "studio" }
    
    // Extract bedrooms
    var bedrooms: Int?
    let bedroomRegex = try? NSRegularExpression(pattern: "([0-9]+)[- ]bedroom", options: [.caseInsensitive])
    if let match = bedroomRegex?.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
       let range = Range(match.range(at: 1), in: query) {
      bedrooms = Int(String(query[range]))
    }
    
    return (location: location, maxPrice: maxPrice, houseType: houseType, bedrooms: bedrooms)
  }
  
  private func clearChat() {
    messages.removeAll()
    foundListings.removeAll()
    setupWelcomeMessage()
  }
}

// MARK: - AI Chat Components
struct AIChatBubble: View {
  let message: AINegotiatorScreen.AIMessage
  
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
    .frame(maxWidth: 300, alignment: .trailing)
  }
  
  private var aiBubble: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("AI Assistant")
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(.secondary)
      
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
    .frame(maxWidth: 300, alignment: .leading)
  }
}

struct AITypingIndicator: View {
  @State private var typingScale: CGFloat = 0.8
  
  var body: some View {
    HStack {
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
      
      Spacer()
    }
  }
}

struct AIListingCard: View {
  let listing: HomePageListing
  
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(listing.title ?? "Untitled")
        .font(.caption)
        .fontWeight(.medium)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
      
      HStack {
        if let price = listing.price {
          Text("$\(price)")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.blue)
        }
        
        Spacer()
        
        if let city = listing.city {
          Text(city)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }
      
      if let bedrooms = listing.bedrooms, let houseType = listing.house_type {
        Text("\(bedrooms) bed • \(houseType)")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
    }
    .padding(8)
    .background(Color(.systemBackground))
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
    )
  }
}

// MARK: - Tab View
struct AppTabs: View {
  @Environment(\.supabase) private var supabase
  
  var body: some View {
    TabView {
      HomeScreen()
        .tabItem { 
          Label("Home", systemImage: "house.fill") 
        }
      
      ListingsScreen()
        .tabItem { 
          Label("Listings", systemImage: "list.bullet") 
        }
      
      AINegotiatorScreen()
        .tabItem { 
          Label("AI Negotiator", systemImage: "brain") 
        }
      
      Text("Messages")
        .tabItem { 
          Label("Messages", systemImage: "message.fill") 
        }
      
      Text("Profile")
        .tabItem { 
          Label("Profile", systemImage: "person.fill") 
        }
    }
  }
}

// MARK: - App
@main
struct MyApp: App {
  private let supabase = SupabaseFactory.makeClient()
  
  var body: some Scene {
    WindowGroup {
      AppTabs()
        .environment(\.supabase, supabase)
    }
  }
}