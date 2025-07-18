import Foundation
import CoreLocation

class MarketAnalyticsService: ObservableObject {
    static let shared = MarketAnalyticsService()
    
    private let supabaseService = SupabaseService.shared
    
    private init() {}
    
    // MARK: - Market Overview
    
    func getMarketOverview(for city: String) async throws -> MarketOverview {
        let listings = try await supabaseService.fetchAllListings()
        let cityListings = listings.filter { $0.city.lowercased() == city.lowercased() }
        
        guard !cityListings.isEmpty else {
            throw MarketAnalyticsError.noDataAvailable
        }
        
        let prices = cityListings.map { $0.price }
        let averagePrice = prices.reduce(0, +) / prices.count
        let medianPrice = calculateMedian(prices)
        let priceRange = (min: prices.min() ?? 0, max: prices.max() ?? 0)
        
        // Calculate price trends (mock data for demo)
        let priceHistory = generatePriceHistory(currentAverage: averagePrice)
        let trend = calculatePriceTrend(priceHistory)
        
        // Property type distribution
        let propertyTypes = Dictionary(grouping: cityListings) { $0.propertyType }
        let typeDistribution = propertyTypes.mapValues { $0.count }
        
        // Bedroom distribution
        let bedroomDistribution = Dictionary(grouping: cityListings) { $0.bedrooms }
            .mapValues { $0.count }
        
        // Market metrics
        let daysOnMarket = Int.random(in: 15...45) // Mock data
        let inventoryLevel = calculateInventoryLevel(listingCount: cityListings.count)
        
        return MarketOverview(
            city: city,
            averagePrice: averagePrice,
            medianPrice: medianPrice,
            priceRange: priceRange,
            totalListings: cityListings.count,
            priceHistory: priceHistory,
            trend: trend,
            propertyTypeDistribution: typeDistribution,
            bedroomDistribution: bedroomDistribution,
            averageDaysOnMarket: daysOnMarket,
            inventoryLevel: inventoryLevel,
            marketScore: calculateMarketScore(
                averagePrice: averagePrice,
                inventoryLevel: inventoryLevel,
                daysOnMarket: daysOnMarket
            )
        )
    }
    
    // MARK: - Neighborhood Analysis
    
    func getNeighborhoodAnalysis(location: CLLocation, radius: Double = 2.0) async throws -> NeighborhoodAnalysis {
        let listings = try await supabaseService.fetchAllListings()
        
        // Filter listings within radius (simplified calculation)
        let nearbyListings = listings.filter { listing in
            let distance = location.distance(from: CLLocation(
                latitude: listing.location.latitude,
                longitude: listing.location.longitude
            ))
            return distance <= radius * 1000 // Convert km to meters
        }
        
        guard !nearbyListings.isEmpty else {
            throw MarketAnalyticsError.noDataAvailable
        }
        
        let prices = nearbyListings.map { $0.price }
        let averagePrice = prices.reduce(0, +) / prices.count
        
        // Calculate walkability score (mock data)
        let walkabilityScore = Int.random(in: 50...95)
        
        // Transit access (mock data)
        let transitAccess = ["Subway: 0.3 miles", "Bus: 0.1 miles", "Bike Share: 0.2 miles"]
        
        // Amenities nearby (mock data)
        let amenities = [
            "Restaurants": Int.random(in: 10...50),
            "Grocery Stores": Int.random(in: 2...8),
            "Parks": Int.random(in: 1...5),
            "Schools": Int.random(in: 2...10),
            "Hospitals": Int.random(in: 1...3)
        ]
        
        // Safety score (mock data)
        let safetyScore = Int.random(in: 60...90)
        
        return NeighborhoodAnalysis(
            center: location,
            radius: radius,
            averagePrice: averagePrice,
            listingCount: nearbyListings.count,
            walkabilityScore: walkabilityScore,
            transitAccess: transitAccess,
            amenities: amenities,
            safetyScore: safetyScore,
            demographics: generateDemographics(),
            priceComparison: generatePriceComparison(currentPrice: averagePrice),
            growthPotential: calculateGrowthPotential(
                averagePrice: averagePrice,
                amenities: amenities
            )
        )
    }
    
    // MARK: - Price Prediction
    
    func getPricePrediction(for listing: Listing) async throws -> PricePrediction {
        let allListings = try await supabaseService.fetchAllListings()
        
        // Find comparable properties
        let comparables = findComparableProperties(
            target: listing,
            allListings: allListings
        )
        
        let comparablePrices = comparables.map { $0.price }
        let averageComparable = comparablePrices.isEmpty ? listing.price : 
            comparablePrices.reduce(0, +) / comparablePrices.count
        
        // Price adjustment factors
        let locationAdjustment = calculateLocationAdjustment(listing)
        let sizeAdjustment = calculateSizeAdjustment(listing, comparables: comparables)
        let amenityAdjustment = calculateAmenityAdjustment(listing)
        
        let predictedPrice = Double(averageComparable) * locationAdjustment * sizeAdjustment * amenityAdjustment
        
        let confidence = calculatePredictionConfidence(
            comparablesCount: comparables.count,
            priceVariation: calculatePriceVariation(comparablePrices)
        )
        
        return PricePrediction(
            currentPrice: listing.price,
            predictedPrice: Int(predictedPrice),
            confidence: confidence,
            priceRange: (
                min: Int(predictedPrice * 0.9),
                max: Int(predictedPrice * 1.1)
            ),
            factors: [
                "Location": locationAdjustment,
                "Size": sizeAdjustment,
                "Amenities": amenityAdjustment
            ],
            comparables: comparables,
            recommendation: generatePriceRecommendation(
                currentPrice: listing.price,
                predictedPrice: Int(predictedPrice)
            )
        )
    }
    
    // MARK: - Market Trends
    
    func getMarketTrends(timeframe: TimeFrame = .sixMonths) async throws -> MarketTrends {
        let listings = try await supabaseService.fetchAllListings()
        
        // Group by property type
        let propertyTypes = Dictionary(grouping: listings) { $0.propertyType }
        
        var typeTrends: [PropertyType: TrendData] = [:]
        
        for (type, typeListings) in propertyTypes {
            let prices = typeListings.map { $0.price }
            let averagePrice = prices.reduce(0, +) / prices.count
            
            // Generate historical data (mock)
            let historicalData = generateHistoricalData(
                currentAverage: averagePrice,
                timeframe: timeframe
            )
            
            typeTrends[type] = TrendData(
                currentAverage: averagePrice,
                historicalData: historicalData,
                trend: calculateTrend(historicalData),
                percentChange: calculatePercentChange(historicalData)
            )
        }
        
        return MarketTrends(
            timeframe: timeframe,
            propertyTypeTrends: typeTrends,
            overallTrend: calculateOverallTrend(typeTrends),
            topGrowthAreas: identifyTopGrowthAreas(listings),
            marketInsights: generateMarketInsights(typeTrends)
        )
    }
    
    // MARK: - Investment Analysis
    
    func getInvestmentAnalysis(for listing: Listing) async throws -> InvestmentAnalysis {
        let marketOverview = try await getMarketOverview(for: listing.city)
        let pricePrediction = try await getPricePrediction(for: listing)
        
        // Calculate rental yield
        let monthlyRent = Double(listing.price) // Assuming price is monthly rent
        let annualRent = monthlyRent * 12
        let propertyValue = Double(listing.price) * 12 // Estimate property value
        let rentalYield = (annualRent / propertyValue) * 100
        
        // Calculate ROI projections
        let roiProjections = calculateROIProjections(
            propertyValue: propertyValue,
            monthlyRent: monthlyRent,
            appreciationRate: 0.03
        )
        
        // Risk assessment
        let riskScore = calculateRiskScore(
            location: listing.city,
            propertyType: listing.propertyType,
            marketTrend: marketOverview.trend
        )
        
        return InvestmentAnalysis(
            listing: listing,
            purchasePrice: Int(propertyValue),
            monthlyRent: Int(monthlyRent),
            rentalYield: rentalYield,
            roiProjections: roiProjections,
            riskScore: riskScore,
            marketScore: marketOverview.marketScore,
            recommendation: generateInvestmentRecommendation(
                rentalYield: rentalYield,
                riskScore: riskScore,
                marketScore: marketOverview.marketScore
            ),
            comparativeAnalysis: generateComparativeAnalysis(listing, marketOverview)
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateMedian(_ numbers: [Int]) -> Int {
        let sorted = numbers.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            return (sorted[count/2 - 1] + sorted[count/2]) / 2
        } else {
            return sorted[count/2]
        }
    }
    
    private func generatePriceHistory(currentAverage: Int) -> [PricePoint] {
        var history: [PricePoint] = []
        var price = Double(currentAverage)
        let calendar = Calendar.current
        
        for i in 0..<12 {
            let date = calendar.date(byAdding: .month, value: -i, to: Date()) ?? Date()
            price *= Double.random(in: 0.95...1.05) // Random fluctuation
            history.append(PricePoint(date: date, price: Int(price)))
        }
        
        return history.reversed()
    }
    
    private func calculatePriceTrend(_ history: [PricePoint]) -> PriceTrend {
        guard history.count >= 2 else { return .stable }
        
        let first = history.first!.price
        let last = history.last!.price
        let change = Double(last - first) / Double(first)
        
        if change > 0.05 {
            return .increasing
        } else if change < -0.05 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateInventoryLevel(listingCount: Int) -> InventoryLevel {
        switch listingCount {
        case 0...10: return .low
        case 11...50: return .moderate
        default: return .high
        }
    }
    
    private func calculateMarketScore(averagePrice: Int, inventoryLevel: InventoryLevel, daysOnMarket: Int) -> Int {
        var score = 50
        
        // Adjust based on inventory
        switch inventoryLevel {
        case .low: score += 20
        case .moderate: score += 10
        case .high: score -= 10
        }
        
        // Adjust based on days on market
        if daysOnMarket < 20 {
            score += 15
        } else if daysOnMarket > 40 {
            score -= 15
        }
        
        return max(0, min(100, score))
    }
    
    private func findComparableProperties(target: Listing, allListings: [Listing]) -> [Listing] {
        return allListings.filter { listing in
            listing.id != target.id &&
            listing.city == target.city &&
            listing.propertyType == target.propertyType &&
            abs(listing.bedrooms - target.bedrooms) <= 1 &&
            abs(listing.price - target.price) <= target.price / 2
        }
    }
    
    private func calculateLocationAdjustment(_ listing: Listing) -> Double {
        // Mock location adjustment based on city
        switch listing.city.lowercased() {
        case "toronto": return 1.2
        case "vancouver": return 1.15
        case "montreal": return 1.0
        default: return 0.9
        }
    }
    
    private func calculateSizeAdjustment(_ listing: Listing, comparables: [Listing]) -> Double {
        guard !comparables.isEmpty else { return 1.0 }
        
        let avgBedrooms = Double(comparables.map { $0.bedrooms }.reduce(0, +)) / Double(comparables.count)
        let bedroomDiff = Double(listing.bedrooms) - avgBedrooms
        
        return 1.0 + (bedroomDiff * 0.15) // 15% adjustment per bedroom difference
    }
    
    private func calculateAmenityAdjustment(_ listing: Listing) -> Double {
        var adjustment = 1.0
        
        if listing.utilities.contains("included") {
            adjustment += 0.05
        }
        
        return adjustment
    }
    
    private func calculatePredictionConfidence(comparablesCount: Int, priceVariation: Double) -> Double {
        let countFactor = min(1.0, Double(comparablesCount) / 10.0)
        let variationFactor = max(0.5, 1.0 - priceVariation)
        
        return (countFactor * variationFactor) * 100
    }
    
    private func calculatePriceVariation(_ prices: [Int]) -> Double {
        guard prices.count > 1 else { return 0.0 }
        
        let avg = Double(prices.reduce(0, +)) / Double(prices.count)
        let variance = prices.map { pow(Double($0) - avg, 2) }.reduce(0, +) / Double(prices.count)
        let stdDev = sqrt(variance)
        
        return stdDev / avg
    }
    
    private func generatePriceRecommendation(currentPrice: Int, predictedPrice: Int) -> String {
        let diff = Double(predictedPrice - currentPrice) / Double(currentPrice)
        
        if diff > 0.1 {
            return "Underpriced - Consider increasing price"
        } else if diff < -0.1 {
            return "Overpriced - Consider reducing price"
        } else {
            return "Fairly priced"
        }
    }
    
    private func generateDemographics() -> [String: Any] {
        return [
            "median_age": Int.random(in: 25...45),
            "median_income": Int.random(in: 40000...80000),
            "education_level": ["High School", "College", "University"].randomElement() ?? "College",
            "population_density": Int.random(in: 1000...5000)
        ]
    }
    
    private func generatePriceComparison(currentPrice: Int) -> [String: Int] {
        return [
            "city_average": currentPrice + Int.random(in: -200...200),
            "provincial_average": currentPrice + Int.random(in: -300...300),
            "national_average": currentPrice + Int.random(in: -400...400)
        ]
    }
    
    private func calculateGrowthPotential(averagePrice: Int, amenities: [String: Int]) -> Int {
        var score = 50
        
        // Adjust based on amenities
        let amenityScore = amenities.values.reduce(0, +)
        score += min(30, amenityScore / 3)
        
        return max(0, min(100, score))
    }
    
    private func generateHistoricalData(currentAverage: Int, timeframe: TimeFrame) -> [PricePoint] {
        let months = timeframe.months
        var data: [PricePoint] = []
        var price = Double(currentAverage)
        let calendar = Calendar.current
        
        for i in 0..<months {
            let date = calendar.date(byAdding: .month, value: -i, to: Date()) ?? Date()
            price *= Double.random(in: 0.98...1.02)
            data.append(PricePoint(date: date, price: Int(price)))
        }
        
        return data.reversed()
    }
    
    private func calculateTrend(_ data: [PricePoint]) -> PriceTrend {
        guard data.count >= 2 else { return .stable }
        
        let first = data.first!.price
        let last = data.last!.price
        let change = Double(last - first) / Double(first)
        
        if change > 0.02 {
            return .increasing
        } else if change < -0.02 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculatePercentChange(_ data: [PricePoint]) -> Double {
        guard data.count >= 2 else { return 0.0 }
        
        let first = data.first!.price
        let last = data.last!.price
        
        return (Double(last - first) / Double(first)) * 100
    }
    
    private func calculateOverallTrend(_ typeTrends: [PropertyType: TrendData]) -> PriceTrend {
        let trends = typeTrends.values.map { $0.trend }
        let increasingCount = trends.filter { $0 == .increasing }.count
        let decreasingCount = trends.filter { $0 == .decreasing }.count
        
        if increasingCount > decreasingCount {
            return .increasing
        } else if decreasingCount > increasingCount {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func identifyTopGrowthAreas(_ listings: [Listing]) -> [String] {
        let cities = Array(Set(listings.map { $0.city }))
        return cities.shuffled().prefix(3).map { $0 }
    }
    
    private func generateMarketInsights(_ trends: [PropertyType: TrendData]) -> [String] {
        var insights: [String] = []
        
        for (type, trend) in trends {
            if trend.percentChange > 5 {
                insights.append("\(type.displayName) prices are rising rapidly (+\(String(format: "%.1f", trend.percentChange))%)")
            } else if trend.percentChange < -5 {
                insights.append("\(type.displayName) prices are declining (-\(String(format: "%.1f", abs(trend.percentChange)))%)")
            }
        }
        
        return insights
    }
    
    private func calculateROIProjections(propertyValue: Double, monthlyRent: Double, appreciationRate: Double) -> [ROIProjection] {
        var projections: [ROIProjection] = []
        var currentValue = propertyValue
        let annualRent = monthlyRent * 12
        
        for year in 1...10 {
            currentValue *= (1 + appreciationRate)
            let totalReturn = (annualRent * Double(year)) + (currentValue - propertyValue)
            let roi = (totalReturn / propertyValue) * 100
            
            projections.append(ROIProjection(
                year: year,
                propertyValue: Int(currentValue),
                cumulativeRent: Int(annualRent * Double(year)),
                totalReturn: Int(totalReturn),
                roi: roi
            ))
        }
        
        return projections
    }
    
    private func calculateRiskScore(location: String, propertyType: PropertyType, marketTrend: PriceTrend) -> Int {
        var score = 50
        
        // Location risk
        switch location.lowercased() {
        case "toronto", "vancouver": score -= 10 // Lower risk
        default: score += 10 // Higher risk
        }
        
        // Property type risk
        switch propertyType {
        case .apartment, .condo: score -= 5
        case .house: score -= 10
        default: score += 5
        }
        
        // Market trend risk
        switch marketTrend {
        case .increasing: score -= 15
        case .stable: score += 0
        case .decreasing: score += 15
        }
        
        return max(0, min(100, score))
    }
    
    private func generateInvestmentRecommendation(rentalYield: Double, riskScore: Int, marketScore: Int) -> String {
        if rentalYield > 7 && riskScore < 40 && marketScore > 70 {
            return "Strong Buy"
        } else if rentalYield > 5 && riskScore < 60 && marketScore > 50 {
            return "Buy"
        } else if rentalYield > 3 && riskScore < 70 {
            return "Hold"
        } else {
            return "Avoid"
        }
    }
    
    private func generateComparativeAnalysis(_ listing: Listing, _ marketOverview: MarketOverview) -> [String: Any] {
        return [
            "vs_market_average": Double(listing.price) / Double(marketOverview.averagePrice),
            "vs_market_median": Double(listing.price) / Double(marketOverview.medianPrice),
            "percentile_ranking": Int.random(in: 20...80)
        ]
    }
}

// MARK: - Models

struct MarketOverview {
    let city: String
    let averagePrice: Int
    let medianPrice: Int
    let priceRange: (min: Int, max: Int)
    let totalListings: Int
    let priceHistory: [PricePoint]
    let trend: PriceTrend
    let propertyTypeDistribution: [PropertyType: Int]
    let bedroomDistribution: [Int: Int]
    let averageDaysOnMarket: Int
    let inventoryLevel: InventoryLevel
    let marketScore: Int
}

struct NeighborhoodAnalysis {
    let center: CLLocation
    let radius: Double
    let averagePrice: Int
    let listingCount: Int
    let walkabilityScore: Int
    let transitAccess: [String]
    let amenities: [String: Int]
    let safetyScore: Int
    let demographics: [String: Any]
    let priceComparison: [String: Int]
    let growthPotential: Int
}

struct PricePrediction {
    let currentPrice: Int
    let predictedPrice: Int
    let confidence: Double
    let priceRange: (min: Int, max: Int)
    let factors: [String: Double]
    let comparables: [Listing]
    let recommendation: String
}

struct MarketTrends {
    let timeframe: TimeFrame
    let propertyTypeTrends: [PropertyType: TrendData]
    let overallTrend: PriceTrend
    let topGrowthAreas: [String]
    let marketInsights: [String]
}

struct TrendData {
    let currentAverage: Int
    let historicalData: [PricePoint]
    let trend: PriceTrend
    let percentChange: Double
}

struct InvestmentAnalysis {
    let listing: Listing
    let purchasePrice: Int
    let monthlyRent: Int
    let rentalYield: Double
    let roiProjections: [ROIProjection]
    let riskScore: Int
    let marketScore: Int
    let recommendation: String
    let comparativeAnalysis: [String: Any]
}

struct ROIProjection {
    let year: Int
    let propertyValue: Int
    let cumulativeRent: Int
    let totalReturn: Int
    let roi: Double
}

struct PricePoint {
    let date: Date
    let price: Int
}

enum PriceTrend {
    case increasing
    case stable
    case decreasing
}

enum InventoryLevel {
    case low
    case moderate
    case high
}

enum TimeFrame {
    case threeMonths
    case sixMonths
    case oneYear
    case twoYears
    
    var months: Int {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        case .twoYears: return 24
        }
    }
}

// MARK: - Errors

enum MarketAnalyticsError: Error {
    case noDataAvailable
    case invalidLocation
    case calculationError
    
    var localizedDescription: String {
        switch self {
        case .noDataAvailable:
            return "No market data available for this area"
        case .invalidLocation:
            return "Invalid location provided"
        case .calculationError:
            return "Error calculating market analytics"
        }
    }
}