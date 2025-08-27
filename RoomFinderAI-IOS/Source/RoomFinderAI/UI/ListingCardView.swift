import SwiftUI

struct ListingCardView: View {
  let listing: Listing
  @State private var imageURL: URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: UI.cardRadius).fill(Color.gray.opacity(0.12))
        if let imageURL {
          AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty: ProgressView()
            case .success(let img):
              img
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            case .failure: placeholder
            @unknown default: placeholder
            }
          }
        } else { placeholder }
      }
      .frame(height: 180)
      .clipShape(RoundedRectangle(cornerRadius: UI.cardRadius))

      Text(listing.title ?? "Untitled")
        .font(.headline)
        .lineLimit(2)

      HStack(spacing: 8) {
        if let p = listing.price { Text("$\(Int(p))").fontWeight(.semibold) }
        if let t = listing.houseType { Text("· \(t)") }
        if let b = listing.bedrooms { Text("· \(b) bd") }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)

      Button {
        // handled by parent via NavigationLink; keep button-only style
      } label: {
        Label("Negotiate", systemImage: "brain.head.profile")
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(UI.vPad)
    .cardBackground()
    .task {
      if let mediaArray = listing.media, let firstMedia = mediaArray.first, 
         let u = URL(string: firstMedia), firstMedia.lowercased().hasPrefix("http") {
        imageURL = u
      }
    }
  }

  private var placeholder: some View {
    VStack(spacing: 6) {
      Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
      Text("No image").font(.caption).foregroundStyle(.secondary)
    }
  }
}