import SwiftUI

struct AISearchView: View {
    @State private var searchQuery = ""
    @State private var aiResponse: AISearchResult?
    @State private var isLoading = false
    @State private var showingResults = false
    @Environment(\.dismiss) private var dismiss
    
    let sampleQueries = [
        "2 bedroom apartment near downtown under $2000",
        "Pet-friendly house with a backyard",
        "Studio apartment close to public transport",
        "Modern condo with city views and gym",
        "Family-friendly house in good school district"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Chat Interface
                if showingResults && aiResponse != nil {
                    resultsSection
                } else {
                    searchInterface
                }
            }
            .navigationTitle("AI Property Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Property Assistant")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Describe what you're looking for")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            Divider()
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Search Interface
    
    private var searchInterface: some View {
        ScrollView {
            VStack(spacing: 24) {
                // AI Avatar and Welcome
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Hi! I'm your AI assistant")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tell me what kind of property you're looking for, and I'll help you find the perfect match")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Search Input
                VStack(spacing: 12) {
                    Text("Describe your ideal property:")
                        .font(.headline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("e.g., 2 bedroom apartment near downtown under $2000", text: $searchQuery, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    
                    Button(action: {
                        searchWithAI()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(isLoading ? "Searching..." : "Search with AI")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(searchQuery.isEmpty || isLoading)
                }
                
                // Sample Queries
                VStack(alignment: .leading, spacing: 12) {
                    Text("Try these examples:")
                        .font(.headline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 8) {
                        ForEach(sampleQueries, id: \.self) { query in
                            Button(action: {
                                searchQuery = query
                            }) {
                                HStack {
                                    Text(query)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Image(systemName: "arrow.up.left")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // AI Response
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("AI Recommendation")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(aiResponse?.recommendation ?? "")
                        .font(.body)
                        .lineSpacing(4)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Recommended Properties
                if let properties = aiResponse?.listings, !properties.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommended Properties")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(properties) { property in
                                NavigationLink(destination: PropertyDetailView(property: property)) {
                                    PropertySearchCard(property: property)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                // Search Again Button
                Button("Search Again") {
                    showingResults = false
                    aiResponse = nil
                    searchQuery = ""
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
    
    // MARK: - AI Search Function
    
    @MainActor
    private func searchWithAI() {
        guard !searchQuery.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                // Call your existing AI search function
                let result = try await WebBridge.shared.callWebFunction(
                    "iosAIApi.searchProperties",
                    with: ["query": searchQuery]
                )
                
                if let aiResult = result as? [String: Any],
                   let recommendation = aiResult["recommendation"] as? String,
                   let listingsArray = aiResult["listings"] as? [[String: Any]] {
                    
                    let properties = parseProperties(from: listingsArray)
                    
                    self.aiResponse = AISearchResult(
                        recommendation: recommendation,
                        listings: properties,
                        searchQuery: searchQuery
                    )
                    
                    self.showingResults = true
                }
                
            } catch {
                print("AI search error: \(error)")
                // Could show an error alert here
            }
            
            isLoading = false
        }
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

#Preview {
    AISearchView()
}