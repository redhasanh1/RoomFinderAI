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
      VStack(spacing: 0) {
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
              .background(Color.blue.opacity(0.1))
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
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        
        // Content Area
        if isLoading {
          Spacer()
          VStack(spacing: 16) {
            ProgressView()
              .scaleEffect(1.2)
            Text("Finding great rooms for you...")
              .font(.headline)
              .foregroundColor(.secondary)
          }
          Spacer()
        } else if let error = error {
          Spacer()
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
          .padding()
          Spacer()
        } else if filteredListings.isEmpty {
          Spacer()
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
          .padding()
          Spacer()
        } else {
          // Enhanced Grid Layout
          ScrollView {
            LazyVGrid(columns: [
              GridItem(.flexible(), spacing: 8),
              GridItem(.flexible(), spacing: 8)
            ], spacing: 16) {
              ForEach(filteredListings) { listing in
                EnhancedListingCardView(listing: listing)
              }
            }
            .padding()
          }
        }
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
            .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
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

// MARK: - Search View
struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedFilters: Set<String> = []
    @State private var showingFilters = false
    
    let availableFilters = ["Studio", "1 Bed", "2 Bed", "3+ Bed", "Furnished", "Pet-Friendly"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Search Header
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Advanced Search")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Find your perfect room with advanced filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // Search Bar
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.headline)
                    .fontWeight(.medium)
                
                TextField("Enter city, neighborhood, or address", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Quick Filters
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Quick Filters")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        selectedFilters.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(availableFilters, id: \.self) { filter in
                        SearchFilterChip(
                            title: filter,
                            isSelected: selectedFilters.contains(filter)
                        ) {
                            if selectedFilters.contains(filter) {
                                selectedFilters.remove(filter)
                            } else {
                                selectedFilters.insert(filter)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Search Button
            Button(action: {
                // TODO: Implement search functionality
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Search Properties")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
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
                .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
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
                                .background(Color.blue.opacity(0.1))
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
                                .background(Color.blue.opacity(0.1))
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
                .background(Color.red.opacity(0.1))
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
