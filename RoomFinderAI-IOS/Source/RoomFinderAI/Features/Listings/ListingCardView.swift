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
}