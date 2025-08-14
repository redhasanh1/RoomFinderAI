import SwiftUI
import Foundation
import UIKit

struct PropertyDetailView: View {
    let listing: Listing
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listingsViewModel: SimpleListingsViewModel
    @State private var showingContactSheet = false
    @State private var showingImageViewer = false
    @State private var selectedImageIndex = 0
    @State private var showingAINegotiator = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    // Image Gallery
                    TabView(selection: $selectedImageIndex) {
                        if let images = listing.images {
                            ForEach(0..<images.count) { index in
                                AsyncImage(url: URL(string: images[index])) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
                            .frame(height: 300)
                            .clipShape(Rectangle())
                            .tag(index)
                            .onTapGesture {
                                showingImageViewer = true
                            }
                            }
                        }
                    }
                    .tabViewStyle(PageTabViewStyle())
                    .frame(height: 300)
                    .overlay(
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                listingsViewModel.toggleFavorite(listing: listing)
                            }) {
                                Image(systemName: (listing.isFavorited ?? false) ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor((listing.isFavorited ?? false) ? .red : .white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(),
                        alignment: .topLeading
                    )
                    
                    // Property Details
                    VStack(alignment: .leading, spacing: 20) {
                        // Title and Price
                        VStack(alignment: .leading, spacing: 8) {
                            Text(listing.title ?? "Unknown")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("$\(listing.price ?? 0)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryBlue)
                            
                            Text("\(listing.street ?? ""), \(listing.city ?? "")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Key Details
                        HStack(spacing: 20) {
                            DetailItem(icon: "bed.double", text: "\(listing.bedrooms ?? 0) Bed")
                        }
                        
                        // Description
                        Text(listing.description ?? "")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        // Amenities section removed - no amenities in Listing model
                        
                        // Utilities
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Utilities")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(listing.utilities ?? "Not specified")
                                .font(.body)
                        }
                        
                        // Policies section removed - no policies in Listing model
                        
                        // Map - Temporarily disabled
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(listing.city ?? "Location not available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    Text("Map view temporarily disabled")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                )
                        }
                        
                        // Contact Info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Contact Information")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "person.circle")
                                        .foregroundColor(.secondary)
                                    Text(listing.userEmail ?? "Unknown")
                                        .font(.subheadline)
                                }
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.secondary)
                                    Text(listing.userEmail ?? "Unknown")
                                        .font(.subheadline)
                                }
                                
                                
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .overlay(
                VStack {
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // AI Negotiator Button
                        Button(action: {
                            showingAINegotiator = true
                        }) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .font(.title3)
                                Text("AI Negotiator")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.accentGreen, .primaryBlue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        
                        // Contact Button
                        Button(action: {
                            showingContactSheet = true
                        }) {
                            HStack {
                                Image(systemName: "envelope")
                                    .font(.title3)
                                Text("Contact Landlord")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.primaryBlue, .secondaryPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                },
                alignment: .bottom
            )
        }
        .sheet(isPresented: $showingContactSheet) {
            ContactSheet(listing: listing)
        }
        .sheet(isPresented: $showingAINegotiator) {
            AINegotiatorSheet(listing: listing)
        }
        .fullScreenCover(isPresented: $showingImageViewer) {
            ImageViewer(images: listing.images ?? [], selectedIndex: $selectedImageIndex)
        }
    }
}

struct DetailItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct UtilityItem: View {
    let name: String
    let included: Bool
    
    var body: some View {
        HStack {
            Image(systemName: included ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(included ? .green : .red)
            Text(name)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct PolicyItem: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct ContactSheet: View {
    let listing: Listing
    @Environment(\.dismiss) private var dismiss
    // Chat functionality removed for simplified app
    @State private var message = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    AsyncImage(url: URL(string: listing.images?.first ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(spacing: 4) {
                        Text(listing.title ?? "Unknown")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(listing.userEmail ?? "Unknown")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Message Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextEditor(text: $message)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Quick Messages
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Messages")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 8) {
                        QuickMessageButton(text: "I'm interested in this property") {
                            message = "Hi! I'm interested in your property listing for \(listing.title). Could you please provide more details?"
                        }
                        
                        QuickMessageButton(text: "Schedule a viewing") {
                            message = "Hi! I'd like to schedule a viewing for \(listing.title). When would be a good time?"
                        }
                        
                        QuickMessageButton(text: "Ask about pricing") {
                            message = "Hi! I'm interested in \(listing.title). Is there any flexibility with the pricing?"
                        }
                    }
                }
                
                Spacer()
                
                // Send Button
                Button(action: {
                    // Contact landlord - Coming soon
                    dismiss()
                }) {
                    Text("Send Message")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.primaryBlue, .secondaryPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .disabled(message.isEmpty)
                .opacity(message.isEmpty ? 0.6 : 1.0)
            }
            .padding()
            .navigationTitle("Contact")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}

struct QuickMessageButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primaryBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.primaryBlue.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct ImageViewer: View {
    let images: [String]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(0..<images.count) { index in
                    AsyncImage(url: URL(string: images[index])) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("\(selectedIndex + 1) / \(images.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(16)
                }
                .padding()
                
                Spacer()
            }
        }
    }
}

struct AINegotiatorSheet: View {
    let listing: Listing
    @Environment(\.dismiss) private var dismiss
    @State private var initialOffer = ""
    @State private var isNegotiating = false
    @State private var userEmail = "user@example.com" // In real app, get from auth
    @State private var negotiationResult: NegotiationResult?
    
    // Simple AI service for demo
    private let aiService = SimpleAIService()
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.primaryBlue)
                        
                        Text("AI Negotiator")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Let AI help you negotiate the best price for this property")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Property Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Property Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            AsyncImage(url: URL(string: listing.images?.first ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(listing.title ?? "Unknown")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Listed at $\(listing.price ?? 0)")
                                    .font(.subheadline)
                                    .foregroundColor(.primaryBlue)
                                    .fontWeight(.medium)
                                
                                Text(listing.city ?? "Unknown")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Offer Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Offer")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter your initial offer amount:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter offer amount", text: $initialOffer)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Start Negotiation Button
                    Button(action: {
                        startNegotiation()
                    }) {
                        HStack {
                            if isNegotiating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "brain.head.profile")
                                    .font(.title3)
                                Text("Start AI Negotiation")
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.accentGreen, .primaryBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .disabled(initialOffer.isEmpty || isNegotiating)
                    .opacity(initialOffer.isEmpty || isNegotiating ? 0.6 : 1.0)
                    
                    // Negotiation Result
                    if let result = negotiationResult {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("AI Negotiation Result")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ResultRow(title: "Recommended Counter-Offer", value: "$\(result.recommendedPrice)")
                                ResultRow(title: "Success Probability", value: "\(result.successProbability)%")
                                ResultRow(title: "Market Comparison", value: result.marketComparison)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            Text("AI Analysis:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(result.analysis)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.accentGreen.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("AI Negotiator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startNegotiation() {
        guard let offerAmount = Double(initialOffer) else { return }
        
        isNegotiating = true
        
        Task {
            do {
                let result = try await aiService.startNegotiation(
                    listing: listing,
                    initialOffer: offerAmount,
                    userEmail: userEmail
                )
                
                await MainActor.run {
                    negotiationResult = result
                    isNegotiating = false
                }
            } catch {
                await MainActor.run {
                    isNegotiating = false
                }
            }
        }
    }
}


// Simple models for AI negotiation demo
struct NegotiationResult {
    let recommendedPrice: Int
    let successProbability: Int
    let marketComparison: String
    let analysis: String
}

// Simple AI service for demo
class SimpleAIService {
    func startNegotiation(listing: Listing, initialOffer: Double, userEmail: String) async throws -> NegotiationResult {
        // Simulate AI processing
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Generate mock negotiation result
        let difference = (listing.price ?? 0) - initialOffer
        let recommendedPrice = Int(initialOffer + (difference / 2)) // Split the difference
        let successProbability = Int(difference) < 200 ? 85 : Int(difference) < 500 ? 65 : 45
        
        return NegotiationResult(
            recommendedPrice: recommendedPrice,
            successProbability: successProbability,
            marketComparison: recommendedPrice < Int(listing.price ?? 0) ? "Below market average" : "At market rate",
            analysis: "Based on similar properties in the area, a counter-offer of $\(recommendedPrice) has a \(successProbability)% chance of acceptance."
        )
    }
}


/*#Preview {
    PropertyDetailView(listing: Listing(
        id: "1",
        title: "Modern Studio Apartment",
        description: "Beautiful modern studio in downtown",
        price: 1200,
        location: Location(
            address: "123 Main St",
            city: "New York",
            state: "NY",
            zipCode: "10001",
            country: "USA",
            latitude: 40.7128,
            longitude: -74.0060,
            neighborhood: "Downtown"
        ),
        bedrooms: 0,
        bathrooms: 1,
        squareFootage: 500,
        propertyType: .studio,
        amenities: ["WiFi", "Gym", "Pool"],
        images: [],
        availableDate: Date(),
        leaseTerm: 12,
        petPolicy: .notAllowed,
        smokingPolicy: .notAllowed,
        utilities: UtilitiesInfo(
            electricity: true,
            water: true,
            gas: false,
            internet: true,
            cable: false,
            heating: true,
            airConditioning: true,
            trash: true,
            sewer: true,
            additionalCosts: 0
        ),
        contactInfo: ContactInfo(
            name: "John Doe",
            email: "john@example.com",
            phone: "555-0123",
            preferredContact: .email,
            responseTime: "24 hours"
        ),
        landlordId: "landlord1",
        status: .active,
        features: [],
        createdAt: Date(),
        updatedAt: Date(),
        viewCount: 0,
        favoriteCount: 0,
        isFavorited: false
    ))
    .environmentObject(SimpleListingsViewModel())
}*/
