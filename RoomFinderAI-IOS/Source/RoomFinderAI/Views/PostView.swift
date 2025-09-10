import SwiftUI

struct PostView: View {
    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var location = ""
    @State private var propertyType = "Apartment"
    @State private var bedrooms = 1
    @State private var selectedAmenities: Set<String> = []
    @State private var showingImagePicker = false
    @State private var showingSuccessAlert = false
    
    let propertyTypes = ["Apartment", "House", "Studio", "Condo", "Townhouse"]
    let amenities = ["WiFi", "Parking", "Laundry", "Gym", "Pool", "Balcony", "Air Conditioning", "Dishwasher", "Pet-Friendly", "Furnished"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Post Your Property")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("List your room or property for rent")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    VStack(spacing: 16) {
                        // Basic Information
                        Group {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Property Title *")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                TextField("e.g., Spacious 1BR near campus", text: $title)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Location *")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                TextField("City, neighborhood, or address", text: $location)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Monthly Rent *")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                HStack {
                                    Text("$")
                                        .foregroundColor(.secondary)
                                    TextField("1200", text: $price)
                                        .keyboardType(.numberPad)
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        // Property Details
                        Group {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Property Type")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                Picker("Property Type", selection: $propertyType) {
                                    ForEach(propertyTypes, id: \.self) { type in
                                        Text(type).tag(type)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bedrooms")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                HStack {
                                    Button("-") {
                                        if bedrooms > 0 { bedrooms -= 1 }
                                    }
                                    .frame(width: 40, height: 40)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                    
                                    Text("\(bedrooms)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .frame(minWidth: 50)
                                    
                                    Button("+") {
                                        if bedrooms < 10 { bedrooms += 1 }
                                    }
                                    .frame(width: 40, height: 40)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                    
                                    Spacer()
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                TextField("Describe your property, location, amenities...", text: $description, axis: .vertical)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(4...8)
                            }
                        }
                        
                        // Photos Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                    Text("Add Photos")
                                        .fontWeight(.semibold)
                                    Text("Upload up to 10 photos")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                                )
                            }
                        }
                        
                        // Amenities
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Amenities")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(amenities, id: \.self) { amenity in
                                    AmenityChip(
                                        title: amenity,
                                        isSelected: selectedAmenities.contains(amenity)
                                    ) {
                                        if selectedAmenities.contains(amenity) {
                                            selectedAmenities.remove(amenity)
                                        } else {
                                            selectedAmenities.insert(amenity)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Submit Button
                        VStack(spacing: 12) {
                            Button(action: {
                                // TODO: Implement post submission
                                showingSuccessAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                    Text("Post Property")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.green, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .disabled(title.isEmpty || location.isEmpty || price.isEmpty)
                            .opacity(title.isEmpty || location.isEmpty || price.isEmpty ? 0.6 : 1.0)
                            
                            Button("Save as Draft") {
                                // TODO: Save as draft
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Post Property")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerPlaceholder()
        }
        .alert("Success!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                // Clear form
                clearForm()
            }
        } message: {
            Text("Your property has been posted successfully!")
        }
    }
    
    private func clearForm() {
        title = ""
        description = ""
        price = ""
        location = ""
        propertyType = "Apartment"
        bedrooms = 1
        selectedAmenities.removeAll()
    }
}

struct AmenityChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
            }
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : .green)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.green : Color.green.opacity(0.1))
            .cornerRadius(20)
        }
    }
}

struct ImagePickerPlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "camera")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("Photo Upload")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Camera and photo library integration coming soon!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Done") {
                    dismiss()
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Add Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PostView()
}