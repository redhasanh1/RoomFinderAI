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
struct SimpleListing: Identifiable, Decodable {
  let id: UUID
  let title: String?
  let price: Int?
  let house_type: String?
  let bedrooms: Int?
  let utilities: String?
  let description: String?
}

// MARK: - Views
struct ListingsScreen: View {
  @Environment(\.supabase) private var supabase
  @State private var listings: [SimpleListing] = []
  @State private var isLoading = false
  @State private var errorText: String?

  var body: some View {
    NavigationView {
      Group {
        if isLoading {
          ProgressView("Loading…")
        } else if let errorText {
          VStack {
            Text("Error").font(.title).foregroundColor(.red)
            Text(errorText).font(.footnote).foregroundColor(.secondary)
            Button("Retry") { Task { await load() } }
              .buttonStyle(.borderedProminent)
              .padding(.top, 8)
          }
        } else {
          List(listings) { listing in
            VStack(alignment: .leading, spacing: 6) {
              Text(listing.title ?? "Untitled")
                .font(.headline)

              HStack {
                if let price = listing.price {
                  Text("$\(price)")
                }
                if let type = listing.house_type {
                  Text("· \(type)")
                }
                if let beds = listing.bedrooms {
                  Text("· \(beds) bd")
                }
              }
              .font(.subheadline)
              .foregroundColor(.secondary)

              if let desc = listing.description, !desc.isEmpty {
                Text(desc)
                  .font(.footnote)
                  .foregroundColor(.secondary)
                  .lineLimit(2)
              }
            }
            .padding(.vertical, 6)
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle("Listings")
      .task { await load() }
    }
  }

  private func load() async {
    isLoading = true
    errorText = nil
    defer { isLoading = false }

    do {
      let response = try await supabase.database
        .from("listings")
        .select("id,title,price,house_type,bedrooms,utilities,description")
        .order("id", ascending: true)
        .range(from: 0, to: 50)
        .execute()

      let decoded = try JSONDecoder().decode([SimpleListing].self, from: response.data)
      listings = decoded
    } catch {
      errorText = "\(error)"
      listings = []
    }
  }
}

// MARK: - App
@main
struct MyApp: App {
  private let supabase = SupabaseFactory.makeClient()
  
  var body: some Scene {
    WindowGroup {
      ListingsScreen()
        .environment(\.supabase, supabase)
    }
  }
}