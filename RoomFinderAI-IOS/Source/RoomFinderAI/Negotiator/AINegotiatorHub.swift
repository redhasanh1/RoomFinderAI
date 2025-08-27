import SwiftUI
import Supabase

struct AINegotiatorHub: View {
  @Environment(\.supabase) private var supabase
  @State private var recent: [Conversation] = []
  @State private var featured: [Listing] = []
  @State private var errorText: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("AI Negotiator").font(.largeTitle.bold()).padding(.top, 4)

        // Quick Start from a listing
        Group {
          Text("Quick Start").font(.headline)
          if featured.isEmpty { 
            ProgressView().padding(.vertical, 6) 
          } else {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 12) {
                ForEach(featured) { listing in
                  NavigationLink {
                    AINegotiatorBootstrap(listing: listing, buyerEmail: "test-user@example.com", buyerBudget: listing.price)
                  } label: {
                    ListingCardView(listing: listing).frame(width: 260)
                  }
                }
              }
              .padding(.horizontal, UI.hPad)
            }
          }
        }

        // Recent Conversations
        Group {
          HStack {
            Text("Recent").font(.headline)
            Spacer()
          }
          if recent.isEmpty {
            Text("No recent conversations").foregroundStyle(.secondary)
          } else {
            ForEach(recent) { c in
              NavigationLink(destination:
                // minimal hand-off shell; fetch listing inside Bootstrap
                AINegotiatorView(conversationId: c.id,
                                  listing: Listing(id: c.listing_id?.uuidString ?? UUID().uuidString, 
                                                 title: "Listing", 
                                                 price: 1000, 
                                                 city: "",
                                                 street: "",
                                                 postalCode: "",
                                                 houseType: "Apartment", 
                                                 bedrooms: 1, 
                                                 utilities: "Not specified", 
                                                 description: nil, 
                                                 media: nil,
                                                 userEmail: "",
                                                 createdAt: Date(),
                                                 updatedAt: Date()),
                                  budget: nil,
                                  userEmail: c.buyer_email ?? "test-user@example.com")
              ) {
                HStack {
                  Image(systemName: "message")
                  VStack(alignment: .leading) {
                    Text(c.buyer_email ?? "—").font(.subheadline)
                    Text(c.id.uuidString.prefix(12) + "…").font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .padding()
                .cardBackground()
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .padding(.horizontal, UI.hPad)
    }
    .navigationTitle("AI")
    .navigationBarTitleDisplayMode(.inline)
    .task { await load() }
  }

  private func load() async {
    do {
      // Featured listings (first 10)
      let lr: [Listing] = try await supabase
        .from("listings")
        .select("id,title,price,city,street,postal_code,house_type,bedrooms,utilities,description,media,user_email,created_at,updated_at")
        .order("created_at", ascending: false)
        .limit(10)
        .execute().value
      featured = lr

      // Recently created conversations (last 20)
      let cr: [Conversation] = try await supabase
        .from("conversations")
        .select("id,listing_id,buyer_email,seller_email,created_at")
        .order("created_at", ascending: false)
        .limit(20)
        .execute().value
      recent = cr
    } catch {
      errorText = String(describing: error)
    }
  }
}