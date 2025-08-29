import SwiftUI
import Supabase

struct ListingsView: View {
  @Environment(\.supabase) private var supabase
  @StateObject private var vm: ListingsViewModel

  init() { _vm = StateObject(wrappedValue: ListingsViewModel(client: SupabaseKey.defaultValue)) }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 14) {
        ForEach(vm.items) { listing in
          NavigationLink { PropertyDetailView(listing: listing) } label {
            ListingCardView(listing: listing)
          }.buttonStyle(.plain)
        }
        if vm.loading { ProgressView().padding(.vertical) }
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
    }
    .navigationTitle("Search Listings")
    .task { await vm.load() }
  }
}