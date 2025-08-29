import SwiftUI

struct PropertyDetailView: View {
    let listing: RoomListing
    @State private var showingContact = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image gallery placeholder
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 300)
                    .overlay(
                        Image(systemName: "house")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    )
                
                VStack(alignment: .leading, spacing: 15) {
                    // Title and price
                    VStack(alignment: .leading, spacing: 8) {
                        Text(listing.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text("$\(Int(listing.price))/month")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                // TODO: Add to favorites
                            }) {
                                Image(systemName: "heart")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.secondary)
                            Text(listing.location)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(listing.description)
                            .font(.body)
                    }
                    
                    Divider()
                    
                    // Amenities
                    if !listing.amenities.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Amenities")
                                .font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], alignment: .leading, spacing: 8) {
                                ForEach(listing.amenities, id: \.self) { amenity in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text(amenity)
                                            .font(.body)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Contact section
                    VStack(spacing: 12) {
                        Button(action: {
                            showingContact = true
                        }) {
                            Text("Contact Property Owner")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            // TODO: Schedule viewing
                        }) {
                            Text("Schedule Viewing")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingContact) {
            ContactView(listing: listing)
        }
    }
}

struct ContactView: View {
    let listing: RoomListing
    @Environment(\.presentationMode) var presentationMode
    @State private var message = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Contact about \(listing.title)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                TextEditor(text: $message)
                    .frame(minHeight: 150)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                Button(action: {
                    // TODO: Send message
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Send Message")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Contact")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            message = "Hi, I'm interested in your room listing: \(listing.title). Could you please provide more information?"
        }
    }
}

#Preview {
    PropertyDetailView(listing: RoomListing(
        id: "1",
        title: "Cozy Studio in Downtown",
        description: "Perfect for students and young professionals. Recently renovated with modern amenities.",
        price: 1200,
        location: "Downtown",
        amenities: ["WiFi", "Laundry", "Kitchen", "Parking"]
    ))
}