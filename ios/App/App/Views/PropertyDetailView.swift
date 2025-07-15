import SwiftUI

struct PropertyDetailView: View {
    let property: Property
    @State private var showingChat = false
    @State private var showingNegotiation = false
    @State private var isFavorited = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Image Gallery
                imageGallery
                
                // Property Info
                propertyInfo
                
                // Description
                descriptionSection
                
                // Features (if available)
                // featuresSection
                
                // Location
                locationSection
                
                // Action Buttons
                actionButtons
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topTrailing) {
            // Close button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding()
        }
        .sheet(isPresented: $showingChat) {
            ChatDetailView(property: property)
        }
        .sheet(isPresented: $showingNegotiation) {
            NegotiationView(property: property)
        }
    }
    
    // MARK: - Image Gallery
    
    private var imageGallery: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: URL(string: property.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            .frame(height: 300)
            .clipped()
            
            // Favorite Button
            Button(action: {
                toggleFavorite()
            }) {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(isFavorited ? .red : .white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding()
        }
    }
    
    // MARK: - Property Info
    
    private var propertyInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and Price
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(property.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(property.location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(property.formattedPrice)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    if property.featured == true {
                        Text("FEATURED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Property Details
            HStack(spacing: 24) {
                if let bedrooms = property.bedrooms {
                    DetailItem(icon: "bed.double", value: "\(bedrooms)", label: bedrooms == 1 ? "Bedroom" : "Bedrooms")
                }
                
                if let bathrooms = property.bathrooms {
                    DetailItem(icon: "bathtub", value: "\(bathrooms)", label: bathrooms == 1 ? "Bathroom" : "Bathrooms")
                }
                
                DetailItem(icon: property.categoryIcon, value: property.category.capitalized, label: "Type")
            }
        }
        .padding()
    }
    
    // MARK: - Description
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(property.description)
                .font(.body)
                .lineSpacing(4)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Location
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: "location.circle")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text(property.location)
                    .font(.body)
                
                Spacer()
                
                Button("View on Map") {
                    // Open in Maps app or show map view
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Contact Button
                Button(action: {
                    showingChat = true
                }) {
                    HStack {
                        Image(systemName: "message")
                        Text("Contact")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // AI Negotiation Button
                Button(action: {
                    showingNegotiation = true
                }) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text("AI Negotiate")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Schedule Visit Button
            Button(action: {
                // Schedule visit functionality
            }) {
                HStack {
                    Image(systemName: "calendar")
                    Text("Schedule Visit")
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func toggleFavorite() {
        // Call your existing favorite toggle function
        Task {
            do {
                let result = try await WebBridge.shared.callWebFunction(
                    "iosListingsAPI.toggleFavorite",
                    with: ["listingId": property.id]
                )
                
                if let favoriteResult = result as? [String: Any],
                   let favorited = favoriteResult["data"] as? [String: Any],
                   let isFav = favorited["favorited"] as? Bool {
                    await MainActor.run {
                        self.isFavorited = isFav
                    }
                }
            } catch {
                print("Error toggling favorite: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct DetailItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PropertyDetailView(property: Property(
        id: "1",
        title: "Beautiful 2BR Apartment",
        description: "A stunning 2-bedroom apartment in the heart of downtown with modern amenities and beautiful city views.",
        price: 2500,
        location: "Downtown, San Francisco",
        category: "apartment",
        bedrooms: 2,
        bathrooms: 2,
        imageUrl: nil,
        featured: true,
        createdAt: nil,
        userEmail: nil
    ))
}