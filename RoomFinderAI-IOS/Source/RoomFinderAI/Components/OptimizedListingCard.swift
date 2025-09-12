import SwiftUI

// MARK: - Optimized Listing Card with Performance Improvements
struct OptimizedListingCard: View {
    let listing: HomePageListing
    @State private var isImageLoaded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Optimized Image with Lazy Loading
            imageSection
            
            // Content Section
            contentSection
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .onTapGesture {
            // Handle tap - navigate to detail view
            // This would trigger navigation to property detail
        }
    }
    
    // MARK: - Image Section
    private var imageSection: some View {
        ZStack {
            // Placeholder while loading
            if !isImageLoaded {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
            
            // Actual Image with Lazy Loading
            AsyncImage(url: URL(string: listing.coverURLString ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isImageLoaded = true
                            }
                        }
                case .failure(_):
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "photo.badge.exclamationmark")
                                .foregroundColor(.gray)
                                .font(.title3)
                        )
                case .empty:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                @unknown default:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                }
            }
            
            // Price Badge Overlay
            VStack {
                HStack {
                    Spacer()
                    Text(listing.displayPrice)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.7))
                        .cornerRadius(6)
                        .padding(.trailing, 8)
                        .padding(.top, 8)
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title and Location
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.displayTitle)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(listing.displayLocation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Property Features
            HStack(spacing: 8) {
                // Bedrooms
                HStack(spacing: 2) {
                    Image(systemName: "bed.double.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(listing.displayBedrooms)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                
                // Property Type
                if let houseType = listing.house_type {
                    HStack(spacing: 2) {
                        Image(systemName: "house.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(houseType.capitalized)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Skeleton Loading Card
struct SkeletonListingCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Skeleton Image
            Rectangle()
                .fill(shimmerGradient)
                .frame(height: 120)
            
            // Skeleton Content
            VStack(alignment: .leading, spacing: 6) {
                // Title skeleton
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 16)
                    .cornerRadius(4)
                
                // Location skeleton
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(width: 80, height: 12)
                    .cornerRadius(4)
                
                // Features skeleton
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(shimmerGradient)
                        .frame(width: 50, height: 12)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(shimmerGradient)
                        .frame(width: 60, height: 12)
                        .cornerRadius(4)
                    
                    Spacer()
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemGray5),
                Color(.systemGray4).opacity(isAnimating ? 0.3 : 1.0),
                Color(.systemGray5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Performance-Optimized Filter Chip
struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 0.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 20) {
        // Preview Optimized Card
        OptimizedListingCard(listing: HomePageListing(
            id: UUID(),
            title: "Beautiful 2BR Apartment",
            price: 1500,
            city: "Toronto",
            house_type: "Apartment",
            bedrooms: 2,
            description: "Spacious apartment in downtown",
            created_at: "2024-01-01",
            media: []
        ))
        
        // Preview Skeleton Card
        SkeletonListingCard()
    }
    .padding()
}