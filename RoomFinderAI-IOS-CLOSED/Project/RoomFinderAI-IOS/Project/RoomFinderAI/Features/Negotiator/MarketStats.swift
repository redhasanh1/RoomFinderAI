import Foundation

// MARK: - Market Statistics Model
struct MarketStats: Codable, Equatable {
    let average: Double?
    let median: Double?
    let min: Double?
    let max: Double?
    let count: Int
    let source: DataSource
    let analysis: String?
    let negotiationTips: [String]?
    let location: String?
    let houseType: String?
    let bedrooms: Int?
    let generatedAt: Date
    
    enum DataSource: String, Codable, CaseIterable {
        case database = "database"
        case ai = "ai_generated"
        case cached = "cached"
    }
    
    init(average: Double?, median: Double?, min: Double?, max: Double?, 
         count: Int, source: DataSource, analysis: String? = nil, 
         negotiationTips: [String]? = nil, location: String? = nil, 
         houseType: String? = nil, bedrooms: Int? = nil) {
        self.average = average
        self.median = median
        self.min = min
        self.max = max
        self.count = count
        self.source = source
        self.analysis = analysis
        self.negotiationTips = negotiationTips
        self.location = location
        self.houseType = houseType
        self.bedrooms = bedrooms
        self.generatedAt = Date()
    }
    
    // MARK: - Validation
    var isValid: Bool {
        return count > 0 && (average != nil || median != nil || min != nil || max != nil)
    }
    
    var hasMinimumData: Bool {
        return count >= NegotiatorConfig.minListingsForValidStats
    }
    
    // MARK: - Helper Properties
    var priceRange: String {
        guard let min = min, let max = max else { return "N/A" }
        return "$\(Int(min)) - $\(Int(max))"
    }
    
    var averagePrice: String {
        guard let avg = average else { return "N/A" }
        return "$\(Int(avg))"
    }
    
    var medianPrice: String {
        guard let med = median else { return "N/A" }
        return "$\(Int(med))"
    }
    
    // MARK: - Cache Key Generation
    static func cacheKey(location: String?, houseType: String?, bedrooms: Int?) -> String {
        let loc = location?.lowercased() ?? "any"
        let type = houseType?.lowercased() ?? "any"
        let bed = bedrooms?.description ?? "any"
        return "market_stats_\(loc)_\(type)_\(bed)"
    }
    
    func cacheKey() -> String {
        return MarketStats.cacheKey(location: location, houseType: houseType, bedrooms: bedrooms)
    }
    
    // MARK: - Age Check
    var isExpired: Bool {
        return Date().timeIntervalSince(generatedAt) > NegotiatorConfig.marketDataCacheTimeout
    }
}

// MARK: - Market Data Query Parameters
struct MarketDataQuery: Equatable {
    let location: String?
    let houseType: String?
    let bedrooms: Int?
    let maxResults: Int
    
    init(location: String? = nil, houseType: String? = nil, bedrooms: Int? = nil, 
         maxResults: Int = NegotiatorConfig.maxListingsForStats) {
        self.location = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.houseType = houseType?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bedrooms = bedrooms
        self.maxResults = maxResults
    }
    
    var cacheKey: String {
        return MarketStats.cacheKey(location: location, houseType: houseType, bedrooms: bedrooms)
    }
}

// MARK: - AI Market Data Response (for OpenAI JSON parsing)
struct AIMarketDataResponse: Codable {
    let average: Double?
    let median: Double?
    let min: Double?
    let max: Double?
    let count: Int
    let analysis: String?
    let negotiationTips: [String]?
    
    func toMarketStats(query: MarketDataQuery) -> MarketStats {
        return MarketStats(
            average: average,
            median: median,
            min: min,
            max: max,
            count: count,
            source: .ai,
            analysis: analysis,
            negotiationTips: negotiationTips,
            location: query.location,
            houseType: query.houseType,
            bedrooms: query.bedrooms
        )
    }
}

// MARK: - Statistics Calculator
extension MarketStats {
    // Calculate stats from price array
    static func calculate(from prices: [Double], query: MarketDataQuery) -> MarketStats {
        guard !prices.isEmpty else {
            return MarketStats(
                average: nil, median: nil, min: nil, max: nil,
                count: 0, source: .database,
                location: query.location, houseType: query.houseType, 
                bedrooms: query.bedrooms
            )
        }
        
        let sortedPrices = prices.sorted()
        let count = prices.count
        let sum = prices.reduce(0, +)
        
        let average = sum / Double(count)
        let median = calculateMedian(from: sortedPrices)
        let min = sortedPrices.first
        let max = sortedPrices.last
        
        return MarketStats(
            average: average,
            median: median,
            min: min,
            max: max,
            count: count,
            source: .database,
            location: query.location,
            houseType: query.houseType,
            bedrooms: query.bedrooms
        )
    }
    
    private static func calculateMedian(from sortedPrices: [Double]) -> Double {
        let count = sortedPrices.count
        if count % 2 == 0 {
            let mid1 = sortedPrices[count / 2 - 1]
            let mid2 = sortedPrices[count / 2]
            return (mid1 + mid2) / 2.0
        } else {
            return sortedPrices[count / 2]
        }
    }
}

// MARK: - Market Data Cache
class MarketDataCache {
    private var cache: [String: MarketStats] = [:]
    private let queue = DispatchQueue(label: "market_data_cache", attributes: .concurrent)
    
    func get(for key: String) -> MarketStats? {
        return queue.sync {
            let stats = cache[key]
            return stats?.isExpired == false ? stats : nil
        }
    }
    
    func set(_ stats: MarketStats, for key: String) {
        queue.async(flags: .barrier) {
            self.cache[key] = stats
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    func clearExpired() {
        queue.async(flags: .barrier) {
            self.cache = self.cache.filter { !$0.value.isExpired }
        }
    }
}