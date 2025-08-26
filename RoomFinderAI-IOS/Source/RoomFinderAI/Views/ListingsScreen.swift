import SwiftUI
import Supabase

// Simplified Listing model for the UI
struct SimpleListing: Identifiable, Decodable {
  let id: UUID
  let title: String?
  let price: Int?
  let house_type: String?
  let bedrooms: Int?
  let utilities: String?
  let description: String?
}

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

      let decoded: [SimpleListing] = try response.value
      listings = decoded
    } catch {
      errorText = "\(error)"
      listings = []
    }
  }
}