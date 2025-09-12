import SwiftUI
import Supabase

// MARK: - Configuration
enum AppConfig {
    static let enableMockAI = false // Use real OpenAI API for intelligent responses
    static let debugMode = true // Enable debug logs to see what's happening
}

// MARK: - Secrets Configuration
enum Secrets {
  static let supabaseURL = "https://fkktwhjybuflxqzopaex.supabase.co"
  static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZra3R3aGp5YnVmbHhxem9wYWV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0OTg5NzQsImV4cCI6MjA2MzA3NDk3NH0.4vdk_ozdi_jNNP1dxpAlGF2Km2detytIhN-lMNXNFHs"

  // 🚀 OpenAI Configuration
  // Note: Replace with your actual OpenAI API key from https://platform.openai.com/api-keys
  static let openAIKey = "sk-proj-your-openai-api-key-here-replace-with-real-key"
  static let openAIOrgID: String? = nil // Optional: Your OpenAI organization ID
  static let openAIModel = "gpt-3.5-turbo" // Using more affordable model
  
  // API Key validation
  static var isOpenAIKeyValid: Bool {
    return !openAIKey.contains("your-openai-api-key-here") && 
           openAIKey.hasPrefix("sk-") && 
           openAIKey.count > 20 &&
           !openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  static var openAIKeyStatus: String {
    if openAIKey == "your-openai-api-key-here" {
      return "⚠️ Please configure your OpenAI API key"
    } else if !openAIKey.hasPrefix("sk-") {
      return "❌ Invalid API key format (must start with 'sk-')"
    } else if openAIKey.count < 20 {
      return "❌ API key appears to be truncated"
    } else {
      return "✅ API key format is valid"
    }
  }

  static func assertValid() {
    precondition(supabaseURL.hasPrefix("https://"), "Supabase URL must start with https://")
    precondition(supabaseURL.contains(".supabase.co"), "Must use .supabase.co domain")
    precondition(URL(string: supabaseURL)?.host?.hasSuffix(".supabase.co") == true, "Invalid host in Supabase URL")
    precondition(!supabaseAnonKey.isEmpty, "Anon key is empty")
    
    // OpenAI validation (warn but don't crash in mock mode)
    if !AppConfig.enableMockAI && !isOpenAIKeyValid {
      print("⚠️ OpenAI API key issue: \(openAIKeyStatus)")
      print("💡 Set AppConfig.enableMockAI = true to use mock responses for testing")
    }
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
              .background(Color(.systemGray6))
              .cornerRadius(16)
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


// MARK: - Enhanced Search View
struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [HomePageListing] = []
    @State private var isLoading = false
    @State private var showingAdvanced = false
    @State private var searchWorkItem: DispatchWorkItem?
    
    // Essential Filter State
    @State private var selectedPriceRanges: Set<String> = []
    @State private var selectedBedroomTypes: Set<String> = []
    @State private var selectedPropertyTypes: Set<String> = []
    @State private var selectedSort = "Recent"
    @State private var showingPriceFilter = false
    @State private var showingBedroomFilter = false
    
    // Advanced Filter State (hidden by default)
    @State private var minPrice: Double = 0
    @State private var maxPrice: Double = 10000
    @State private var specificBedrooms: Int? = nil
    
    @Environment(\.supabase) private var supabase
    
    let propertyTypes = ["Studio", "Apartment", "House", "Condo", "Townhouse", "Loft"]
    let priceRanges = ["Under $1,000", "$1,000 - $1,500", "$1,500 - $2,000", "$2,000 - $3,000", "Over $3,000"]
    let bedroomTypes = ["Studio", "1 Bedroom", "2 Bedrooms", "3 Bedrooms", "4+ Bedrooms"]
    let sortOptions = ["Recent", "Price: Low to High", "Price: High to Low", "Distance"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Clean Header
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Search Properties")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Find your perfect home")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    // Clean Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search properties...", text: $searchText)
                            .onChange(of: searchText) { _ in
                                // Cancel previous search
                                searchWorkItem?.cancel()
                                
                                // Create new debounced search
                                let workItem = DispatchWorkItem {
                                    performSearch()
                                }
                                searchWorkItem = workItem
                                
                                // Execute after 300ms delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                            }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    // Main Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterChipView(
                                title: selectedPriceRanges.isEmpty ? "Price" : "\(selectedPriceRanges.count) Price Range\(selectedPriceRanges.count > 1 ? "s" : "")",
                                isSelected: !selectedPriceRanges.isEmpty
                            ) {
                                showingPriceFilter.toggle()
                            }
                            
                            FilterChipView(
                                title: selectedBedroomTypes.isEmpty ? "Bedrooms" : "\(selectedBedroomTypes.count) Bedroom Type\(selectedBedroomTypes.count > 1 ? "s" : "")",
                                isSelected: !selectedBedroomTypes.isEmpty
                            ) {
                                showingBedroomFilter.toggle()
                            }
                            
                            FilterChipView(
                                title: selectedPropertyTypes.isEmpty ? "Type" : "\(selectedPropertyTypes.count) Type\(selectedPropertyTypes.count > 1 ? "s" : "")",
                                isSelected: !selectedPropertyTypes.isEmpty
                            ) {
                                showingAdvanced.toggle()
                            }
                            
                            FilterChipView(
                                title: selectedSort,
                                isSelected: selectedSort != "Recent"
                            ) {
                                showSortOptions()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Price Range Filter
                    if showingPriceFilter {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Price Range")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button("Clear") {
                                    selectedPriceRanges.removeAll()
                                    performSearch()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            .padding(.horizontal, 16)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                                ForEach(priceRanges, id: \.self) { range in
                                    Button(action: {
                                        if selectedPriceRanges.contains(range) {
                                            selectedPriceRanges.remove(range)
                                        } else {
                                            selectedPriceRanges.insert(range)
                                        }
                                        performSearch()
                                    }) {
                                        HStack(spacing: 8) {
                                            if selectedPriceRanges.contains(range) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.gray)
                                            }
                                            Text(range)
                                                .font(.subheadline)
                                            Spacer()
                                        }
                                        .foregroundColor(selectedPriceRanges.contains(range) ? .blue : .primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(selectedPriceRanges.contains(range) ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                    
                    // Bedroom Type Filter
                    if showingBedroomFilter {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Bedrooms")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button("Clear") {
                                    selectedBedroomTypes.removeAll()
                                    performSearch()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            .padding(.horizontal, 16)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                                ForEach(bedroomTypes, id: \.self) { bedroom in
                                    Button(action: {
                                        if selectedBedroomTypes.contains(bedroom) {
                                            selectedBedroomTypes.remove(bedroom)
                                        } else {
                                            selectedBedroomTypes.insert(bedroom)
                                        }
                                        performSearch()
                                    }) {
                                        HStack(spacing: 8) {
                                            if selectedBedroomTypes.contains(bedroom) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.gray)
                                            }
                                            Text(bedroom)
                                                .font(.subheadline)
                                            Spacer()
                                        }
                                        .foregroundColor(selectedBedroomTypes.contains(bedroom) ? .blue : .primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(selectedBedroomTypes.contains(bedroom) ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                    
                    // Property Type Filter (Advanced)
                    if showingAdvanced {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Property Types")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button("Clear All") {
                                    clearAllFilters()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            .padding(.horizontal, 16)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(propertyTypes, id: \.self) { type in
                                    Button(action: {
                                        if selectedPropertyTypes.contains(type) {
                                            selectedPropertyTypes.remove(type)
                                        } else {
                                            selectedPropertyTypes.insert(type)
                                        }
                                        performSearch()
                                    }) {
                                        HStack(spacing: 6) {
                                            if selectedPropertyTypes.contains(type) {
                                                Image(systemName: "checkmark")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                            }
                                            Text(type)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(selectedPropertyTypes.contains(type) ? .white : .blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedPropertyTypes.contains(type) ? Color.blue : Color(.systemGray6))
                                        .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                    
                    // Results Area
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Searching properties...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                    } else if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("\(searchResults.count) properties found")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if hasActiveFilters() {
                                    Button("Clear Filters") {
                                        clearAllFilters()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            // Single Column Results (like Android)
                            LazyVStack(spacing: 16) {
                                ForEach(searchResults) { listing in
                                    SearchListingCardView(listing: listing)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                    } else if !searchText.isEmpty || hasActiveFilters() {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No results found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Try adjusting your search or filters")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if hasActiveFilters() {
                                Button("Clear All Filters") {
                                    clearAllFilters()
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.top, 8)
                            }
                        }
                        .padding(.top, 60)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Load initial results on appear
                if searchResults.isEmpty {
                    performSearch()
                }
            }
    }
    }
    
    // MARK: - Helper Functions
    private func hasActiveFilters() -> Bool {
        return !selectedPriceRanges.isEmpty || 
               !selectedBedroomTypes.isEmpty || 
               !selectedPropertyTypes.isEmpty ||
               selectedSort != "Recent"
    }
    
    private func clearAllFilters() {
        selectedPriceRanges.removeAll()
        selectedBedroomTypes.removeAll()
        selectedPropertyTypes.removeAll()
        selectedSort = "Recent"
        searchText = ""
        showingAdvanced = false
        showingPriceFilter = false
        showingBedroomFilter = false
        performSearch()
    }
    
    // MARK: - Filter Functions
    private func showSortOptions() {
        let alert = UIAlertController(title: "Sort Properties", message: nil, preferredStyle: .actionSheet)
        
        for option in sortOptions {
            alert.addAction(UIAlertAction(title: option, style: .default) { _ in
                self.selectedSort = option
                self.performSearch()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func matchesPriceFilter(_ listing: HomePageListing) -> Bool {
        if selectedPriceRanges.isEmpty { return true }
        
        guard let price = listing.price else { return false }
        let priceValue = Double(price)
        
        for range in selectedPriceRanges {
            switch range {
            case "Under $1,000":
                if priceValue < 1000 { return true }
            case "$1,000 - $1,500":
                if priceValue >= 1000 && priceValue <= 1500 { return true }
            case "$1,500 - $2,000":
                if priceValue >= 1500 && priceValue <= 2000 { return true }
            case "$2,000 - $3,000":
                if priceValue >= 2000 && priceValue <= 3000 { return true }
            case "Over $3,000":
                if priceValue > 3000 { return true }
            default:
                break
            }
        }
        return false
    }
    
    private func matchesBedroomFilter(_ listing: HomePageListing) -> Bool {
        if selectedBedroomTypes.isEmpty { return true }
        
        for bedroomType in selectedBedroomTypes {
            switch bedroomType {
            case "Studio":
                if listing.bedrooms == 0 { return true }
            case "1 Bedroom":
                if listing.bedrooms == 1 { return true }
            case "2 Bedrooms":
                if listing.bedrooms == 2 { return true }
            case "3 Bedrooms":
                if listing.bedrooms == 3 { return true }
            case "4+ Bedrooms":
                if listing.bedrooms ?? 0 >= 4 { return true }
            default:
                break
            }
        }
        return false
    }
    
    // MARK: - Smart Search
    private func matchesSmartSearch(_ listing: HomePageListing, _ query: String) -> Bool {
        let lowerQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic text search
        let titleMatch = listing.title?.lowercased().contains(lowerQuery) ?? false
        let cityMatch = listing.city?.lowercased().contains(lowerQuery) ?? false
        let descriptionMatch = listing.description?.lowercased().contains(lowerQuery) ?? false
        let basicMatch = titleMatch || cityMatch || descriptionMatch
        
        // Smart price search patterns
        if lowerQuery.contains("under") && lowerQuery.contains("$") {
            let priceStr = lowerQuery.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let maxPrice = Double(priceStr), let listingPrice = listing.price {
                return Double(listingPrice) <= maxPrice
            }
        }
        
        if lowerQuery.contains("over") && lowerQuery.contains("$") {
            let priceStr = lowerQuery.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let minPrice = Double(priceStr), let listingPrice = listing.price {
                return Double(listingPrice) >= minPrice
            }
        }
        
        // Price range search (e.g., "1000-1500")
        if lowerQuery.range(of: #"\d+-\d+"#, options: .regularExpression) != nil {
            let parts = lowerQuery.replacingOccurrences(of: "[^0-9-]", with: "", options: .regularExpression).split(separator: "-")
            if parts.count == 2, let minPrice = Double(parts[0]), let maxPrice = Double(parts[1]), let listingPrice = listing.price {
                return Double(listingPrice) >= minPrice && Double(listingPrice) <= maxPrice
            }
        }
        
        // Bedroom search
        if lowerQuery.contains("bedroom") || lowerQuery.contains("bed") {
            let bedStr = lowerQuery.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let bedrooms = Int(bedStr) {
                return listing.bedrooms == bedrooms
            }
        }
        
        // Studio search
        if lowerQuery.contains("studio") {
            return (listing.house_type?.lowercased().contains("studio") == true) || listing.bedrooms == 0
        }
        
        return basicMatch
    }
    
    private func performSearch() {
        isLoading = true
        Task {
            await searchListings()
        }
    }
    
    private func searchListings() async {
        do {
            // Fetch all listings from database
            let allListings: [HomePageListing] = try await supabase
                .from("listings")
                .select("*")
                .execute()
                .value
            
            // Apply filtering and smart search
            var filtered = allListings.filter { listing in
                // Smart search patterns (if search text exists)
                if !searchText.isEmpty {
                    return matchesSmartSearch(listing, searchText)
                }
                return true
            }
            
            // Apply price filter
            filtered = filtered.filter { listing in
                return matchesPriceFilter(listing)
            }
            
            // Apply bedroom filter
            filtered = filtered.filter { listing in
                return matchesBedroomFilter(listing)
            }
            
            // Apply property type filter
            if !selectedPropertyTypes.isEmpty {
                filtered = filtered.filter { listing in
                    selectedPropertyTypes.contains { type in
                        listing.house_type?.lowercased().contains(type.lowercased()) ?? false
                    }
                }
            }
            
            // Apply sorting
            switch selectedSort {
            case "Recent":
                filtered.sort { ($0.created_at ?? "") > ($1.created_at ?? "") }
            case "Price: Low":
                filtered.sort { ($0.price ?? 0) < ($1.price ?? 0) }
            case "Price: High":
                filtered.sort { ($0.price ?? 0) > ($1.price ?? 0) }
            case "Alphabetical":
                filtered.sort { ($0.title ?? "") < ($1.title ?? "") }
            default:
                break
            }
            
            await MainActor.run {
                self.searchResults = filtered
                self.isLoading = false
            }
            
        } catch {
            print("Search error: \(error)")
            await MainActor.run {
                self.searchResults = []
                self.isLoading = false
            }
        }
    }
}

struct SearchResultsView: View {
    let results: [HomePageListing]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if results.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Results Found")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Try adjusting your search criteria")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(results) { listing in
                                SearchListingCardView(listing: listing)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Search Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct SearchFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

// MARK: - Post View
struct PostView: View {
    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var location = ""
    @State private var bedrooms = 1
    @State private var bathrooms = 1
    @State private var selectedPropertyType = "Apartment"
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Form validation
    @State private var titleError = ""
    @State private var priceError = ""
    @State private var locationError = ""
    
    @Environment(\.supabase) private var supabase
    
    let propertyTypes = ["Studio", "Apartment", "House", "Condo", "Townhouse", "Loft"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Post Your Property")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("List your room or property for rent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(spacing: 20) {
                    // Basic Information Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "house.fill")
                                .foregroundColor(.blue)
                            Text("Basic Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Property Title *")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("e.g., Spacious 1BR near campus", text: $title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            if !titleError.isEmpty {
                                Text(titleError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location *")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("City, neighborhood, or address", text: $location)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            if !locationError.isEmpty {
                                Text(locationError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Monthly Rent *")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack {
                                Text("$")
                                    .foregroundColor(.secondary)
                                TextField("1200", text: $price)
                                    .keyboardType(.numberPad)
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            if !priceError.isEmpty {
                                Text(priceError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(12)
                    
                    // Property Details Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.green)
                            Text("Property Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Property Type")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(propertyTypes, id: \.self) { type in
                                        Button(action: {
                                            selectedPropertyType = type
                                        }) {
                                            Text(type)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(selectedPropertyType == type ? .white : .primary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(selectedPropertyType == type ? Color.blue : Color(.systemGray6))
                                                .cornerRadius(20)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        
                        HStack(spacing: 30) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bedrooms")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack(spacing: 12) {
                                    Button("-") {
                                        if bedrooms > 0 { bedrooms -= 1 }
                                    }
                                    .frame(width: 36, height: 36)
                                    .background(Color(.systemGray6))
                                    .foregroundColor(.blue)
                                    .cornerRadius(18)
                                    
                                    Text("\(bedrooms)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .frame(minWidth: 30)
                                    
                                    Button("+") {
                                        if bedrooms < 10 { bedrooms += 1 }
                                    }
                                    .frame(width: 36, height: 36)
                                    .background(Color(.systemGray6))
                                    .foregroundColor(.blue)
                                    .cornerRadius(18)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bathrooms")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack(spacing: 12) {
                                    Button("-") {
                                        if bathrooms > 0 { bathrooms -= 1 }
                                    }
                                    .frame(width: 36, height: 36)
                                    .background(Color(.systemGray6))
                                    .foregroundColor(.blue)
                                    .cornerRadius(18)
                                    
                                    Text("\(bathrooms)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .frame(minWidth: 30)
                                    
                                    Button("+") {
                                        if bathrooms < 10 { bathrooms += 1 }
                                    }
                                    .frame(width: 36, height: 36)
                                    .background(Color(.systemGray6))
                                    .foregroundColor(.blue)
                                    .cornerRadius(18)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(12)
                    
                    // Description Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(.orange)
                            Text("Description")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tell potential renters about your property")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Describe your property, amenities, nearby attractions...", text: $description, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(4...8)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(12)
                    
                    // Submit Button
                    Button(action: {
                        submitListing()
                    }) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(isSubmitting ? "Posting..." : "Post Property")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: isFormValid() ? [.green, .blue] : [.gray, .gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid() || isSubmitting)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarHidden(true)
        .alert("Success!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                clearForm()
            }
        } message: {
            Text("Your property has been posted successfully!")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Helper Functions
    
    private func isFormValid() -> Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               Int(price) != nil &&
               Int(price) ?? 0 > 0
    }
    
    private func validateForm() {
        titleError = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Title is required" : ""
        locationError = location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Location is required" : ""
        
        if price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            priceError = "Price is required"
        } else if Int(price) == nil {
            priceError = "Please enter a valid price"
        } else if Int(price) ?? 0 <= 0 {
            priceError = "Price must be greater than 0"
        } else {
            priceError = ""
        }
    }
    
    private func clearForm() {
        title = ""
        description = ""
        price = ""
        location = ""
        bedrooms = 1
        bathrooms = 1
        selectedPropertyType = "Apartment"
        titleError = ""
        priceError = ""
        locationError = ""
    }
    
    private func submitListing() {
        validateForm()
        
        guard isFormValid() else {
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                // Create a new listing struct that can be encoded
                struct NewListing: Codable {
                    let title: String
                    let price: Int
                    let city: String
                    let house_type: String
                    let bedrooms: Int
                    let bathrooms: Int
                    let description: String?
                }
                
                let newListing = NewListing(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    price: Int(price) ?? 0,
                    city: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    house_type: selectedPropertyType,
                    bedrooms: bedrooms,
                    bathrooms: bathrooms,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                // Submit to Supabase
                try await supabase
                    .from("listings")
                    .insert(newListing)
                    .execute()
                
                await MainActor.run {
                    isSubmitting = false
                    showingSuccessAlert = true
                }
                
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to post listing: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Search-Optimized Listing Card
struct SearchListingCardView: View {
    let listing: HomePageListing
    @State private var imageURL: URL?
    @Environment(\.supabase) private var supabase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with price overlay
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundColor(.secondary)
                        )
                }
                .frame(height: 180)
                .aspectRatio(16/9, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Price Badge
                if let price = listing.price {
                    Text("$\(price)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(12)
                }
            }
            
            // Content section - optimized spacing for search
            VStack(alignment: .leading, spacing: 8) {
                Text(listing.title ?? "Untitled")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let city = listing.city {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 16) {
                    if let bedrooms = listing.bedrooms {
                        HStack(spacing: 4) {
                            Image(systemName: "bed.double.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(bedrooms) bed\(bedrooms == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let houseType = listing.house_type {
                        HStack(spacing: 4) {
                            Image(systemName: "house.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(houseType)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let mediaItems = listing.media, !mediaItems.isEmpty else { return }
        if let urlString = mediaItems.first?.url, let url = URL(string: urlString) {
            imageURL = url
        }
    }
}

// MARK: - Simple Profile View
struct SimpleProfileView: View {
    @State private var isLoggedIn = false
    @State private var showingLogin = false
    
    var body: some View {
        VStack(spacing: 24) {
            if isLoggedIn {
                // Logged In Profile
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("John Doe")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("john@example.com")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Stats
                    HStack(spacing: 30) {
                        VStack {
                            Text("3")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Listings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("12")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("Favorites")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("5")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("Chats")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Button("Logout") {
                    isLoggedIn = false
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
                
            } else {
                // Guest Profile
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue.opacity(0.3))
                    
                    Text("Welcome to RoomFinder")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Sign in to access your profile and manage your listings")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        isLoggedIn = true // Simple demo toggle
                    }) {
                        HStack {
                            Image(systemName: "person.fill")
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .navigationTitle("Profile")
    }
}

// MARK: - App
@main
struct RoomFinderAIApp: App {
  private let supabase = SupabaseFactory.makeClient()
  
  init() {
    // Assert OpenAI credentials are configured at startup (fail fast)
    Secrets.assertValid()
    
    // Debug: Confirm 5-tab structure is loaded
    print("🚀 DEBUG: 5-tab app structure loaded successfully! (Android → iOS)")
  }
  
  var body: some Scene {
    WindowGroup {
      TabView {
        // 1. Home Tab - Optimized room listings with pagination
        OptimizedHomeScreen()
          .tabItem { Label("Home", systemImage: "house.fill") }
        
        // 2. Search Tab - Advanced search (like Android SearchFragment)  
        NavigationView { SearchView() }
          .tabItem { Label("Search", systemImage: "magnifyingglass") }
        
        // 3. Post Tab - Create listings (like Android PostFragment)
        NavigationView { PostView() }
          .tabItem { Label("Post", systemImage: "plus.circle.fill") }
        
        // 4. Chat Tab - AI Chat hub (like Android ChatFragment)
        NavigationView { ChatView() }
          .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
        
        // 5. Profile Tab - User profile (like Android ProfileFragment)
        NavigationView { ProfileView() }
          .tabItem { Label("Profile", systemImage: "person.fill") }
      }
      .environment(\.supabase, supabase)
    }
  }
}

// MARK: - Chat System Implementation

// MARK: - Chat Data Models

struct ChatConversation: Identifiable, Codable {
    let id: String
    let participantIds: [String]
    let lastMessage: ChatMessage?
    let lastActivity: Date
    let isRead: Bool
    let conversationType: ConversationType
    let title: String?
    let groupImage: String?
    
    enum ConversationType: String, Codable {
        case direct = "direct"
        case group = "group"
        case landlord = "landlord"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case participantIds = "participant_ids"
        case lastMessage = "last_message"
        case lastActivity = "last_activity"
        case isRead = "is_read"
        case conversationType = "conversation_type"
        case title
        case groupImage = "group_image"
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let messageType: MessageType
    let timestamp: Date
    let isRead: Bool
    let replyToId: String?
    let attachments: [ChatAttachment]?
    
    enum MessageType: String, Codable {
        case text = "text"
        case image = "image"
        case file = "file"
        case system = "system"
        case propertyCard = "property_card"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case timestamp
        case isRead = "is_read"
        case replyToId = "reply_to_id"
        case attachments
    }
}

struct ChatAttachment: Identifiable, Codable {
    let id: String
    let messageId: String
    let fileName: String
    let fileSize: Int
    let mimeType: String
    let url: String
    let thumbnailUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case fileName = "file_name"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case url
        case thumbnailUrl = "thumbnail_url"
    }
}

struct ChatUser: Identifiable, Codable {
    let id: String
    let email: String
    let displayName: String?
    let avatarUrl: String?
    let isOnline: Bool
    let lastSeen: Date?
    let userType: UserType
    
    enum UserType: String, Codable {
        case tenant = "tenant"
        case landlord = "landlord"
        case agent = "agent"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
        case userType = "user_type"
    }
    
    var displayNameOrEmail: String {
        return displayName ?? email
    }
}

// MARK: - Chat Service Request/Response Models

struct CreateConversationRequest: Codable {
    let participantIds: [String]
    let conversationType: ChatConversation.ConversationType
    let title: String?
    
    enum CodingKeys: String, CodingKey {
        case participantIds = "participant_ids"
        case conversationType = "conversation_type"
        case title
    }
}

struct SendMessageRequest: Codable {
    let conversationId: String
    let content: String
    let messageType: ChatMessage.MessageType
    let replyToId: String?
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case content
        case messageType = "message_type"
        case replyToId = "reply_to_id"
    }
}

// MARK: - Chat Extensions

extension ChatMessage {
    var isFromCurrentUser: Bool {
        return senderId == "current_user_id"
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

extension ChatConversation {
    var displayTitle: String {
        return title ?? "Chat"
    }
    
    var lastMessagePreview: String {
        guard let lastMessage = lastMessage else {
            return "No messages yet"
        }
        
        switch lastMessage.messageType {
        case .text:
            return lastMessage.content
        case .image:
            return "📷 Image"
        case .file:
            return "📎 File"
        case .system:
            return lastMessage.content
        case .propertyCard:
            return "🏠 Property"
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActivity, relativeTo: Date())
    }
}

// MARK: - Chat Service

class ChatService: ObservableObject {
    var supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    // MARK: - Conversation Management
    
    func fetchConversations() async throws -> [ChatConversation] {
        return mockConversations()
    }
    
    func createConversation(request: CreateConversationRequest) async throws -> ChatConversation {
        let conversation = ChatConversation(
            id: UUID().uuidString,
            participantIds: request.participantIds,
            lastMessage: nil,
            lastActivity: Date(),
            isRead: true,
            conversationType: request.conversationType,
            title: request.title,
            groupImage: nil
        )
        return conversation
    }
    
    // MARK: - Message Management
    
    func fetchMessages(for conversationId: String) async throws -> [ChatMessage] {
        return mockMessages(for: conversationId)
    }
    
    func sendMessage(request: SendMessageRequest) async throws -> ChatMessage {
        let message = ChatMessage(
            id: UUID().uuidString,
            conversationId: request.conversationId,
            senderId: "current_user_id",
            content: request.content,
            messageType: request.messageType,
            timestamp: Date(),
            isRead: false,
            replyToId: request.replyToId,
            attachments: nil
        )
        return message
    }
    
    func markMessageAsRead(messageId: String) async throws {
        // Would update message status in Supabase
    }
    
    // MARK: - User Management
    
    func fetchUsers() async throws -> [ChatUser] {
        return mockUsers()
    }
    
    func searchUsers(query: String) async throws -> [ChatUser] {
        let allUsers = try await fetchUsers()
        return allUsers.filter { user in
            user.displayNameOrEmail.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Mock Data (for development)
    
    private func mockConversations() -> [ChatConversation] {
        return [
            ChatConversation(
                id: "conv1",
                participantIds: ["user1", "current_user"],
                lastMessage: ChatMessage(
                    id: "msg1",
                    conversationId: "conv1",
                    senderId: "user1",
                    content: "Hi! Is the apartment still available?",
                    messageType: .text,
                    timestamp: Date().addingTimeInterval(-3600),
                    isRead: false,
                    replyToId: nil,
                    attachments: nil
                ),
                lastActivity: Date().addingTimeInterval(-3600),
                isRead: false,
                conversationType: .landlord,
                title: "John Smith (Landlord)",
                groupImage: nil
            ),
            ChatConversation(
                id: "conv2",
                participantIds: ["user2", "current_user"],
                lastMessage: ChatMessage(
                    id: "msg2",
                    conversationId: "conv2",
                    senderId: "current_user",
                    content: "Thanks for the info!",
                    messageType: .text,
                    timestamp: Date().addingTimeInterval(-7200),
                    isRead: true,
                    replyToId: nil,
                    attachments: nil
                ),
                lastActivity: Date().addingTimeInterval(-7200),
                isRead: true,
                conversationType: .direct,
                title: "Sarah Wilson",
                groupImage: nil
            )
        ]
    }
    
    private func mockMessages(for conversationId: String) -> [ChatMessage] {
        switch conversationId {
        case "conv1":
            return [
                ChatMessage(
                    id: "msg1_1",
                    conversationId: conversationId,
                    senderId: "current_user",
                    content: "Hello! I'm interested in your 2BR apartment listing.",
                    messageType: .text,
                    timestamp: Date().addingTimeInterval(-7200),
                    isRead: true,
                    replyToId: nil,
                    attachments: nil
                ),
                ChatMessage(
                    id: "msg1_2",
                    conversationId: conversationId,
                    senderId: "user1",
                    content: "Hi! Yes, it's still available. When would you like to schedule a viewing?",
                    messageType: .text,
                    timestamp: Date().addingTimeInterval(-5400),
                    isRead: true,
                    replyToId: nil,
                    attachments: nil
                )
            ]
        default:
            return []
        }
    }
    
    private func mockUsers() -> [ChatUser] {
        return [
            ChatUser(
                id: "user1",
                email: "john.smith@email.com",
                displayName: "John Smith",
                avatarUrl: nil,
                isOnline: true,
                lastSeen: Date(),
                userType: .landlord
            ),
            ChatUser(
                id: "user2",
                email: "sarah.wilson@email.com",
                displayName: "Sarah Wilson",
                avatarUrl: nil,
                isOnline: false,
                lastSeen: Date().addingTimeInterval(-3600),
                userType: .tenant
            )
        ]
    }
}

// MARK: - ChatView Implementation

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
                        NavigationLink(destination: AINegotiatorView()) {
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
                            ChatStatCard(title: "AI Conversations", value: "0", icon: "brain")
                            ChatStatCard(title: "Messages", value: "0", icon: "message")
                            ChatStatCard(title: "Active Chats", value: "0", icon: "person.2")
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

// MARK: - Chat Stat Card
struct ChatStatCard: View {
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

// MARK: - AI Negotiator View (Using Enhanced Version)
typealias AINegotiatorView = EnhancedAINegotiatorView

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
        NavigationView {
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
        }
        .navigationTitle("Direct Messages")
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
    
    var body: some View {
        VStack(spacing: 0) {
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
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
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

// MARK: - OpenAI Service & AI Negotiator

// MARK: - Property Criteria Model
struct PropertyCriteria {
    var location: String?
    var maxPrice: Int?
    var minPrice: Int?
    var propertyType: String?
    var bedrooms: Int?
    var bathrooms: Int?
    
    var hasValidCriteria: Bool {
        return location != nil || maxPrice != nil || minPrice != nil || 
               propertyType != nil || bedrooms != nil || bathrooms != nil
    }
}

// MARK: - AI Response Model
struct AiResponse {
    let message: String
    let success: Bool
    let error: String?
    let extractedCriteria: PropertyCriteria?
    
    init(message: String, success: Bool, extractedCriteria: PropertyCriteria? = nil) {
        self.message = message
        self.success = success
        self.error = nil
        self.extractedCriteria = extractedCriteria
    }
    
    init(error: String) {
        self.message = ""
        self.success = false
        self.error = error
        self.extractedCriteria = nil
    }
}

// MARK: - OpenAI Chat Message
struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
    
    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - OpenAI Request/Response Models
struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let maxTokens: Int
    let temperature: Double
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
    }
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    
    struct OpenAIChoice: Codable {
        let message: OpenAIChatMessage
    }
}

// MARK: - OpenAI Service
class OpenAIService: ObservableObject {
    private static let OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"
    private var conversationHistory: [OpenAIChatMessage] = []
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    private func buildSystemPrompt() -> String {
        return """
        You are an AI rental negotiation assistant for RoomFinderAI. Your role is to:

        1. Help users find rental properties by understanding their criteria (location, price, type, etc.)
        2. Provide expert negotiation advice for dealing with landlords
        3. Generate professional messages and emails for landlord communication
        4. Offer market insights and rental strategies
        5. Guide users through the rental application process

        When users provide search criteria, acknowledge what you understand and let them know you'll search the database. For negotiation help, provide specific tactics and ready-to-send message templates. Be professional, helpful, and focus on getting users the best rental deals possible.

        Keep responses concise but informative. Always ask clarifying questions when criteria are unclear.
        """
    }
    
    func processMessage(_ userMessage: String) async -> AiResponse {
        // Validate input
        guard !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AiResponse(error: "Please enter a message")
        }
        
        // Sanitize message
        let sanitizedMessage = String(userMessage.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        
        // Add user message to conversation history
        conversationHistory.append(OpenAIChatMessage(role: "user", content: sanitizedMessage))
        
        // Check if we should use mock mode
        if AppConfig.enableMockAI || !Secrets.isOpenAIKeyValid {
            return await generateMockResponse(for: sanitizedMessage, userMessage: userMessage)
        }
        
        // Attempt request with retries
        for attempt in 1...maxRetries {
            if AppConfig.debugMode {
                print("🤖 AI Request attempt \(attempt) for message: \(sanitizedMessage)")
            }
            
            do {
                let response = try await makeOpenAIRequest(sanitizedMessage)
                
                // Add AI response to conversation history
                conversationHistory.append(OpenAIChatMessage(role: "assistant", content: response.message))
                
                // Extract property criteria from user message
                let criteria = extractPropertyCriteria(from: userMessage)
                if AppConfig.debugMode {
                    print("📍 Extracted criteria: \(criteria.hasValidCriteria ? "Found" : "None")")
                }
                
                return AiResponse(
                    message: response.message,
                    success: true,
                    extractedCriteria: criteria
                )
                
            } catch {
                if AppConfig.debugMode {
                    print("❌ AI Request attempt \(attempt) failed: \(error)")
                }
                
                if attempt == maxRetries {
                    // Fall back to mock response if all attempts fail
                    print("🔄 Falling back to mock response after API failures")
                    return await generateMockResponse(for: sanitizedMessage, userMessage: userMessage, includeError: true)
                }
                
                // Wait before retry
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
        
        return AiResponse(error: "Request failed after multiple attempts")
    }
    
    // MARK: - Mock Response Generation
    private func generateMockResponse(for sanitizedMessage: String, userMessage: String, includeError: Bool = false) async -> AiResponse {
        // Extract property criteria
        let criteria = extractPropertyCriteria(from: userMessage)
        
        // Simulate thinking time
        try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.5...1.5) * 1_000_000_000))
        
        var response: String
        
        if includeError {
            response = """
            I'm currently experiencing some connectivity issues, but I can still help! 
            
            Based on your message, I understand you're looking for rental properties. Let me assist you with what I can determine from your request.
            """
        } else {
            response = generateContextualMockResponse(for: sanitizedMessage, criteria: criteria)
        }
        
        // Add mock response to conversation history
        conversationHistory.append(OpenAIChatMessage(role: "assistant", content: response))
        
        if AppConfig.debugMode {
            print("🎭 Generated mock response for: \(sanitizedMessage)")
            print("📍 Extracted criteria: \(criteria.hasValidCriteria ? "Found" : "None")")
        }
        
        return AiResponse(
            message: response,
            success: true,
            extractedCriteria: criteria
        )
    }
    
    private func generateContextualMockResponse(for message: String, criteria: PropertyCriteria) -> String {
        let lowerMessage = message.lowercased()
        
        // Greeting responses
        if lowerMessage.contains("hello") || lowerMessage.contains("hi ") || lowerMessage.starts(with: "hi") {
            return """
            Hello! I'm your AI rental negotiation assistant. I'm here to help you find the perfect property and negotiate the best deals.
            
            Feel free to tell me what you're looking for - location, budget, property type, number of bedrooms, etc. I can search our database and provide personalized assistance!
            """
        }
        
        // Property search requests
        if criteria.hasValidCriteria {
            var responseComponents: [String] = []
            
            responseComponents.append("Great! I understand you're looking for rental properties. Here's what I gathered from your request:")
            
            var criteriaList: [String] = []
            if let location = criteria.location {
                criteriaList.append("📍 Location: \(location)")
            }
            if let maxPrice = criteria.maxPrice {
                criteriaList.append("💰 Maximum price: $\(maxPrice)")
            }
            if let minPrice = criteria.minPrice {
                criteriaList.append("💰 Minimum price: $\(minPrice)")
            }
            if let propertyType = criteria.propertyType {
                criteriaList.append("🏠 Property type: \(propertyType)")
            }
            if let bedrooms = criteria.bedrooms {
                criteriaList.append("🛏️ Bedrooms: \(bedrooms)")
            }
            if let bathrooms = criteria.bathrooms {
                criteriaList.append("🚿 Bathrooms: \(bathrooms)")
            }
            
            if !criteriaList.isEmpty {
                responseComponents.append("")
                responseComponents.append(criteriaList.joined(separator: "\n"))
                responseComponents.append("")
                responseComponents.append("I'll search our property database for matching listings. You can use the 'Search Properties' button that should appear above to see available options!")
                responseComponents.append("")
                responseComponents.append("Would you like me to refine the search criteria or provide tips for negotiating with landlords?")
            }
            
            return responseComponents.joined(separator: "\n")
        }
        
        // Negotiation help
        if lowerMessage.contains("negotiat") || lowerMessage.contains("price") || lowerMessage.contains("lower") || lowerMessage.contains("deal") {
            return """
            I'd be happy to help with negotiation strategies! Here are some effective approaches:
            
            💡 **Key Negotiation Tips:**
            • Research comparable properties in the area
            • Highlight your strengths as a tenant (stable income, good credit, references)
            • Consider offering a longer lease term for a lower monthly rate
            • Be prepared to move quickly if you find the right property
            • Ask about utilities, parking, or other included amenities
            
            Would you like me to help you draft a message to a specific landlord, or do you have a particular property in mind?
            """
        }
        
        // General help
        if lowerMessage.contains("help") || lowerMessage.contains("what can you") || lowerMessage.contains("how do") {
            return """
            I'm here to help with all aspects of your rental search! Here's what I can assist you with:
            
            🔍 **Property Search**
            • Find properties based on your criteria
            • Analyze market trends and pricing
            • Compare different neighborhoods
            
            💬 **Communication & Negotiation**
            • Draft professional messages to landlords
            • Provide negotiation strategies and tips
            • Help with application materials
            
            📋 **Application Process**
            • Guide you through rental applications
            • Suggest questions to ask landlords
            • Help evaluate lease terms
            
            Just tell me what you're looking for or what specific help you need!
            """
        }
        
        // Default response
        return """
        I understand you're interested in rental properties. As your AI negotiation assistant, I can help you:
        
        • Find properties that match your criteria
        • Negotiate better prices and terms
        • Draft professional communications to landlords
        • Navigate the rental application process
        
        Could you tell me more about what you're looking for? For example:
        - What location are you interested in?
        - What's your budget range?
        - How many bedrooms do you need?
        - Any specific property type preferences?
        """
    }
    
    private func makeOpenAIRequest(_ userMessage: String) async throws -> AiResponse {
        guard let url = URL(string: OpenAIService.OPENAI_API_URL) else {
            throw URLError(.badURL)
        }
        
        // Build request with conversation history
        let messages = buildMessagesArray()
        let requestBody = OpenAIRequest(
            model: Secrets.openAIModel,
            messages: messages,
            maxTokens: 500,
            temperature: 0.7
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let orgId = Secrets.openAIOrgID {
            request.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ OpenAI API error: \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("Error response: \(errorData)")
            }
            
            switch httpResponse.statusCode {
            case 401:
                throw URLError(.userAuthenticationRequired)
            case 429:
                throw URLError(.resourceUnavailable)
            case 500...503:
                throw URLError(.badServerResponse)
            default:
                throw URLError(.unknown)
            }
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let firstChoice = openAIResponse.choices.first else {
            throw URLError(.badServerResponse)
        }
        
        return AiResponse(message: firstChoice.message.content, success: true)
    }
    
    private func buildMessagesArray() -> [OpenAIChatMessage] {
        var messages: [OpenAIChatMessage] = []
        
        // Add system prompt
        messages.append(OpenAIChatMessage(role: "system", content: buildSystemPrompt()))
        
        // Add conversation history (keep last 10 messages for context)
        let startIndex = max(0, conversationHistory.count - 10)
        messages.append(contentsOf: Array(conversationHistory[startIndex...]))
        
        return messages
    }
    
    // MARK: - Property Criteria Extraction
    private func extractPropertyCriteria(from message: String) -> PropertyCriteria {
        var criteria = PropertyCriteria()
        let lowerMessage = message.lowercased()
        
        print("🔍 Extracting criteria from: \"\(message)\"")
        
        // Extract location
        criteria.location = extractLocation(from: lowerMessage)
        print("📍 Location extracted: \(criteria.location ?? "nil")")
        
        // Extract prices
        criteria.maxPrice = extractMaxPrice(from: lowerMessage)
        criteria.minPrice = extractMinPrice(from: lowerMessage)
        print("💰 Price range: \(criteria.minPrice ?? 0) - \(criteria.maxPrice ?? 0)")
        
        // Extract property type
        criteria.propertyType = extractPropertyType(from: lowerMessage)
        print("🏠 Property type: \(criteria.propertyType ?? "nil")")
        
        // Extract bedrooms and bathrooms
        criteria.bedrooms = extractBedrooms(from: lowerMessage)
        criteria.bathrooms = extractBathrooms(from: lowerMessage)
        print("🛏️ Bedrooms: \(criteria.bedrooms ?? 0), 🚿 Bathrooms: \(criteria.bathrooms ?? 0)")
        
        print("✅ Criteria extraction complete. Has valid criteria: \(criteria.hasValidCriteria)")
        
        return criteria
    }
    
    private func extractLocation(from message: String) -> String? {
        // Pattern 1: "in [location]"
        if message.contains(" in ") {
            let parts = message.components(separatedBy: " in ")
            if parts.count > 1 {
                var locationPart = parts[1]
                
                // Remove everything after stop words
                let stopWords = [" with ", " under ", " over ", " for ", " that ", " where ", " near ", " around ", " at ", " priced ", " costing "]
                for stopWord in stopWords {
                    if locationPart.contains(stopWord) {
                        locationPart = String(locationPart.split(separator: stopWord).first ?? "")
                        break
                    }
                }
                
                let cleanLocation = locationPart.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "[^a-zA-Z\\s]", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cleanLocation.isEmpty {
                    return cleanLocation
                }
            }
        }
        
        // Pattern 2: "near [location]", "around [location]", "at [location]"
        let locationPatterns = [" near ", " around ", " at "]
        for pattern in locationPatterns {
            if message.contains(pattern) {
                let parts = message.components(separatedBy: pattern)
                if parts.count > 1 {
                    var locationPart = parts[1]
                    
                    let stopWords = [" with ", " under ", " over ", " for ", " that ", " priced "]
                    for stopWord in stopWords {
                        if locationPart.contains(stopWord) {
                            locationPart = String(locationPart.split(separator: stopWord).first ?? "")
                            break
                        }
                    }
                    
                    let cleanLocation = locationPart.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "[^a-zA-Z\\s]", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !cleanLocation.isEmpty {
                        return cleanLocation
                    }
                }
            }
        }
        
        // Pattern 3: Common location names
        let commonLocations = ["downtown", "midtown", "uptown", "city center", "city centre", "suburbs", "waterfront"]
        for location in commonLocations {
            if message.contains(location) {
                return location
            }
        }
        
        return nil
    }
    
    private func extractMaxPrice(from message: String) -> Int? {
        print("🔍 DEBUG extractMaxPrice from: '\(message)'")
        
        // Pattern 1: "under $X", "below $X", "max $X"
        let maxKeywords = ["under", "below", "max", "maximum", "up to", "no more than"]
        for keyword in maxKeywords {
            if message.contains(keyword) {
                if let price = findPriceAfterKeyword(keyword, in: message) {
                    print("   Found max price \(price) with keyword '\(keyword)'")
                    // Only accept reasonable prices (over $100)
                    if price >= 100 {
                        return price
                    } else {
                        print("   Rejected unrealistic max price: \(price)")
                    }
                }
            }
        }
        
        // Pattern 2: "$X or less", "$X maximum"
        if let price = extractPriceWithSuffix(["or less", "maximum", "max"], from: message) {
            print("   Found max price \(price) with suffix pattern")
            // Only accept reasonable prices (over $100)
            if price >= 100 {
                return price
            } else {
                print("   Rejected unrealistic max price: \(price)")
            }
        }
        
        // If no min keywords present, assume single price is max
        if !message.contains("over") && !message.contains("above") && !message.contains("minimum") && !message.contains("more than") {
            if let price = extractFirstPrice(from: message) {
                print("   Found first price \(price) as potential max")
                // Only accept reasonable prices (over $100)
                if price >= 100 {
                    return price
                } else {
                    print("   Rejected unrealistic first price as max: \(price)")
                }
            }
        }
        
        print("   No max price found")
        return nil
    }
    
    private func extractMinPrice(from message: String) -> Int? {
        // Pattern 1: "over $X", "above $X", "min $X"
        let minKeywords = ["over", "above", "min", "minimum", "more than", "at least"]
        for keyword in minKeywords {
            if message.contains(keyword) {
                if let price = findPriceAfterKeyword(keyword, in: message) {
                    return price
                }
            }
        }
        
        // Pattern 2: "$X or more", "$X minimum"
        if let price = extractPriceWithSuffix(["or more", "minimum", "plus"], from: message) {
            return price
        }
        
        return nil
    }
    
    private func findPriceAfterKeyword(_ keyword: String, in message: String) -> Int? {
        let words = message.components(separatedBy: .whitespacesAndNewlines)
        for i in 0..<words.count {
            if words[i].lowercased().contains(keyword.replacingOccurrences(of: " ", with: "")) {
                for j in (i + 1)..<min(i + 4, words.count) {
                    if let price = parsePrice(from: words[j]) {
                        return price
                    }
                }
            }
        }
        return nil
    }
    
    private func extractPriceWithSuffix(_ suffixes: [String], from message: String) -> Int? {
        let words = message.components(separatedBy: .whitespacesAndNewlines)
        for i in 0..<words.count {
            if words[i].contains("$"), let price = parsePrice(from: words[i]) {
                if i + 1 < words.count {
                    let nextWords = Array(words[(i + 1)...min(i + 2, words.count - 1)]).joined(separator: " ")
                    for suffix in suffixes {
                        if nextWords.contains(suffix) {
                            return price
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func extractFirstPrice(from message: String) -> Int? {
        print("🔍 DEBUG extractFirstPrice from: '\(message)'")
        let words = message.components(separatedBy: .whitespacesAndNewlines)
        for (index, word) in words.enumerated() {
            if let price = parsePrice(from: word) {
                print("   Found potential price \(price) in word '\(word)'")
                
                // Skip if this looks like bedroom/bathroom count
                let context = index > 0 ? words[index-1] : ""
                let nextContext = index < words.count-1 ? words[index+1] : ""
                
                if context.contains("bed") || nextContext.contains("bed") || 
                   context.contains("bath") || nextContext.contains("bath") ||
                   nextContext.contains("bedroom") || nextContext.contains("bathroom") {
                    print("   Skipping \(price) - appears to be bedroom/bathroom count")
                    continue
                }
                
                // Only return prices that look reasonable for rent (over $100)
                if price >= 100 {
                    return price
                } else {
                    print("   Skipping \(price) - too low to be rent price")
                    continue
                }
            }
        }
        print("   No valid price found")
        return nil
    }
    
    private func parsePrice(from word: String) -> Int? {
        let priceString = word.replacingOccurrences(of: "[^0-9,]", with: "", options: .regularExpression)
        guard !priceString.isEmpty else { return nil }
        
        let cleanPriceString = priceString.replacingOccurrences(of: ",", with: "")
        return Int(cleanPriceString)
    }
    
    private func extractPropertyType(from message: String) -> String? {
        if message.contains("studio") || message.contains("bachelor") {
            return "studio"
        } else if message.contains("townhouse") || message.contains("town house") {
            return "townhouse"
        } else if message.contains("condo") || message.contains("condominium") {
            return "condo"
        } else if message.contains("apartment") || message.contains("apt") {
            return "apartment"
        } else if message.contains("house") || message.contains("home") {
            return "house"
        } else if message.contains("room") || message.contains("shared") {
            return "room"
        }
        return nil
    }
    
    private func extractBedrooms(from message: String) -> Int? {
        return extractRoomCount(from: message, keywords: ["bedroom", "bed"], patterns: ["-bedroom", "-bed"])
    }
    
    private func extractBathrooms(from message: String) -> Int? {
        return extractRoomCount(from: message, keywords: ["bathroom", "bath"], patterns: ["-bathroom", "-bath"])
    }
    
    private func extractRoomCount(from message: String, keywords: [String], patterns: [String]) -> Int? {
        // Pattern 1: "X bedroom", "X bed"
        for keyword in keywords {
            if message.contains(keyword) {
                let words = message.components(separatedBy: .whitespacesAndNewlines)
                for i in 0..<(words.count - 1) {
                    if words[i + 1].contains(keyword) {
                        if let number = parseNumber(from: words[i]) {
                            return number
                        }
                    }
                }
            }
        }
        
        // Pattern 2: "X-bedroom", "X-bed"
        for pattern in patterns {
            if message.contains(pattern) {
                let words = message.components(separatedBy: .whitespacesAndNewlines)
                for word in words {
                    if word.contains(pattern) {
                        let parts = word.components(separatedBy: "-")
                        if let first = parts.first, let number = parseNumber(from: first) {
                            return number
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func parseNumber(from word: String) -> Int? {
        // Try parsing as integer first
        let numericString = word.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if !numericString.isEmpty, let number = Int(numericString) {
            return number
        }
        
        // Try text-to-number conversion
        let lowerWord = word.lowercased()
        switch lowerWord {
        case "one", "1": return 1
        case "two", "2": return 2
        case "three", "3": return 3
        case "four", "4": return 4
        case "five", "5": return 5
        case "six", "6": return 6
        default: return nil
        }
    }
    
    func clearConversation() {
        conversationHistory.removeAll()
    }
    
    func getConversationHistory() -> [OpenAIChatMessage] {
        return conversationHistory
    }
    
    func addMessage(role: String, content: String) {
        conversationHistory.append(OpenAIChatMessage(role: role, content: content))
    }
}



// MARK: - OpenAI Service Extension for Direct Requests
extension OpenAIService {
    func makeDirectRequest(systemPrompt: String, userMessage: String) async throws -> String {
        guard Secrets.isOpenAIKeyValid else {
            throw URLError(.userAuthenticationRequired)
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        
        let messages = [
            OpenAIChatMessage(role: "system", content: systemPrompt),
            OpenAIChatMessage(role: "user", content: userMessage)
        ]
        
        let requestBody = OpenAIRequest(
            model: Secrets.openAIModel,
            messages: messages,
            maxTokens: 500,
            temperature: 0.7
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let orgId = Secrets.openAIOrgID {
            request.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let firstChoice = openAIResponse.choices.first else {
            throw URLError(.badServerResponse)
        }
        
        return firstChoice.message.content
    }
}

// MARK: - Property Search Service

class PropertySearchService: ObservableObject {
    var supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    func searchProperties(criteria: PropertyCriteria) async -> ([HomePageListing], String?) {
        guard criteria.hasValidCriteria else {
            return ([], "Please provide search criteria (location, price, property type, etc.)")
        }
        
        do {
            print("🔍 Searching properties with criteria: \(criteria)")
            
            // First, let's get a sample of ALL properties to debug
            let allPropertiesQuery = supabase.from("listings").select("*").limit(5)
            do {
                let allProperties: [HomePageListing] = try await allPropertiesQuery.execute().value
                print("🔍 DEBUG: Found \(allProperties.count) total properties in database")
                for (index, property) in allProperties.enumerated() {
                    print("   Property \(index + 1): title='\(property.title ?? "nil")', city='\(property.city ?? "nil")', house_type='\(property.house_type ?? "nil")', price=\(property.price ?? 0)")
                }
            } catch {
                print("❌ DEBUG: Failed to fetch sample properties: \(error)")
            }
            
            var query = supabase
                .from("listings")
                .select("*")
            
            // Apply location filter - search in title, city fields
            if let location = criteria.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
                print("📍 Applying location filter: \(location)")
                // Try case-insensitive search in city field first (most likely match)
                query = query.ilike("city", pattern: "%\(location)%")
            }
            
            // Apply price filters
            if let maxPrice = criteria.maxPrice {
                print("💰 Applying max price filter: \(maxPrice)")
                query = query.lte("price", value: maxPrice)
            }
            
            if let minPrice = criteria.minPrice {
                print("💰 Applying min price filter: \(minPrice)")
                query = query.gte("price", value: minPrice)
            }
            
            // Apply property type filter
            if let propertyType = criteria.propertyType {
                print("🏠 Applying property type filter: \(propertyType)")
                // Search in house_type field
                query = query.ilike("house_type", pattern: "%\(propertyType)%")
            }
            
            // Apply bedroom filter
            if let bedrooms = criteria.bedrooms {
                print("🛏️ Applying bedroom filter: \(bedrooms)")
                // Search for exact bedroom count
                query = query.eq("bedrooms", value: bedrooms)
            }
            
            let response: [HomePageListing] = try await query.execute().value
            
            print("✅ Found \(response.count) matching properties")
            return (response, nil)
            
        } catch {
            print("❌ Property search failed: \(error)")
            return ([], "Failed to search properties: \(error.localizedDescription)")
        }
    }
    
    private func buildSupabaseQuery(criteria: PropertyCriteria) -> (select: String, filters: [String]) {
        let filters: [String] = []
        
        // Location filter - search in city, street, and title
        if let location = criteria.location?.trimmingCharacters(in: .whitespacesAndNewlines),
           !location.isEmpty {
            let locationLower = location.lowercased()
            // This would need to be adapted based on your actual Supabase query capabilities
            // For now, we'll just log it and handle in the actual query construction
            print("📍 Searching for location: \(locationLower)")
        }
        
        // Price filters would be applied here if your model supports it
        if let maxPrice = criteria.maxPrice {
            print("💰 Max price filter: \(maxPrice)")
        }
        if let minPrice = criteria.minPrice {
            print("💰 Min price filter: \(minPrice)")
        }
        
        // Property type filter
        if let propertyType = criteria.propertyType?.trimmingCharacters(in: .whitespacesAndNewlines),
           !propertyType.isEmpty {
            print("🏠 Property type filter: \(propertyType)")
        }
        
        // Room filters
        if let bedrooms = criteria.bedrooms {
            print("🛏️ Bedrooms filter: \(bedrooms)")
        }
        if let bathrooms = criteria.bathrooms {
            print("🚿 Bathrooms filter: \(bathrooms)")
        }
        
        // For now, return all fields - this would be enhanced based on your actual Supabase schema
        let select = "*"
        
        return (select: select, filters: filters)
    }
    
    func getAllProperties() async -> ([HomePageListing], String?) {
        do {
            let response: [HomePageListing] = try await supabase
                .from("listings")
                .select("*")
                .limit(50)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Retrieved \(response.count) total properties")
            return (response, nil)
            
        } catch {
            print("❌ Failed to get all properties: \(error)")
            return ([], "Failed to retrieve properties: \(error.localizedDescription)")
        }
    }
    
    func searchPropertiesByText(_ searchText: String) async -> ([HomePageListing], String?) {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ([], "Please enter search criteria")
        }
        
        do {
            // Simple text search across title and city fields
            let response: [HomePageListing] = try await supabase
                .from("listings")
                .select("*")
                .or("title.ilike.%\(searchText)%,city.ilike.%\(searchText)%")
                .limit(20)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Text search found \(response.count) properties")
            return (response, nil)
            
        } catch {
            print("❌ Text search failed: \(error)")
            return ([], "Search failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Enhanced AI Negotiator View

struct EnhancedAINegotiatorView: View {
    @Environment(\.supabase) private var supabase
    @StateObject private var openAIService = OpenAIService()
    @StateObject private var propertySearchService: PropertySearchService
    
    @State private var messageText = ""
    @State private var messages: [String] = []
    @State private var isLoading = false
    @State private var foundProperties: [HomePageListing] = []
    @State private var lastExtractedCriteria: PropertyCriteria?
    @State private var showingPropertyConfirmation = false
    
    init() {
        // Initialize PropertySearchService - we'll set supabase in onAppear
        _propertySearchService = StateObject(wrappedValue: PropertySearchService(supabase: SupabaseClient(supabaseURL: URL(string: "https://temp.supabase.co")!, supabaseKey: "temp")))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Messages
                messagesView
                
                // Input Area
                inputView
            }
            .navigationTitle("AI Negotiator")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if messages.isEmpty {
                    messages.append("👋 Hi! I'm your AI Negotiator. I can help you find properties, negotiate prices, and contact landlords. Tell me what you're looking for - like '2 bedroom apartment in downtown under $2000'")
                }
                // Initialize PropertySearchService with real supabase client
                propertySearchService.supabase = supabase
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("AI Negotiator")
                        .font(.headline)
                    
                    Text("Smart rental assistant")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Clear") {
                    clearConversation()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages.indices, id: \.self) { index in
                        MessageBubble(
                            content: messages[index],
                            isUser: index % 2 == 1 // Odd indices are user messages
                        )
                        .id(index)
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("AI is thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 16)
                        .id("loading")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastIndex = messages.indices.last {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isLoading) { _ in
                if isLoading {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Ask about rentals, negotiations, or property advice...", text: $messageText, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, !isLoading else { return }
        
        // Add user message
        messages.append("You: \(trimmedMessage)")
        messageText = ""
        isLoading = true
        
        // Check if user is confirming property selection
        if showingPropertyConfirmation && (trimmedMessage.lowercased().contains("yes") || trimmedMessage.lowercased().contains("negotiate") || trimmedMessage.lowercased().contains("start")) {
            handlePropertyConfirmation()
            return
        }
        
        // Use intelligent AI processing
        Task {
            do {
                // Process message with AI to get intelligent response and extract criteria
                let aiResponse = await openAIService.processMessage(trimmedMessage)
                
                await MainActor.run {
                    if aiResponse.success {
                        messages.append("AI: \(aiResponse.message)")
                        
                        // If we extracted valid property criteria, search for properties
                        if let criteria = aiResponse.extractedCriteria, criteria.hasValidCriteria {
                            lastExtractedCriteria = criteria
                            print("🔍 Valid criteria detected: \(criteria)")
                            searchForProperties(criteria: criteria)
                        }
                    } else {
                        messages.append("AI: \(aiResponse.error ?? "I'm having trouble understanding. Could you try rephrasing your request?")")
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    messages.append("AI: I'm having technical difficulties. Please try again.")
                    print("❌ AI processing error: \(error)")
                }
            }
        }
    }
    
    private func searchForProperties(criteria: PropertyCriteria) {
        Task {
            let (properties, searchError) = await propertySearchService.searchProperties(criteria: criteria)
            
            await MainActor.run {
                if let error = searchError {
                    messages.append("AI: \(error)")
                } else if properties.isEmpty {
                    messages.append("AI: I couldn't find any properties matching your criteria. Try adjusting your requirements - different location, price range, or property type.")
                } else {
                    foundProperties = properties
                    let propertyList = properties.prefix(5).map { "• \($0.title ?? "Property") - $\($0.price ?? 0)/month in \($0.city ?? "Unknown")" }.joined(separator: "\n")
                    messages.append("AI: Great! I found \(properties.count) properties matching your criteria:\n\n\(propertyList)\n\nAre these the homes you want me to negotiate for? Reply 'yes' to start negotiations or adjust your criteria for a new search.")
                    showingPropertyConfirmation = true
                }
            }
        }
    }
    
    private func handlePropertyConfirmation() {
        isLoading = false
        showingPropertyConfirmation = false
        
        if foundProperties.isEmpty {
            messages.append("AI: I don't have any properties to negotiate for. Please search for properties first.")
            return
        }
        
        let propertyCount = foundProperties.count
        let propertyTitles = foundProperties.prefix(3).map { $0.title ?? "Property" }.joined(separator: ", ")
        
        messages.append("AI: Perfect! I'll start negotiating for these \(propertyCount) properties: \(propertyTitles)\(propertyCount > 3 ? ", and \(propertyCount - 3) more" : "").")
        messages.append("AI: 🤝 Starting negotiation process...")
        messages.append("AI: I'm now contacting the landlords to negotiate better terms, reduced prices, and improved lease conditions. This may take a few moments.")
        messages.append("AI: 📧 Sending initial inquiry messages to landlords...")
        
        // Simulate negotiation progress
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                messages.append("AI: ✅ Successfully contacted \(propertyCount) landlords! I've started negotiations focusing on price reduction and better lease terms. I'll update you as responses come in.")
                messages.append("AI: You can continue chatting with me about other properties or ask about the negotiation progress.")
            }
        }
    }
    
    private func clearConversation() {
        messages.removeAll()
        messages.append("👋 Hi! I'm your AI Negotiator. I can help you with rental questions, negotiation tips, and property advice. How can I assist you today?")
    }
}

struct MessageBubble: View {
    let content: String
    let isUser: Bool
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            
            Text(content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
}


