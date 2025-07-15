import Foundation
import SwiftUI

// MARK: - Property Models

struct Property: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let price: Double
    let location: String
    let category: String
    let bedrooms: Int
    let bathrooms: Int
    let imageUrl: String?
    let featured: Bool
    let createdAt: String?
    let userEmail: String?
    
    var formattedPrice: String {
        return "$\(Int(price))/month"
    }
}

// MARK: - User Models

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let displayName: String
    let firstName: String?
    let lastName: String?
    let profileImage: String?
    let createdAt: String?
}

// MARK: - Search Models

struct SearchFilters: Codable {
    var category: String?
    var minPrice: Double?
    var maxPrice: Double?
    var bedrooms: Int?
    var bathrooms: Int?
    var location: String?
    
    init() {
        self.category = nil
        self.minPrice = nil
        self.maxPrice = nil
        self.bedrooms = nil
        self.bathrooms = nil
        self.location = nil
    }
}

struct SearchResult: Identifiable, Codable {
    let id: String
    let properties: [Property]
    let totalCount: Int
    let query: String?
}

// MARK: - Chat Models

struct Conversation: Identifiable, Codable {
    let id: String
    let senderEmail: String
    let receiverEmail: String
    let listing: Property?
    let lastMessageAt: String?
    let createdAt: String
}

struct Message: Identifiable, Codable {
    let id: String
    let conversationId: String
    let senderEmail: String
    let content: String
    let createdAt: String
}

// MARK: - AI Models

struct AISearchResult: Codable {
    let recommendation: String
    let listings: [Property]
    let searchQuery: String
}

// MARK: - Subscription Models

struct SubscriptionStatus: Codable {
    let type: String
    let isActive: Bool
    let isPremium: Bool
    let expiryDate: String?
}

struct SubscriptionPlan: Identifiable, Codable {
    let id: String
    let name: String
    let price: Double
    let originalPrice: Double?
    let interval: String
    let features: [String]
    let isPopular: Bool
}

// MARK: - Negotiation Models

struct NegotiationOffer: Identifiable, Codable {
    let id: String
    let propertyId: String
    let amount: Double
    let message: String
    let status: OfferStatus
    let isFromUser: Bool
    let createdAt: String
}

enum OfferStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
    case countered = "countered"
}

// MARK: - Property Card Views

struct PropertySearchCard: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Property Image
            AsyncImage(url: URL(string: property.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "house")
                            .foregroundColor(.gray)
                    )
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                // Title and Price
                HStack {
                    Text(property.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(property.formattedPrice)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                // Location
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                    Text(property.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Details
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "bed")
                            .foregroundColor(.secondary)
                        Text("\(property.bedrooms)")
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "shower")
                            .foregroundColor(.secondary)
                        Text("\(property.bathrooms)")
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .foregroundColor(.secondary)
                        Text(property.category.capitalized)
                            .font(.subheadline)
                    }
                    
                    Spacer()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PropertyGridCard: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Property Image
            AsyncImage(url: URL(string: property.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "house")
                            .foregroundColor(.gray)
                    )
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(property.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(property.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(property.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}