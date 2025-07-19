import SwiftUI
import Charts

struct MarketAnalyticsView: View {
    @StateObject private var marketService = MarketAnalyticsService.shared
    @State private var selectedCity = "Toronto"
    @State private var marketOverview: MarketOverview?
    @State private var isLoading = true
    @State private var selectedTimeframe: TimeFrame = .sixMonths
    
    let cities = ["Toronto", "Vancouver", "Montreal", "Calgary", "Ottawa"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // City Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select City")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(cities, id: \.self) { city in
                                    Button(action: {
                                        selectedCity = city
                                        loadMarketData()
                                    }) {
                                        Text(city)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(selectedCity == city ? .white : .primaryBlue)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedCity == city ? Color.primaryBlue : Color.primaryBlue.opacity(0.1))
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(height: 200)
                    } else if let overview = marketOverview {
                        // Market Overview Cards
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            MarketStatCard(
                                title: "Average Price",
                                value: "$\(overview.averagePrice)",
                                change: "+5.2%",
                                isPositive: true
                            )
                            
                            MarketStatCard(
                                title: "Total Listings",
                                value: "\(overview.totalListings)",
                                change: "+12",
                                isPositive: true
                            )
                            
                            MarketStatCard(
                                title: "Median Price",
                                value: "$\(overview.medianPrice)",
                                change: "+3.8%",
                                isPositive: true
                            )
                            
                            MarketStatCard(
                                title: "Days on Market",
                                value: "\(overview.averageDaysOnMarket)",
                                change: "-2 days",
                                isPositive: true
                            )
                        }
                        
                        // Price Trend Chart
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Price Trends")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if #available(iOS 16.0, *) {
                                Chart {
                                    ForEach(overview.priceHistory, id: \.date) { point in
                                        LineMark(
                                            x: .value("Date", point.date),
                                            y: .value("Price", point.price)
                                        )
                                        .foregroundStyle(Color.primaryBlue)
                                    }
                                }
                                .frame(height: 200)
                            } else {
                                // Fallback for iOS < 16
                                PriceChartFallback(data: overview.priceHistory)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        
                        // Property Type Distribution
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Property Types")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 12) {
                                ForEach(Array(overview.propertyTypeDistribution.keys.sorted(by: { overview.propertyTypeDistribution[$0] ?? 0 > overview.propertyTypeDistribution[$1] ?? 0 })), id: \.self) { type in
                                    let count = overview.propertyTypeDistribution[type] ?? 0
                                    let percentage = Double(count) / Double(overview.totalListings) * 100
                                    
                                    PropertyTypeRow(
                                        type: type,
                                        count: count,
                                        percentage: percentage
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        
                        // Market Score
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Market Health Score")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(overview.marketScore)")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(.primaryBlue)
                                    
                                    Text("out of 100")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text(getMarketHealthText(score: overview.marketScore))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(getMarketHealthColor(score: overview.marketScore))
                                    
                                    Text("Market Condition")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            ProgressView(value: Double(overview.marketScore) / 100)
                                .tint(.primaryBlue)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        
                        // Market Insights
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Market Insights")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 12) {
                                InsightCard(
                                    icon: "chart.line.uptrend.xyaxis",
                                    title: "Price Trend",
                                    description: getTrendDescription(overview.trend),
                                    color: getTrendColor(overview.trend)
                                )
                                
                                InsightCard(
                                    icon: "house.fill",
                                    title: "Inventory Level",
                                    description: getInventoryDescription(overview.inventoryLevel),
                                    color: getInventoryColor(overview.inventoryLevel)
                                )
                                
                                InsightCard(
                                    icon: "clock.fill",
                                    title: "Market Speed",
                                    description: "Properties sell \(overview.averageDaysOnMarket) days on average",
                                    color: overview.averageDaysOnMarket < 30 ? .green : .orange
                                )
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            .navigationTitle("Market Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadMarketData()
            }
        }
    }
    
    private func loadMarketData() {
        isLoading = true
        
        Task {
            do {
                let overview = try await marketService.getMarketOverview(for: selectedCity)
                await MainActor.run {
                    marketOverview = overview
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func getMarketHealthText(score: Int) -> String {
        switch score {
        case 80...100: return "Excellent"
        case 60...79: return "Good"
        case 40...59: return "Fair"
        case 20...39: return "Poor"
        default: return "Very Poor"
        }
    }
    
    private func getMarketHealthColor(score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60...79: return .blue
        case 40...59: return .orange
        default: return .red
        }
    }
    
    private func getTrendDescription(_ trend: PriceTrend) -> String {
        switch trend {
        case .increasing: return "Prices are rising"
        case .stable: return "Prices are stable"
        case .decreasing: return "Prices are falling"
        }
    }
    
    private func getTrendColor(_ trend: PriceTrend) -> Color {
        switch trend {
        case .increasing: return .green
        case .stable: return .blue
        case .decreasing: return .red
        }
    }
    
    private func getInventoryDescription(_ level: InventoryLevel) -> String {
        switch level {
        case .low: return "Low inventory - Seller's market"
        case .moderate: return "Balanced inventory"
        case .high: return "High inventory - Buyer's market"
        }
    }
    
    private func getInventoryColor(_ level: InventoryLevel) -> Color {
        switch level {
        case .low: return .red
        case .moderate: return .blue
        case .high: return .green
        }
    }
}

struct MarketStatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.caption)
                
                Text(change)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isPositive ? .green : .red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PropertyTypeRow: View {
    let type: PropertyType
    let count: Int
    let percentage: Double
    
    var body: some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundColor(.primaryBlue)
                .frame(width: 20)
            
            Text(type.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text("\(percentage, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct PriceChartFallback: View {
    let data: [PricePoint]
    
    var body: some View {
        VStack {
            Text("Price Trend Chart")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Chart requires iOS 16+")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Simple line representation
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data.indices, id: \.self) { index in
                    let point = data[index]
                    let maxPrice = data.map { $0.price }.max() ?? 1
                    let height = CGFloat(point.price) / CGFloat(maxPrice) * 100
                    
                    Rectangle()
                        .fill(Color.primaryBlue)
                        .frame(width: 8, height: height)
                        .cornerRadius(2)
                }
            }
            .frame(height: 100)
        }
        .frame(height: 200)
    }
}

#Preview {
    MarketAnalyticsView()
}