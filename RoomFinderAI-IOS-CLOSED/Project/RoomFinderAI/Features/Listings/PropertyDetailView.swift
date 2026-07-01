import SwiftUI

struct PropertyDetailView: View {
  let listing: Listing
  @State private var budget = ""
  
  var body: some View {
    ScrollView {
      ListingCardView(listing: listing).padding(.horizontal,16)
      VStack(alignment:.leading, spacing:12) {
        Text("Your budget").font(.subheadline)
        TextField("$", text: $budget).textFieldStyle(.roundedBorder)
        NavigationLink("Negotiate") {
          AINegotiatorBootstrap(listing: listing,
                                buyerEmail: "test-user@example.com",
                                buyerBudget: Double(budget))
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(16)
    }
    .navigationTitle(listing.title ?? "Listing")
    .navigationBarTitleDisplayMode(.inline)
  }
}