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

// MARK: - Tab View
struct AppTabs: View {
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