import SwiftUI
import Supabase

// MARK: - AI Negotiator Demo View
struct AINegotiatorDemoView: View {
    @Environment(\.supabase) private var supabase
    @State private var selectedListing: NegotiationListing?
    @State private var budget: String = "1500"
    @State private var showingNegotiator = false
    
    // Sample listings for testing
    private let sampleListings = [
        NegotiationListing(
            id: UUID(),
            title: "Modern 1BR Apartment in Downtown",
            price: 1800,
            city: "New York",
            bedrooms: 1,
            houseType: "apartment",
            description: "Beautiful modern apartment with city views",
            media: [MediaItem(url: "https://example.com/image1.jpg")],
            createdAt: "2024-01-15T10:30:00Z"
        ),
        NegotiationListing(
            id: UUID(),
            title: "Cozy 2BR House with Garden",
            price: 2200,
            city: "San Francisco",
            bedrooms: 2,
            houseType: "house",
            description: "Charming house with private garden",
            media: [MediaItem(url: "https://example.com/image2.jpg")],
            createdAt: "2024-01-14T15:45:00Z"
        ),
        NegotiationListing(
            id: UUID(),
            title: "Studio Apartment Near Campus",
            price: 1200,
            city: "Boston",
            bedrooms: 0,
            houseType: "studio",
            description: "Perfect for students, walking distance to campus",
            media: nil,
            createdAt: "2024-01-13T09:20:00Z"
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Negotiator Demo")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Test the AI Negotiation Assistant with sample listings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Budget Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Budget")
                        .font(.headline)
                    
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        TextField("1500", text: $budget)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    
                    Text("This will be used for market analysis and negotiation strategy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Sample Listings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sample Listings")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sampleListings) { listing in
                                DemoListingCard(
                                    listing: listing,
                                    isSelected: selectedListing?.id == listing.id
                                ) {
                                    selectedListing = listing
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Start Button
                Button {
                    showingNegotiator = true
                } label: {
                    Text("Start AI Negotiation")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            selectedListing != nil ? Color.blue : Color.gray,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .disabled(selectedListing == nil)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Demo")
        .fullScreenCover(isPresented: $showingNegotiator) {
            if let listing = selectedListing {
                DemoNegotiatorWrapper(
                    listing: listing,
                    budget: Double(budget),
                    onDismiss: {
                        showingNegotiator = false
                    }
                )
            }
        }
    }
}

// MARK: - Demo Listing Card
struct DemoListingCard: View {
    let listing: NegotiationListing
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.displayTitle)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        
                        Text(listing.displayLocation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(listing.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                // Details
                HStack {
                    if let bedrooms = listing.bedrooms {
                        Label("\(bedrooms) bed", systemImage: "bed.double")
                    }
                    
                    if let houseType = listing.houseType {
                        Label(houseType.capitalized, systemImage: "house")
                    }
                    
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Description
                if let description = listing.description {
                    Text(description)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Selection indicator
                HStack {
                    if isSelected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Selected for negotiation")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("Tap to select this listing")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.green : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Demo Negotiator Wrapper
struct DemoNegotiatorWrapper: View {
    let listing: NegotiationListing
    let budget: Double?
    let onDismiss: () -> Void
    
    @Environment(\.supabase) private var supabase
    @StateObject private var viewModel: AINegotiatorViewModel
    @State private var conversationId = UUID()
    @State private var hasStarted = false
    
    init(listing: NegotiationListing, budget: Double?, onDismiss: @escaping () -> Void) {
        self.listing = listing
        self.budget = budget
        self.onDismiss = onDismiss
        
        // Initialize with mock supabase - in production this would come from environment
        let mockSupabase = SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "mock-key"
        )
        self._viewModel = StateObject(wrappedValue: AINegotiatorViewModel(supabase: mockSupabase))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if !hasStarted {
                    // Configuration screen
                    configurationView
                } else {
                    // Negotiator interface
                    AINegotiatorView(supabase: supabase)
                }
            }
            .navigationTitle("Demo Negotiation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var configurationView: some View {
        VStack(spacing: 24) {
            // Demo Notice
            VStack(spacing: 16) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Demo Mode")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("This is a demonstration of the AI Negotiation Assistant. In demo mode, actual API calls are simulated.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Selected Listing
            VStack(alignment: .leading, spacing: 12) {
                Text("Selected Listing")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(listing.displayTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text(listing.displayPrice)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(listing.displayLocation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let description = listing.description {
                        Text(description)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Budget
            if let budget = budget {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Budget")
                        .font(.headline)
                    
                    Text("$\(Int(budget))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Start Button
            Button {
                startDemo()
            } label: {
                Text("Start Demo Negotiation")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func startDemo() {
        hasStarted = true
        
        // In a real implementation, this would start the actual negotiation
        Task {
            await viewModel.start(
                conversationId: conversationId,
                listing: listing,
                budget: budget,
                userEmail: "demo@roomfinderai.com"
            )
        }
    }
}

// MARK: - Unit Tests Helper
extension AINegotiatorDemoView {
    static func createTestListing() -> NegotiationListing {
        return NegotiationListing(
            id: UUID(),
            title: "Test Apartment",
            price: 1500,
            city: "Test City",
            bedrooms: 1,
            houseType: "apartment",
            description: "Test description",
            media: nil,
            createdAt: "2024-01-15T10:30:00Z"
        )
    }
}

// MARK: - Preview
struct AINegotiatorDemoView_Previews: PreviewProvider {
    static var previews: some View {
        AINegotiatorDemoView()
            .environment(\.supabase, SupabaseClient(
                supabaseURL: URL(string: "https://example.supabase.co")!,
                supabaseKey: "mock-key"
            ))
            .previewDisplayName("AI Negotiator Demo")
    }
}