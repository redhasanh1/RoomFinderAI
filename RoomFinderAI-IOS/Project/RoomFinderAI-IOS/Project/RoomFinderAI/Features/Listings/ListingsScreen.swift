import SwiftUI
import Supabase

struct ListingsScreen: View {
  @Environment(\.supabase) private var supabase

  @State private var items: [CardListing] = []
  @State private var errorText: String?
  @State private var isLoading = false
  @State private var isRefreshing = false
  @State private var page = 0
  private let pageSize = 20

  var body: some View {
    NavigationView {
      Group {
        if isLoading && items.isEmpty {
          ProgressView("Loading…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = errorText, items.isEmpty {
          VStack(spacing: 12) {
            Text("Error").font(.title3.bold()).foregroundStyle(.red)
            Text(err).font(.footnote).foregroundStyle(.secondary)
            Button("Retry") { Task { await reload() } }.buttonStyle(.borderedProminent)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
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
              if isLoading { 
                ProgressView()
                  .padding(.vertical, 12) 
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
          }
          .refreshable { await refresh() }
        }
      }
      .navigationTitle("Listings")
      .task { 
        if items.isEmpty { 
          await reload() 
        } 
      }
    }
  }

  // MARK: Data
  private func reload() async {
    page = 0
    items.removeAll()
    await loadMore()
  }

  private func refresh() async {
    isRefreshing = true
    defer { isRefreshing = false }
    await reload()
  }

  private func loadMore() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }

    do {
      // Select only columns we need including media
      let resp = try await supabase.database
        .from("listings")
        .select("id,title,price,house_type,bedrooms,description,created_at,media")
        .order("id", ascending: true)
        .range(from: page * pageSize, to: (page + 1) * pageSize - 1)
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