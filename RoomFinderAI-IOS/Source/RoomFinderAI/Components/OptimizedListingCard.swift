import SwiftUI

// MARK: - Property Type Info
struct PropertyTypeInfo {
    let iconName: String
    let displayName: String
}

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
            // Show either image or themed default
            if let urlString = listing.coverURLString, !urlString.isEmpty,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    case .failure(_):
                        getDefaultImageView()
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
            } else {
                // No image URL available - show themed default
                getDefaultImageView()
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
    
    // MARK: - Property Type Helper
    private func getDefaultImageView() -> some View {
        let propertyType = determinePropertyType()
        
        return ZStack {
            // Purple gradient background matching RoomFinderAI theme
            LinearGradient(
                colors: [
                    Color(red: 0.6, green: 0.4, blue: 0.8),  // Light purple
                    Color(red: 0.4, green: 0.2, blue: 0.7)   // Darker purple
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)
            
            VStack(spacing: 8) {
                // Property type specific icon
                Image(systemName: propertyType.iconName)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white)
                
                Text(propertyType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .clipped()
    }
    
    private func determinePropertyType() -> PropertyTypeInfo {
        let houseType = listing.house_type?.lowercased() ?? ""
        
        switch houseType {
        case let type where type.contains("apartment") || type.contains("studio") || type.contains("condo"):
            return PropertyTypeInfo(iconName: "building.2.fill", displayName: "Apartment")
        case let type where type.contains("house") || type.contains("townhouse"):
            return PropertyTypeInfo(iconName: "house.fill", displayName: "House")
        default:
            return PropertyTypeInfo(iconName: "building.fill", displayName: "Property")
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
                Color(red: 0.85, green: 0.80, blue: 0.95),  // Light purple-tinted gray
                Color(red: 0.75, green: 0.65, blue: 0.85).opacity(isAnimating ? 0.4 : 1.0),  // Medium purple-tinted gray
                Color(red: 0.85, green: 0.80, blue: 0.95)   // Light purple-tinted gray
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