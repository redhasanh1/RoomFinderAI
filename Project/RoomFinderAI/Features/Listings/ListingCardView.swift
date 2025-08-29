import SwiftUI

struct ListingCardView: View {
  let listing: Listing

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      AsyncImage(url: URL(string: listing.coverURLString ?? "")) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .overlay {
            Image(systemName: "photo")
              .font(.system(size: 32))
              .foregroundColor(.gray)
          }
      }
      .frame(height: 200)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(listing.title ?? "Listing")
            .font(.headline)
            .fontWeight(.semibold)
          Spacer()
          if let price = listing.price {
            Text("$\(price)")
              .font(.title2)
              .fontWeight(.bold)
              .foregroundColor(.primary)
          }
        }
        
        HStack {
          if let city = listing.city {
            Label(city, systemImage: "location")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          Spacer()
          if let bedrooms = listing.bedrooms {
            Text("\(bedrooms) bed")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        
        if let description = listing.description {
          Text(description)
            .font(.body)
            .foregroundColor(.secondary)
            .lineLimit(2)
        }
      }
      .padding(.horizontal, 4)
    }
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
  }
}