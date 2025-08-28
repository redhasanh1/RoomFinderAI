import SwiftUI
import Supabase

struct AINegotiatorBootstrap: View {
  let listing: Listing
  let buyerEmail: String  
  let buyerBudget: Double?
  
  @Environment(\.supabase) private var supabase
  @State private var showNegotiator = false
  
  var body: some View {
    VStack(spacing: 20) {
      
      VStack(alignment: .leading, spacing: 12) {
        Text("Ready to Negotiate")
          .font(.title2)
          .fontWeight(.bold)
        
        Text("Property: \(listing.title ?? "Listing")")
          .font(.headline)
        
        Text("Listed Price: $\(listing.price ?? 0)")
          .font(.subheadline)
        
        if let budget = buyerBudget {
          Text("Your Budget: $\(Int(budget))")
            .font(.subheadline) 
        }
      }
      .padding()
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      
      Button("Start AI Negotiation") {
        showNegotiator = true
      }
      .buttonStyle(.borderedProminent)
      .font(.headline)
      
    }
    .padding()
    .navigationTitle("Negotiation Setup")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showNegotiator) {
      AINegotiatorView(listing: listing, buyerEmail: buyerEmail, buyerBudget: buyerBudget)
    }
  }
}