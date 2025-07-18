import SwiftUI
// StatCard is now in SharedComponents

struct SubleaseView: View {
    @EnvironmentObject var listingsViewModel: ListingsViewModel
    @State private var selectedTimeframe: SubleaseTimeframe = .summer
    @State private var showingCreateSublease = false
    @State private var showingFilters = false
    
    var subleaseListings: [Listing] {
        return listingsViewModel.listings.filter { $0.houseType == "sublease" }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with timeframe selector
                VStack(spacing: 16) {
                    HStack {
                        Text("Sublease Marketplace")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            showingCreateSublease = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.primaryBlue)
                        }
                    }
                    
                    // Timeframe selector
                    HStack {
                        ForEach(SubleaseTimeframe.allCases, id: \.self) { timeframe in
                            Button(action: {
                                selectedTimeframe = timeframe
                            }) {
                                VStack(spacing: 4) {
                                    Text(timeframe.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(timeframe.dateRange)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTimeframe == timeframe ? Color.primaryBlue : Color.gray.opacity(0.1))
                                .foregroundColor(selectedTimeframe == timeframe ? .white : .primary)
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Quick stats
                    HStack {
                        StatCard(title: "Available", value: "\(subleaseListings.count)")
                        StatCard(title: "Avg Price", value: "$\(averageSubleasePrice)")
                        StatCard(title: "Success Rate", value: "87%")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Search and filters
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search subleases...", text: $listingsViewModel.searchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Button(action: {
                        showingFilters = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundColor(.primaryBlue)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Sublease listings
                if subleaseListings.isEmpty {
                    Spacer()
                    EmptySubleaseView()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(subleaseListings) { listing in
                                SubleaseCard(listing: listing)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreateSublease) {
                CreateSubleaseView()
            }
            .sheet(isPresented: $showingFilters) {
                SubleaseFiltersView(selectedTimeframe: $selectedTimeframe)
            }
        }
    }
    
    private var averageSubleasePrice: Int {
        guard !subleaseListings.isEmpty else { return 0 }
        return subleaseListings.map { $0.price }.reduce(0, +) / subleaseListings.count
    }
}

struct SubleaseCard: View {
    let listing: Listing
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Image with urgency badge
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: URL(string: listing.images.first ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Urgency badge
                    HStack {
                        Image(systemName: "clock.fill")
                        Text("Urgent")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(8)
                    .padding(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title and price
                    HStack {
                        Text(listing.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("$\(listing.price)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryBlue)
                            
                            Text("/month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Sublease period
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                        
                        Text(getSubleaseTimeframe(listing))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Bedrooms
                        HStack {
                            Image(systemName: "bed.double")
                            Text("\(listing.bedrooms)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Location
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                        
                        Text(listing.location.city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Sublease type
                        Text(getSubleaseType(listing))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                    
                    // Key features
                    HStack {
                        Text("• \(listing.utilities)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Posted \(listing.createdAt.timeAgoDisplay())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            SubleaseDetailView(listing: listing)
        }
    }
    
    private func getSubleaseTimeframe(_ listing: Listing) -> String {
        // Mock timeframe based on current date
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startDate = listing.createdAt
        let endDate = Calendar.current.date(byAdding: .month, value: 4, to: startDate) ?? startDate
        
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    private func getSubleaseType(_ listing: Listing) -> String {
        let types = ["Full Sublease", "Partial Sublease", "Room Only", "Temporary"]
        return types.randomElement() ?? "Full Sublease"
    }
}

// StatCard moved to shared component

struct EmptySubleaseView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Subleases Available")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Be the first to post a sublease for this timeframe")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create Sublease") {
                // Action handled by parent view
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.primaryBlue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct CreateSubleaseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var bedrooms = 1
    @State private var subleaseType: SubleaseType = .full
    @State private var utilities = ""
    @State private var contactInfo = ""
    @State private var images: [String] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("0", text: $price)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("$/month")
                    }
                }
                
                Section("Sublease Period") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(calculateDuration())
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Property Details") {
                    Picker("Bedrooms", selection: $bedrooms) {
                        ForEach(1...5, id: \.self) { bedroom in
                            Text("\(bedroom)").tag(bedroom)
                        }
                    }
                    
                    Picker("Sublease Type", selection: $subleaseType) {
                        ForEach(SubleaseType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    TextField("Utilities Included", text: $utilities)
                }
                
                Section("Contact Information") {
                    TextField("Contact Details", text: $contactInfo)
                }
                
                Section("Photos") {
                    Button("Add Photos") {
                        // Photo picker implementation
                    }
                    .foregroundColor(.primaryBlue)
                }
            }
            .navigationTitle("Create Sublease")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        createSublease()
                    }
                    .disabled(title.isEmpty || price.isEmpty)
                }
            }
        }
    }
    
    private func calculateDuration() -> String {
        let components = Calendar.current.dateComponents([.month, .day], from: startDate, to: endDate)
        
        if let months = components.month, months > 0 {
            return "\(months) month\(months > 1 ? "s" : "")"
        } else if let days = components.day, days > 0 {
            return "\(days) day\(days > 1 ? "s" : "")"
        } else {
            return "Same day"
        }
    }
    
    private func createSublease() {
        // Implementation for creating sublease
        print("Creating sublease: \(title)")
        dismiss()
    }
}

struct SubleaseDetailView: View {
    let listing: Listing
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Image gallery
                    TabView {
                        ForEach(listing.images, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(height: 250)
                    .tabViewStyle(PageTabViewStyle())
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Title and price
                        HStack {
                            Text(listing.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("$\(listing.price)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primaryBlue)
                                
                                Text("per month")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Sublease period
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.primaryBlue)
                            
                            Text("Available: May 1 - Aug 31, 2024")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.primaryBlue.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Key details
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            DetailRow(icon: "bed.double", title: "Bedrooms", value: "\(listing.bedrooms)")
                            DetailRow(icon: "location", title: "Location", value: listing.location.city)
                            DetailRow(icon: "bolt", title: "Utilities", value: listing.utilities)
                            DetailRow(icon: "clock", title: "Duration", value: "4 months")
                        }
                        
                        // Description
                        if let description = listing.description {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text(description)
                                    .font(.body)
                            }
                        }
                        
                        // Contact button
                        Button(action: {
                            // Contact subletter
                        }) {
                            Text("Contact Subletter")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.primaryBlue)
                                .cornerRadius(12)
                        }
                        .padding(.top)
                    }
                    .padding()
                }
            }
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
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
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

struct SubleaseFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTimeframe: SubleaseTimeframe
    
    var body: some View {
        NavigationView {
            Form {
                Section("Timeframe") {
                    Picker("Period", selection: $selectedTimeframe) {
                        ForEach(SubleaseTimeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.displayName).tag(timeframe)
                        }
                    }
                }
                
                Section("Filters") {
                    // Additional filters can be added here
                }
            }
            .navigationTitle("Sublease Filters")
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
}

// MARK: - Enums

enum SubleaseTimeframe: String, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case fall = "fall"
    case winter = "winter"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .fall: return "Fall"
        case .winter: return "Winter"
        case .custom: return "Custom"
        }
    }
    
    var dateRange: String {
        switch self {
        case .spring: return "Mar - May"
        case .summer: return "Jun - Aug"
        case .fall: return "Sep - Nov"
        case .winter: return "Dec - Feb"
        case .custom: return "Select dates"
        }
    }
}

enum SubleaseType: String, CaseIterable {
    case full = "full"
    case partial = "partial"
    case room = "room"
    case temporary = "temporary"
    
    var displayName: String {
        switch self {
        case .full: return "Full Sublease"
        case .partial: return "Partial Sublease"
        case .room: return "Room Only"
        case .temporary: return "Temporary"
        }
    }
}

#Preview {
    SubleaseView()
        .environmentObject(ListingsViewModel())
}