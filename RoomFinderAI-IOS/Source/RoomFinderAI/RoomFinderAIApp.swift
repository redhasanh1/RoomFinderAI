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
              .padding(.horizontal, 20)
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
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
              ], spacing: 16) {
                ForEach(filteredListings) { listing in
                  EnhancedListingCardView(listing: listing)
                }
              }
              .padding(.bottom, 100) // Extra bottom padding to prevent tab bar overlap
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
          }
        }
        .padding(.horizontal, 8)
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
            .padding(.horizontal, 20)
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
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        )
                }
                .frame(height: 120)
                .aspectRatio(4/3, contentMode: .fill)
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
                        .padding(.trailing, 8)
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
                
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity)
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
        .padding(.top)
        .navigationBarHidden(true)
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
