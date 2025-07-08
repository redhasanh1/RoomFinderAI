import Foundation
import UIKit

// MARK: - Data Validation Service
class DataValidationService {
    static let shared = DataValidationService()
    
    private var isConnectedToRealAPI = false
    private var lastConnectionCheck: Date?
    private let connectionCheckInterval: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Connection Validation
    func validateAPIConnection() async -> Bool {
        // Check if we need to revalidate
        if let lastCheck = lastConnectionCheck,
           Date().timeIntervalSince(lastCheck) < connectionCheckInterval,
           isConnectedToRealAPI {
            return true
        }
        
        print("🔄 Validating API connection...")
        
        let isValidSupabase = await SupabaseService.shared.validateConnection()
        
        if isValidSupabase {
            print("✅ Supabase connection validated successfully")
            isConnectedToRealAPI = true
        } else {
            print("❌ Supabase connection failed")
            isConnectedToRealAPI = false
        }
        
        lastConnectionCheck = Date()
        return isConnectedToRealAPI
    }
    
    // MARK: - Data Quality Validation
    func validatePropertyData(_ properties: [Property]) -> PropertyDataQuality {
        var quality = PropertyDataQuality()
        
        for property in properties {
            quality.totalCount += 1
            
            // Check for real images
            if !property.images.isEmpty && !property.images.allSatisfy({ $0.contains("unsplash.com") }) {
                quality.realImagesCount += 1
            }
            
            // Check for complete data
            if !property.description.isEmpty && 
               property.price > 0 && 
               property.bedrooms > 0 && 
               !property.city.isEmpty {
                quality.completeDataCount += 1
            }
            
            // Check for realistic prices (basic validation)
            if property.price >= 500 && property.price <= 10000 {
                quality.realisticPriceCount += 1
            }
            
            // Check for location data
            if let lat = property.latitude, let lng = property.longitude,
               lat != 0.0 && lng != 0.0 {
                quality.hasLocationCount += 1
            }
        }
        
        return quality
    }
    
    // MARK: - API Health Check
    func performHealthCheck() async -> APIHealthStatus {
        let isSupabaseHealthy = await SupabaseService.shared.validateConnection()
        
        var status = APIHealthStatus()
        status.supabaseStatus = isSupabaseHealthy ? .healthy : .unhealthy
        
        // Test a simple fetch to validate data quality
        do {
            var testFilters = SupabaseSearchFilters()
            testFilters.limit = 5
            let testListings = try await SupabaseService.shared.fetchListings(filters: testFilters)
            
            if testListings.count > 0 {
                status.dataQuality = .good
                print("✅ Data quality check passed - found \(testListings.count) listings")
            } else {
                status.dataQuality = .poor
                print("⚠️ Data quality check warning - no listings found")
            }
        } catch {
            status.dataQuality = .poor
            print("❌ Data quality check failed: \(error)")
        }
        
        status.overallHealth = (status.supabaseStatus == .healthy && status.dataQuality == .good) ? .healthy : .degraded
        
        return status
    }
    
    // MARK: - Error Recovery
    func suggestErrorRecovery(for error: Error) -> ErrorRecoveryAction {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidURL:
                return .retryWithFallback("Invalid URL - using sample data")
            case .noData:
                return .retryWithFallback("No data received - using sample data")
            case .unauthorized:
                return .requireAuth("Authentication required")
            case .serverError(let code):
                if code >= 500 {
                    return .retryLater("Server error - try again later")
                } else {
                    return .retryWithFallback("Client error - using sample data")
                }
            case .custom(let message):
                return .retryWithFallback(message)
            case .invalidResponse:
                return .retryWithFallback("Invalid response - using sample data")
            }
        }
        
        return .retryWithFallback("Unknown error - using sample data")
    }
}

// MARK: - Data Models
struct PropertyDataQuality {
    var totalCount = 0
    var realImagesCount = 0
    var completeDataCount = 0
    var realisticPriceCount = 0
    var hasLocationCount = 0
    
    var imageQuality: Double {
        guard totalCount > 0 else { return 0 }
        return Double(realImagesCount) / Double(totalCount)
    }
    
    var dataCompleteness: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completeDataCount) / Double(totalCount)
    }
    
    var priceRealism: Double {
        guard totalCount > 0 else { return 0 }
        return Double(realisticPriceCount) / Double(totalCount)
    }
    
    var locationCoverage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(hasLocationCount) / Double(totalCount)
    }
    
    var overallQuality: Double {
        return (imageQuality + dataCompleteness + priceRealism + locationCoverage) / 4.0
    }
}

struct APIHealthStatus {
    var supabaseStatus: ServiceStatus = .unknown
    var dataQuality: DataQuality = .unknown
    var overallHealth: ServiceStatus = .unknown
}

enum ServiceStatus {
    case healthy
    case degraded
    case unhealthy
    case unknown
}

enum DataQuality {
    case excellent
    case good
    case fair
    case poor
    case unknown
}

enum ErrorRecoveryAction {
    case retry
    case retryLater(String)
    case retryWithFallback(String)
    case requireAuth(String)
}

// MARK: - Network Connectivity
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private init() {}
    
    func isConnectedToInternet() -> Bool {
        // Basic connectivity check
        guard let url = URL(string: "https://www.google.com") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        let semaphore = DispatchSemaphore(value: 0)
        var isConnected = false
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                isConnected = true
            }
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 5)
        return isConnected
    }
}

// MARK: - Performance Metrics
class PerformanceMetrics {
    static let shared = PerformanceMetrics()
    
    private var apiCallTimes: [String: TimeInterval] = [:]
    private var apiCallCounts: [String: Int] = [:]
    
    private init() {}
    
    func startTimer(for operation: String) -> Date {
        return Date()
    }
    
    func endTimer(for operation: String, startTime: Date) {
        let duration = Date().timeIntervalSince(startTime)
        apiCallTimes[operation] = duration
        apiCallCounts[operation, default: 0] += 1
        
        print("⏱️ \(operation) took \(String(format: "%.2f", duration))s")
    }
    
    func getAverageTime(for operation: String) -> TimeInterval? {
        return apiCallTimes[operation]
    }
    
    func getCallCount(for operation: String) -> Int {
        return apiCallCounts[operation, default: 0]
    }
    
    func logPerformanceSummary() {
        print("📊 Performance Summary:")
        for (operation, time) in apiCallTimes {
            let count = apiCallCounts[operation, default: 0]
            print("  \(operation): \(String(format: "%.2f", time))s (called \(count) times)")
        }
    }
}