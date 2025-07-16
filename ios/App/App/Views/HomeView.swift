import SwiftUI

struct HomeView: View {
    @State private var featuredProperties: [Property] = []
    @State private var recentProperties: [Property] = []
    @State private var isLoading = true
    @State private var showingSearch = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    headerSection
                    
                    // Quick Search
                    quickSearchSection
                    
                    // Featured Properties
                    featuredSection
                    
                    // Recent Properties
                    recentSection
                }
                .padding(.horizontal)
            }
            .navigationTitle("RoomFinderAI")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find Your Perfect")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Dream Home")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                Spacer()
                
                // AI Assistant Button
                Button(action: {
                    // Navigate to AI chat
                }) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                }
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Quick Search Section
    
    private var quickSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Search")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {
                    showingSearch = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    QuickSearchCard(title: "Apartments", icon: "building.2", category: "apartment")
                    QuickSearchCard(title: "Houses", icon: "house", category: "house")
                    QuickSearchCard(title: "Studios", icon: "rectangle", category: "studio")
                    QuickSearchCard(title: "Condos", icon: "building", category: "condo")
                }
                .padding(.horizontal, 4)
            }
        }
        .sheet(isPresented: $showingSearch) {
            SearchView()
        }
    }
    
    // MARK: - Featured Section
    
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Featured Properties")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("See All") {
                    showingSearch = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(featuredProperties) { property in
                            NavigationLink(destination: PropertyDetailView(property: property)) {
                                FeaturedPropertyCard(property: property)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    // MARK: - Recent Section
    
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Listings")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 12) {
                ForEach(recentProperties) { property in
                    NavigationLink(destination: PropertyDetailView(property: property)) {
                        PropertyRowCard(property: property)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadData() async {
        isLoading = true
        
        do {
            // Call your existing web functions through the bridge
            async let featuredData = WebBridge.shared.callWebFunction("iosListingsAPI.getFeaturedListings", with: ["limit": 10])
            async let recentData = WebBridge.shared.callWebFunction("iosListingsAPI.getRecentListings", with: ["limit": 20])
            
            let (featured, recent) = try await (featuredData, recentData)
            
            // Parse the results
            if let featuredResult = featured as? [String: Any],
               let featuredArray = featuredResult["data"] as? [[String: Any]] {
                self.featuredProperties = parseProperties(from: featuredArray)
            }
            
            if let recentResult = recent as? [String: Any],
               let recentArray = recentResult["data"] as? [[String: Any]] {
                self.recentProperties = parseProperties(from: recentArray)
            }
            
        } catch {
            print("Error loading data: \(error)")
        }
        
        isLoading = false
    }
    
    private func parseProperties(from array: [[String: Any]]) -> [Property] {
        return array.compactMap { dict in
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let property = try? JSONDecoder().decode(Property.self, from: data) else {
                return nil
            }
            return property
        }
    }
}

// MARK: - Supporting Views

struct QuickSearchCard: View {
    let title: String
    let icon: String
    let category: String
    
    var body: some View {
        Button(action: {
            // Navigate to search with category filter
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct FeaturedPropertyCard: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Property Image
            AsyncImage(url: URL(string: property.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 280, height: 200)
            .clipped()
            
            // Property Info
            VStack(alignment: .leading, spacing: 8) {
                Text(property.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(property.location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(property.formattedPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    if let bedrooms = property.bedrooms, let bathrooms = property.bathrooms {
                        Text("\(bedrooms)bd • \(bathrooms)ba")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .frame(width: 280)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct PropertyRowCard: View {
    let property: Property
    
    var body: some View {
        HStack(spacing: 12) {
            // Property Image
            AsyncImage(url: URL(string: property.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Property Info
            VStack(alignment: .leading, spacing: 4) {
                Text(property.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(property.location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(property.formattedPrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    if let bedrooms = property.bedrooms, let bathrooms = property.bathrooms {
                        Text("\(bedrooms)bd • \(bathrooms)ba")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    HomeView()
}