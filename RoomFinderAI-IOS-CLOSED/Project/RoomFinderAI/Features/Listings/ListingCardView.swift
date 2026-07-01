import SwiftUI

struct ListingCardView: View {
  let listing: Listing
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      AsyncImage(url: URL(string: listing.coverURLString ?? "")) { image in
        image.resizable().aspectRatio(contentMode: .fill)
      } placeholder: {
        Rectangle().fill(Color(.systemGray5))
          .overlay(Image(systemName: "house").font(.largeTitle).foregroundColor(.secondary))
      }
      .frame(height: 180)
      .clipped()
      .cornerRadius(12)
      
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(listing.title ?? "Untitled")
            .font(.headline)
            .lineLimit(1)
          Spacer()
          if let price = listing.price {
            Text("$\(price)")
              .font(.title2)
              .fontWeight(.semibold)
              .foregroundColor(.green)
          }
        }
        
        HStack {
          if let city = listing.city {
            Text(city)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
          Spacer()
          if let bedrooms = listing.bedrooms {
            Text("\(bedrooms) bed")
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.blue.opacity(0.1))
              .foregroundColor(.blue)
              .cornerRadius(8)
          }
        }
        
        if let description = listing.description {
          Text(description)
            .font(.caption)
            .lineLimit(2)
            .foregroundColor(.secondary)
        }
      }
      .padding(.horizontal)
      .padding(.bottom)
    }
    .background(Color(.systemBackground))
    .cornerRadius(15)
    .shadow(radius: 2)
  }
}