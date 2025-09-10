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
              .background(Color(.systemGray6))
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
  @State private var filteredListings: [HomePageListing] = []
  @State private var isLoading = true
  @State private var error: String?
  @State private var searchText = ""
  @State private var selectedFilters: Set<String> = []
  @State private var selectedSort = "Recent"
  @State private var showingSortOptions = false
  @Environment(\.supabase) private var supabase
  
  let filterOptions = ["Studio", "1 Bed", "2 Bed", "3+ Bed", "Apartment", "House", "Furnished"]
  let sortOptions = ["Recent", "Price: Low to High", "Price: High to Low", "Alphabetical"]

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // Enhanced Header with Search
          VStack(spacing: 16) {
          HStack {
            Text("Find Your Room")
              .font(.largeTitle)
              .fontWeight(.bold)
            Spacer()
            
            Button(action: { showingSortOptions = true }) {
              HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text("Sort")
              }
              .font(.caption)
              .foregroundColor(.blue)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Color(.systemGray6))
              .cornerRadius(20)
            }
          }
          .padding(.horizontal)
          
          // Search Bar
          HStack {
            Image(systemName: "magnifyingglass")
              .foregroundColor(.gray)
            TextField("Search by location, title...", text: $searchText)
              .onChange(of: searchText) { _ in
                applyFilters()
              }
          }
          .padding()
          .background(Color(.systemGray6))
          .cornerRadius(12)
          .padding(.horizontal)
          
          // Filter Chips
          if !filterOptions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 12) {
                ForEach(filterOptions, id: \.self) { filter in
                  FilterChipView(
                    title: filter,
                    isSelected: selectedFilters.contains(filter)
                  ) {
                    if selectedFilters.contains(filter) {
                      selectedFilters.remove(filter)
                    } else {
                      selectedFilters.insert(filter)
                    }
                    applyFilters()
                  }
                }
              }
              .padding(.horizontal)
            }
          }
          
          // Results Count
          if !filteredListings.isEmpty {
            HStack {
              Text("\(filteredListings.count) properties found")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
            }
            .padding(.horizontal)
          }
          }
          .padding(.vertical, 16)
          .padding(.horizontal, 20)
          .background(Color(.systemBackground))
          .cornerRadius(16)
          .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
          
          // Featured Properties Section
          if isLoading {
            VStack(spacing: 16) {
              ProgressView()
                .scaleEffect(1.2)
              Text("Finding great rooms for you...")
                .font(.headline)
                .foregroundColor(.secondary)
            }
            .frame(minHeight: 200)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
          } else if let error = error {
            VStack(spacing: 16) {
              Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
              Text("Oops! Something went wrong")
                .font(.headline)
              Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
              Button("Try Again") {
                loadListings()
              }
              .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
          } else if filteredListings.isEmpty {
            VStack(spacing: 16) {
              Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
              Text("No rooms found")
                .font(.headline)
              Text("Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
              Button("Clear Filters") {
                searchText = ""
                selectedFilters.removeAll()
                applyFilters()
              }
              .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
          } else {
            VStack(spacing: 16) {
              // Section Header like Android app
              HStack {
                Text("Featured Properties")
                  .font(.title2)
                  .fontWeight(.bold)
                  .foregroundColor(.primary)
                Spacer()
                Button(action: { showingSortOptions = true }) {
                  HStack(spacing: 4) {
                    Text("Sort")
                    Image(systemName: "chevron.down")
                  }
                  .font(.subheadline)
                  .foregroundColor(.blue)
                }
              }
              .padding(.horizontal, 20)
              .padding(.top, 16)
              
              // Subtle divider like Android
              Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1)
                .opacity(0.3)
                .padding(.horizontal, 20)
              
              // Enhanced Grid Layout
              LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
              ], spacing: 16) {
                ForEach(filteredListings) { listing in
                  EnhancedListingCardView(listing: listing)
                }
              }
              .padding(.horizontal, 20)
              .padding(.bottom, 100) // Extra bottom padding to prevent tab bar overlap
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
      }
      .navigationBarHidden(true)
      .onAppear {
        loadListings()
      }
      .confirmationDialog("Sort By", isPresented: $showingSortOptions, titleVisibility: .visible) {
        ForEach(sortOptions, id: \.self) { option in
          Button(option) {
            selectedSort = option
            applyFilters()
          }
        }
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
          self.applyFilters()
        }
      } catch {
        await MainActor.run {
          self.error = error.localizedDescription
          self.isLoading = false
        }
      }
    }
  }
  
  private func applyFilters() {
    var filtered = listings
    
    // Apply search filter
    if !searchText.isEmpty {
      filtered = filtered.filter { listing in
        let titleMatch = listing.title?.lowercased().contains(searchText.lowercased()) ?? false
        let cityMatch = listing.city?.lowercased().contains(searchText.lowercased()) ?? false
        let descriptionMatch = listing.description?.lowercased().contains(searchText.lowercased()) ?? false
        return titleMatch || cityMatch || descriptionMatch
      }
    }
    
    // Apply category filters
    if !selectedFilters.isEmpty {
      filtered = filtered.filter { listing in
        for filter in selectedFilters {
          switch filter {
          case "Studio":
            if listing.bedrooms == 0 { return true }
          case "1 Bed":
            if listing.bedrooms == 1 { return true }
          case "2 Bed":
            if listing.bedrooms == 2 { return true }
          case "3+ Bed":
            if (listing.bedrooms ?? 0) >= 3 { return true }
          case "Apartment":
            if listing.house_type?.lowercased().contains("apartment") == true { return true }
          case "House":
            if listing.house_type?.lowercased().contains("house") == true { return true }
          case "Furnished":
            if listing.description?.lowercased().contains("furnished") == true { return true }
          default:
            break
          }
        }
        return false
      }
    }
    
    // Apply sorting
    switch selectedSort {
    case "Recent":
      filtered.sort { ($0.created_at ?? "") > ($1.created_at ?? "") }
    case "Price: Low to High":
      filtered.sort { ($0.price ?? 0) < ($1.price ?? 0) }
    case "Price: High to Low":
      filtered.sort { ($0.price ?? 0) > ($1.price ?? 0) }
    case "Alphabetical":
      filtered.sort { ($0.title ?? "") < ($1.title ?? "") }
    default:
      break
    }
    
    filteredListings = filtered
  }
}

// MARK: - Enhanced Components
struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(20)
        }
    }
}

struct EnhancedListingCardView: View {
    let listing: HomePageListing
    @State private var imageURL: URL?
    @Environment(\.supabase) private var supabase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with overlay elements
            ZStack(alignment: .topLeading) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        )
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Price Badge
                if let price = listing.price {
                    Text("$\(price)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Color.black.opacity(0.7)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        )
                        .padding(.top, 8)
                        .padding(.leading, 8)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(listing.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if let city = listing.city {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                HStack(spacing: 8) {
                    if let bedrooms = listing.bedrooms {
                        Label("\(bedrooms) bed", systemImage: "bed.double.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let type = listing.house_type {
                        Text("• \(type)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Action Button
                NavigationLink(destination: SimpleAINegotiatorView(listing: listing)) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                        Text("Negotiate")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                }
            }
            .padding(10)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .task {
            if let s = listing.coverURLString, let u = URL(string: s) { 
                imageURL = u 
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

// MARK: - Chat View
struct ChatView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Chat")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Chat functionality coming soon")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("Chat")
    }
}

// MARK: - Enhanced Search View
struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedLocation = ""
    @State private var minPrice: Double = 500
    @State private var maxPrice: Double = 3000
    @State private var bedrooms: Int = 0
    @State private var bathrooms: Double = 1.0
    @State private var propertyType: Set<String> = []
    @State private var amenities: Set<String> = []
    @State private var moveInDate = Date()
    @State private var maxCommute: Double = 30
    @State private var searchRadius: Double = 10
    @State private var showingResults = false
    @State private var showingAdvanced = false
    @State private var searchResults: [HomePageListing] = []
    @State private var savedSearches: [String] = ["Downtown Studio under $1500", "2BR near Campus"]
    @State private var searchHistory: [String] = []
    @Environment(\.supabase) private var supabase
    
    let propertyTypes = ["Studio", "Apartment", "House", "Condo", "Townhouse", "Loft"]
    let amenitiesList = ["WiFi", "Parking", "Laundry", "Gym", "Pool", "Balcony", "Air Conditioning", "Dishwasher", "Pet-Friendly", "Furnished", "Washer/Dryer", "Elevator", "Doorman", "Rooftop"]
    let bedroomOptions = [0, 1, 2, 3, 4, 5]
    let bathroomOptions = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Header
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "location.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Find Your Perfect Room")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Advanced search with smart filters")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // Main Search Bar
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search by location, neighborhood, or property name", text: $searchText)
                                .onChange(of: searchText) { _ in
                                    if !searchText.isEmpty && !searchHistory.contains(searchText) {
                                        searchHistory.append(searchText)
                                    }
                                }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        
                        // Location Radius
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Search within \(Int(searchRadius)) miles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text("1mi")
                                    .font(.caption)
                                Slider(value: $searchRadius, in: 1...50, step: 1)
                                    .accentColor(.blue)
                                Text("50mi")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Quick Search Suggestions
                    if !searchHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Searches")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(searchHistory.suffix(5).reversed(), id: \.self) { search in
                                        Button(action: { searchText = search }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "clock")
                                                    .font(.caption)
                                                Text(search)
                                                    .font(.caption)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(.systemGray5))
                                            .foregroundColor(.blue)
                                            .cornerRadius(16)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Price Range
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Price Range")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("$\(Int(minPrice))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("$\(Int(maxPrice))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal)
                            
                            // Custom dual slider implementation
                            VStack(spacing: 8) {
                                Text("Min: $\(Int(minPrice))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $minPrice, in: 300...5000, step: 50)
                                    .accentColor(.green)
                                
                                Text("Max: $\(Int(maxPrice))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $maxPrice, in: 500...8000, step: 50)
                                    .accentColor(.red)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Property Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Property Details")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            // Bedrooms
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bedrooms")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(bedroomOptions, id: \.self) { count in
                                            Button(action: { bedrooms = count }) {
                                                Text(count == 0 ? "Studio" : "\(count)")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(bedrooms == count ? .white : .blue)
                                                    .frame(width: 50, height: 40)
                                                    .background(bedrooms == count ? Color.blue : Color(.systemGray6))
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Bathrooms
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bathrooms")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(bathroomOptions, id: \.self) { count in
                                            Button(action: { bathrooms = count }) {
                                                Text(count == floor(count) ? "\(Int(count))" : "\(count, specifier: "%.1f")")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(bathrooms == count ? .white : .orange)
                                                    .frame(width: 50, height: 40)
                                                    .background(bathrooms == count ? Color.orange : Color(.systemGray6))
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // Property Types
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Property Type")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(propertyTypes, id: \.self) { type in
                                Button(action: {
                                    if propertyType.contains(type) {
                                        propertyType.remove(type)
                                    } else {
                                        propertyType.insert(type)
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: propertyType.contains(type) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(propertyType.contains(type) ? .green : .gray)
                                        Text(type)
                                            .fontWeight(.medium)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(propertyType.contains(type) ? Color.green.opacity(0.3) : Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Amenities
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Amenities")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(amenitiesList, id: \.self) { amenity in
                                Button(action: {
                                    if amenities.contains(amenity) {
                                        amenities.remove(amenity)
                                    } else {
                                        amenities.insert(amenity)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        if amenities.contains(amenity) {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        Text(amenity)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(amenities.contains(amenity) ? .white : .purple)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(amenities.contains(amenity) ? Color.purple : Color(.systemGray6))
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Move-in Date
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferred Move-in Date")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        DatePicker("Move-in Date", selection: $moveInDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding(.horizontal)
                    }
                    
                    // Saved Searches
                    if !savedSearches.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Saved Searches")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(savedSearches, id: \.self) { search in
                                Button(action: { loadSavedSearch(search) }) {
                                    HStack {
                                        Image(systemName: "bookmark.fill")
                                            .foregroundColor(.yellow)
                                        Text(search)
                                            .font(.subheadline)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .foregroundColor(.primary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Search Actions
                    VStack(spacing: 12) {
                        Button(action: performSearch) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Search Properties")
                                    .fontWeight(.semibold)
                                if !searchResults.isEmpty {
                                    Text("(\(searchResults.count))")
                                }
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
                        
                        HStack(spacing: 12) {
                            Button("Save Search") {
                                saveCurrentSearch()
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            Button("Clear All") {
                                clearAllFilters()
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Advanced Search")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingResults) {
                SearchResultsView(results: searchResults)
            }
        }
    }
    
    private func performSearch() {
        // Add search term to history
        if !searchText.isEmpty && !searchHistory.contains(searchText) {
            searchHistory.append(searchText)
            if searchHistory.count > 20 {
                searchHistory.removeFirst()
            }
        }
        
        Task {
            await searchListings()
        }
    }
    
    private func searchListings() async {
        do {
            // Fetch all listings first (in a real app, you'd want server-side filtering)
            let allListings: [HomePageListing] = try await supabase
                .from("listings")
                .select("*")
                .execute()
                .value
            
            // Apply client-side filtering
            let filtered = allListings.filter { listing in
                // Location/text search
                if !searchText.isEmpty {
                    let titleMatch = listing.title?.lowercased().contains(searchText.lowercased()) ?? false
                    let cityMatch = listing.city?.lowercased().contains(searchText.lowercased()) ?? false
                    let descriptionMatch = listing.description?.lowercased().contains(searchText.lowercased()) ?? false
                    
                    if !titleMatch && !cityMatch && !descriptionMatch {
                        return false
                    }
                }
                
                // Price range filter
                if let price = listing.price {
                    if Double(price) < minPrice || Double(price) > maxPrice {
                        return false
                    }
                }
                
                // Bedroom filter
                if bedrooms > 0 {
                    if listing.bedrooms != bedrooms {
                        return false
                    }
                } else if bedrooms == 0 { // Studio
                    if listing.bedrooms != 0 {
                        return false
                    }
                }
                
                // Property type filter
                if !propertyType.isEmpty {
                    let hasMatchingType = propertyType.contains { type in
                        listing.house_type?.lowercased().contains(type.lowercased()) ?? false
                    }
                    if !hasMatchingType {
                        return false
                    }
                }
                
                // Amenities filter
                if !amenities.isEmpty {
                    let description = listing.description?.lowercased() ?? ""
                    let hasAllAmenities = amenities.allSatisfy { amenity in
                        description.contains(amenity.lowercased())
                    }
                    if !hasAllAmenities {
                        return false
                    }
                }
                
                return true
            }
            
            await MainActor.run {
                self.searchResults = filtered
                self.showingResults = true
            }
            
        } catch {
            print("Search error: \(error)")
            await MainActor.run {
                self.searchResults = []
                self.showingResults = true
            }
        }
    }
    
    private func saveCurrentSearch() {
        let searchName = searchText.isEmpty ? "Custom Search \(savedSearches.count + 1)" : searchText
        if !savedSearches.contains(searchName) {
            savedSearches.append(searchName)
        }
        
        // In a real app, you'd persist these search parameters to UserDefaults or Core Data
        // For now, we'll just store the name in the array
    }
    
    private func loadSavedSearch(_ search: String) {
        searchText = search
        
        // Set some smart defaults based on saved search names
        if search.lowercased().contains("studio") {
            bedrooms = 0
            propertyType.insert("Studio")
        } else if search.lowercased().contains("1br") || search.lowercased().contains("1 bed") {
            bedrooms = 1
        } else if search.lowercased().contains("2br") || search.lowercased().contains("2 bed") {
            bedrooms = 2
        }
        
        if search.lowercased().contains("downtown") {
            maxPrice = 2500 // Downtown typically more expensive
        }
        
        if search.lowercased().contains("campus") {
            maxPrice = 1800 // Student housing typically cheaper
            amenities.insert("WiFi")
        }
    }
    
    private func clearAllFilters() {
        searchText = ""
        minPrice = 500
        maxPrice = 3000
        bedrooms = 0
        bathrooms = 1.0
        propertyType.removeAll()
        amenities.removeAll()
        moveInDate = Date()
        searchRadius = 10
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
                                EnhancedListingCardView(listing: listing)
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
                .padding(.horizontal, 12)
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
    @State private var showingSuccessAlert = false
    
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
                
                VStack(spacing: 16) {
                    // Basic Information
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Property Title *")
                                .font(.headline)
                                .fontWeight(.medium)
                            TextField("e.g., Spacious 1BR near campus", text: $title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location *")
                                .font(.headline)
                                .fontWeight(.medium)
                            TextField("City, neighborhood, or address", text: $location)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Monthly Rent *")
                                .font(.headline)
                                .fontWeight(.medium)
                            HStack {
                                Text("$")
                                    .foregroundColor(.secondary)
                                TextField("1200", text: $price)
                                    .keyboardType(.numberPad)
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bedrooms")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            HStack {
                                Button("-") {
                                    if bedrooms > 0 { bedrooms -= 1 }
                                }
                                .frame(width: 40, height: 40)
                                .background(Color(.systemGray6))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                                
                                Text("\(bedrooms)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .frame(minWidth: 50)
                                
                                Button("+") {
                                    if bedrooms < 10 { bedrooms += 1 }
                                }
                                .frame(width: 40, height: 40)
                                .background(Color(.systemGray6))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                                
                                Spacer()
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .fontWeight(.medium)
                            TextField("Describe your property...", text: $description, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(4...8)
                        }
                    }
                    
                    // Submit Button
                    Button(action: {
                        showingSuccessAlert = true
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Post Property")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(title.isEmpty || location.isEmpty || price.isEmpty)
                    .opacity(title.isEmpty || location.isEmpty || price.isEmpty ? 0.6 : 1.0)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Post Property")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                // Clear form
                title = ""
                description = ""
                price = ""
                location = ""
                bedrooms = 1
            }
        } message: {
            Text("Your property has been posted successfully!")
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
        // 1. Home Tab - Room listings (like Android HomeFragment)
        NavigationView { HomeScreen() }
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
        NavigationView { SimpleProfileView() }
          .tabItem { Label("Profile", systemImage: "person.fill") }
      }
      .environment(\.supabase, supabase)
    }
  }
}
