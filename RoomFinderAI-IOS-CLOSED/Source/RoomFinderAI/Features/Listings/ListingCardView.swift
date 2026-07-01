import SwiftUI
import Supabase

struct ListingCardView: View {
  @Environment(\.supabase) private var supabase
  let listing: CardListing

  // CONFIGURE THESE to match your project:
  private let bucket = "listings-media"   // adjust if your bucket has a different name
  private let isBucketPublic = true       // set false to use signed URLs

  @State private var imageURL: URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Image
      ZStack {
        Rectangle().fill(Color.gray.opacity(0.12))
        if let imageURL {
          AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty: 
              ProgressView()
                .scaleEffect(0.9)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let img): 
              img
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failure: 
              Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            @unknown default: 
              EmptyView()
            }
          }
        } else {
          Image(systemName: "photo")
            .font(.largeTitle)
            .foregroundColor(.gray.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(height: 180)
      .clipShape(RoundedRectangle(cornerRadius: 16))

      // Text content
      VStack(alignment: .leading, spacing: 4) {
        Text(listing.title?.isEmpty == false ? listing.title! : "Untitled")
          .font(.headline)
          .lineLimit(2)

        HStack(spacing: 8) {
          if let price = listing.price { 
            Text("$\(price)")
              .fontWeight(.semibold)
              .foregroundColor(.primary)
          }
          if let type = listing.house_type { 
            Text("· \(type)")
              .foregroundStyle(.secondary)
          }
          if let bd = listing.bedrooms { 
            Text("· \(bd) bd")
              .foregroundStyle(.secondary)
          }
        }
        .font(.subheadline)

        if let desc = listing.description, !desc.isEmpty {
          Text(desc)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        
        // Negotiate button
        HStack {
          Spacer()
          NavigationLink(destination: createNegotiatorView()) {
            HStack(spacing: 6) {
              Image(systemName: "brain")
                .font(.caption)
              Text("Negotiate")
                .font(.caption)
                .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
        }
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 18)
        .fill(Color(.secondarySystemBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .strokeBorder(Color.black.opacity(0.05))
    )
    .task { await resolveMediaURL() }
  }

  private func resolveMediaURL() async {
    // Check if we have any media path
    guard let path = listing.coverImagePath, !path.isEmpty else { return }
    
    // Use the storage URL helper to get the proper URL
    if isBucketPublic {
      imageURL = StorageURL.publicURL(supabase: supabase, bucket: bucket, path: path)
    } else {
      imageURL = await StorageURL.signedURL(supabase: supabase, bucket: bucket, path: path)
    }
  }
  
  private func createNegotiatorView() -> AINegotiatorView {
    // Convert CardListing to Models/Listing format
    let dateFormatter = ISO8601DateFormatter()
    let createdAtDate = listing.created_at.flatMap { dateFormatter.date(from: $0) } ?? Date()
    
    let negotiatorListing = Listing(
      id: listing.id.uuidString,
      title: listing.title ?? "Untitled",
      price: Double(listing.price ?? 0),
      city: "", // CardListing doesn't have city
      street: "", // CardListing doesn't have street
      postalCode: "", // CardListing doesn't have postal code
      houseType: listing.house_type ?? "apartment",
      bedrooms: listing.bedrooms ?? 0,
      utilities: "", // CardListing doesn't have utilities
      description: listing.description,
      media: listing.media, // CardListing.media is already [String]?
      userEmail: "landlord@example.com",
      createdAt: createdAtDate,
      updatedAt: createdAtDate
    )
    
    return AINegotiatorView(
      conversationId: UUID(), // Generate new conversation
      listing: negotiatorListing,
      budget: 1200, // Default budget - can be made configurable
      userEmail: "test-user@example.com" // Stub for now
    )
  }
}