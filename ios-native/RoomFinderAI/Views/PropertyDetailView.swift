import SwiftUI
import MapKit

struct PropertyDetailView: View {
    let listing: Listing
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listingsViewModel: ListingsViewModel
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var showingContactSheet = false
    @State private var showingImageViewer = false
    @State private var selectedImageIndex = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Image Gallery
                    TabView(selection: $selectedImageIndex) {
                        ForEach(0..<listing.images.count, id: \.self) { index in
                            AsyncImage(url: URL(string: listing.images[index])) { image in
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
                                Image(systemName: listing.isFavorited ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(listing.isFavorited ? .red : .white)
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
                            Text(listing.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(listing.price.currencyFormatted())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryBlue)
                            
                            Text(listing.location.fullAddress)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Key Details
                        HStack(spacing: 20) {
                            DetailItem(icon: "bed.double", text: "\(listing.bedrooms) Bed")
                            DetailItem(icon: "drop", text: "\(listing.bathrooms) Bath")
                            if let sqft = listing.squareFootage {
                                DetailItem(icon: "square.grid.3x3", text: "\(Int(sqft)) sq ft")
                            }
                        }
                        
                        // Description
                        Text(listing.description)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        // Amenities
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Amenities")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(listing.amenities, id: \.self) { amenity in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text(amenity)
                                            .font(.subheadline)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        // Utilities
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Utilities Included")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                UtilityItem(name: "Electricity", included: listing.utilities.electricity)
                                UtilityItem(name: "Water", included: listing.utilities.water)
                                UtilityItem(name: "Gas", included: listing.utilities.gas)
                                UtilityItem(name: "Internet", included: listing.utilities.internet)
                                UtilityItem(name: "Cable", included: listing.utilities.cable)
                                UtilityItem(name: "Heating", included: listing.utilities.heating)
                            }
                        }
                        
                        // Policies
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Policies")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                PolicyItem(title: "Pet Policy", value: listing.petPolicy.displayName)
                                PolicyItem(title: "Smoking Policy", value: listing.smokingPolicy.displayName)
                                PolicyItem(title: "Lease Term", value: "\(listing.leaseTerm) months")
                            }
                        }
                        
                        // Map
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Map(coordinateRegion: .constant(MKCoordinateRegion(
                                center: listing.location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )), annotationItems: [listing]) { listing in
                                MapPin(coordinate: listing.location.coordinate, tint: .primaryBlue)
                            }
                            .frame(height: 200)
                            .cornerRadius(12)
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
                                    Text(listing.contactInfo.name)
                                        .font(.subheadline)
                                }
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.secondary)
                                    Text(listing.contactInfo.email)
                                        .font(.subheadline)
                                }
                                
                                if let phone = listing.contactInfo.phone {
                                    HStack {
                                        Image(systemName: "phone")
                                            .foregroundColor(.secondary)
                                        Text(phone)
                                            .font(.subheadline)
                                    }
                                }
                                
                                if let responseTime = listing.contactInfo.responseTime {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.secondary)
                                        Text("Usually responds in \(responseTime)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
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
                    
                    // Contact Button
                    Button(action: {
                        showingContactSheet = true
                    }) {
                        Text("Contact Landlord")
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
                    .padding()
                    .background(Color(.systemBackground))
                },
                alignment: .bottom
            )
        }
        .sheet(isPresented: $showingContactSheet) {
            ContactSheet(listing: listing)
        }
        .fullScreenCover(isPresented: $showingImageViewer) {
            ImageViewer(images: listing.images, selectedIndex: $selectedImageIndex)
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
    @EnvironmentObject var chatViewModel: ChatViewModel
    @State private var message = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    AsyncImage(url: URL(string: listing.images.first ?? "")) { image in
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
                        Text(listing.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(listing.contactInfo.name)
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
                    // Create new chat or send message
                    chatViewModel.createNewChat(with: [listing.landlordId], listingId: listing.id)
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
                ForEach(0..<images.count, id: \.self) { index in
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

#Preview {
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
    .environmentObject(ListingsViewModel())
    .environmentObject(ChatViewModel())
}