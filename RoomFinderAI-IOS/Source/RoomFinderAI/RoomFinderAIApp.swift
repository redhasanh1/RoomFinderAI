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

struct CardListing: Identifiable, Decodable, Equatable {
  let id: UUID
  let title: String?
  let price: Int?
  let house_type: String?
  let bedrooms: Int?
  let utilities: String?
  let description: String?
  let created_at: String?

  // media is jsonb: [] | [{"url":"…"}] | null
  let media: [MediaItem]?

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

// MARK: - Views
struct ListingCardView: View {
  let listing: CardListing
  @State private var imageURL: URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ZStack {
        Rectangle().fill(Color.gray.opacity(0.12))
        if let imageURL {
          AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty: ProgressView().scaleEffect(0.9)
            case .success(let img): img.resizable().scaledToFill()
            case .failure: Image(systemName: "photo").font(.largeTitle)
            @unknown default: EmptyView()
            }
          }
        } else {
          Image(systemName: "photo").font(.largeTitle)
        }
      }
      .frame(height: 180)
      .clipShape(RoundedRectangle(cornerRadius: 16))

      VStack(alignment: .leading, spacing: 4) {
        Text(listing.title?.isEmpty == false ? listing.title! : "Untitled")
          .font(.headline)
          .lineLimit(2)

        HStack(spacing: 8) {
          if let price = listing.price { Text("$\(price)") }
          if let type = listing.house_type { Text("· \(type)") }
          if let bd = listing.bedrooms { Text("· \(bd) bd") }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)

        if let desc = listing.description, !desc.isEmpty {
          Text(desc).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
        }
      }
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.black.opacity(0.06)))
    .task {
      if let s = listing.coverURLString, let u = URL(string: s) {
        imageURL = u
      } else {
        imageURL = nil
      }
    }
  }
}

struct ListingsScreen: View {
  @Environment(\.supabase) private var supabase

  @State private var items: [CardListing] = []
  @State private var errorText: String?
  @State private var isLoading = false
  @State private var page = 0
  private let pageSize = 20

  var body: some View {
    NavigationView {
      Group {
        if isLoading && items.isEmpty {
          ProgressView("Loading…")
        } else if let err = errorText, items.isEmpty {
          VStack(spacing: 10) {
            Text("Error").font(.title3.bold()).foregroundStyle(.red)
            Text(err).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") { Task { await reload() } }.buttonStyle(.borderedProminent)
          }
          .padding()
        } else {
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(items) { listing in
                ListingCardView(listing: listing)
                  .onAppear {
                    if listing.id == items.last?.id {
                      Task { await loadMore() }
                    }
                  }
              }
              if isLoading { ProgressView().padding(.vertical, 12) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .refreshable { await reload() }
          }
        }
      }
      .navigationTitle("Listings")
      .task { if items.isEmpty { await reload() } }
    }
  }

  private func reload() async {
    page = 0
    items.removeAll()
    await loadMore()
  }

  private func loadMore() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }

    do {
      let resp = try await supabase.database
        .from("listings")
        .select("id,title,price,house_type,bedrooms,utilities,description,created_at,media") // <- includes media
        .order("id", ascending: true)                                                         // cheap order
        .range(from: page * pageSize, to: page * pageSize + (pageSize - 1))
        .execute()

      let pageItems = try JSONDecoder().decode([CardListing].self, from: resp.data)
      if !pageItems.isEmpty {
        items.append(contentsOf: pageItems)
        page += 1
      }
      errorText = nil
    } catch {
      errorText = String(describing: error)
    }
  }
}

// MARK: - Tab View
struct AppTabs: View {
  var body: some View {
    TabView {
      ListingsScreen()
        .tabItem { 
          Label("Listings", systemImage: "house.fill") 
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