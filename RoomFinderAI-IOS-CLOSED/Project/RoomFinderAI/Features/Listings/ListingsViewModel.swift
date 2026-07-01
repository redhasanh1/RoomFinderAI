import Foundation
import Supabase

@MainActor
final class ListingsViewModel: ObservableObject {
  @Published var items: [Listing] = []
  @Published var loading = false
  private let service: SupabaseService
  init(client: SupabaseClient) { self.service = SupabaseService(client) }

  func load() async {
    guard !loading else { return }
    loading = true; defer { loading = false }
    do { items = try await service.fetchListings() }
    catch {
      print("Listings fetch error:", error)
    }
  }
}

