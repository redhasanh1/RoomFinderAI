import Foundation
import CoreData
import Combine
import UIKit

// MARK: - Database Performance Service
class DatabasePerformanceService: ObservableObject {
    static let shared = DatabasePerformanceService()
    
    // MARK: - Properties
    @Published var performanceMetrics: DatabasePerformanceMetrics = DatabasePerformanceMetrics()
    @Published var recentOperations: [DatabaseOperation] = []
    @Published var isMonitoring: Bool = false
    
    private let coreDataService = CoreDataService.shared
    private let loggingService = LoggingService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let maxRecentOperations = 100
    private let performanceThresholds = PerformanceThresholds()
    
    // MARK: - Initialization
    private init() {
        setupPerformanceMonitoring()
    }
    
    // MARK: - Setup
    private func setupPerformanceMonitoring() {
        // Monitor Core Data notifications
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCoreDataSave(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidMergeChanges,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCoreDataMerge(notification)
        }
    }
    
    // MARK: - Performance Testing
    
    func runFullPerformanceTest() async -> DatabasePerformanceReport {
        let report = DatabasePerformanceReport(
            testDate: Date(),
            deviceInfo: DeviceInfo.current
        )
        
        var testResults: [PerformanceTestResult] = []
        
        // Test 1: Single Insert Performance
        let singleInsertResult = await testSingleInsert()
        testResults.append(singleInsertResult)
        
        // Test 2: Batch Insert Performance
        let batchInsertResult = await testBatchInsert()
        testResults.append(batchInsertResult)
        
        // Test 3: Query Performance
        let queryResult = await testQueryPerformance()
        testResults.append(queryResult)
        
        // Test 4: Complex Query Performance
        let complexQueryResult = await testComplexQueryPerformance()
        testResults.append(complexQueryResult)
        
        // Test 5: Update Performance
        let updateResult = await testUpdatePerformance()
        testResults.append(updateResult)
        
        // Test 6: Delete Performance
        let deleteResult = await testDeletePerformance()
        testResults.append(deleteResult)
        
        // Test 7: Concurrent Operations
        let concurrentResult = await testConcurrentOperations()
        testResults.append(concurrentResult)
        
        // Test 8: Memory Usage
        let memoryResult = await testMemoryUsage()
        testResults.append(memoryResult)
        
        var finalReport = report
        finalReport.testResults = testResults
        finalReport.overallScore = calculateOverallScore(testResults)
        
        // Log performance report
        loggingService.info(
            "Database performance test completed",
            category: .performance,
            metadata: [
                "overallScore": finalReport.overallScore,
                "testCount": testResults.count,
                "deviceModel": DeviceInfo.current.model
            ]
        )
        
        return finalReport
    }
    
    // MARK: - Individual Performance Tests
    
    private func testSingleInsert() async -> PerformanceTestResult {
        let testName = "Single Insert Performance"
        let startTime = CFAbsoluteTimeGetCurrent()
        var operationCount = 0
        var errors: [Error] = []
        
        // Test inserting 100 single listings
        for i in 0..<100 {
            do {
                let testListing = createTestListing(id: "single_insert_\(i)")
                try await insertSingleListing(testListing)
                operationCount += 1
            } catch {
                errors.append(error)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return PerformanceTestResult(
            testName: testName,
            duration: duration,
            operationCount: operationCount,
            operationsPerSecond: Double(operationCount) / duration,
            averageOperationTime: duration / Double(operationCount),
            errors: errors,
            memoryUsage: getCurrentMemoryUsage(),
            passed: errors.isEmpty && duration < performanceThresholds.singleInsertThreshold
        )
    }
    
    private func testBatchInsert() async -> PerformanceTestResult {
        let testName = "Batch Insert Performance"
        let startTime = CFAbsoluteTimeGetCurrent()
        var operationCount = 0
        var errors: [Error] = []
        
        // Test batch inserting 1000 listings
        let batchSize = 100
        let numberOfBatches = 10
        
        for batch in 0..<numberOfBatches {
            do {
                let testListings = (0..<batchSize).map { i in
                    createTestListing(id: "batch_insert_\(batch)_\(i)")
                }
                
                try await insertBatchListings(testListings)
                operationCount += testListings.count
            } catch {
                errors.append(error)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return PerformanceTestResult(
            testName: testName,
            duration: duration,
            operationCount: operationCount,
            operationsPerSecond: Double(operationCount) / duration,
            averageOperationTime: duration / Double(operationCount),
            errors: errors,
            memoryUsage: getCurrentMemoryUsage(),
            passed: errors.isEmpty && duration < performanceThresholds.batchInsertThreshold
        )
    }
    
    private func testQueryPerformance() async -> PerformanceTestResult {
        let testName = "Query Performance"
        let startTime = CFAbsoluteTimeGetCurrent()
        var operationCount = 0
        var errors: [Error] = []
        
        // Test various query patterns
        let queryTests = [
            ("Simple Select", { try await self.queryAllListings() }),
            ("Filtered Select", { try await self.queryFilteredListings() }),
            ("Sorted Select", { try await self.querySortedListings() }),
            ("Limited Select", { try await self.queryLimitedListings() }),
            ("Count Query", { try await self.countListings() })
        ]
        
        for (queryName, queryOperation) in queryTests {
            do {
                _ = try await queryOperation()
                operationCount += 1
            } catch {
                errors.append(error)
                loggingService.error("Query failed: \(queryName) - \(error.localizedDescription)", category: .performance)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return PerformanceTestResult(
            testName: testName,
            duration: duration,
            operationCount: operationCount,
            operationsPerSecond: Double(operationCount) / duration,
            averageOperationTime: duration / Double(operationCount),
            errors: errors,
            memoryUsage: getCurrentMemoryUsage(),
            passed: errors.isEmpty && duration < performanceThresholds.queryThreshold
        )
    }
    
    private func testComplexQueryPerformance() async -> PerformanceTestResult {
        let testName = "Complex Query Performance"
        let startTime = CFAbsoluteTimeGetCurrent()
        var operationCount = 0
        var errors: [Error] = []
        
        // Test complex queries with joins, aggregations, etc.
        let complexQueries = [
            ("Price Range Query", { try await self.queryPriceRangeListings() }),
            ("Multi-Filter Query", { try await self.queryMultiFilterListings() }),
            ("Aggregate Query", { try await self.queryAggregateListings() }),
            ("Relationship Query", { try await self.queryWithRelationships() })
        ]
        
        for (queryName, queryOperation) in complexQueries {
            do {
                _ = try await queryOperation()
                operationCount += 1
            } catch {
                errors.append(error)
                loggingService.error("Complex query failed: \(queryName) - \(error.localizedDescription)", category: .performance)
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return PerformanceTestResult(
            testName: testName,
            duration: duration,
            operationCount: operationCount,
            operationsPerSecond: Double(operationCount) / duration,
            averageOperationTime: duration / Double(operationCount),
            errors: errors,
            memoryUsage: getCurrentMemoryUsage(),
            passed: errors.isEmpty && duration < performanceThresholds.complexQueryThreshold
        )
    }
    
    private func testUpdatePerformance() async -> PerformanceTestResult {
        let testName = "Update Performance"
        let startTime = CFAbsoluteTimeGetCurrent()
        var operationCount = 0
        var errors: [Error] = []
        
        // Test updating existing records
        do {
            let listings = try await queryLimitedListings()
            
            for listing in listings.prefix(50) {
                do {
                    try await updateListing(listing)
                    operationCount += 1
                } catch {
                    errors.append(error)
                }
            }
        } catch {
            errors.append(error)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return PerformanceTestResult(
            testName: testName,
            duration: duration,
            operationCount: operationCount,
            operationsPerSecond: Double(operationCount) / duration,
            averageOperationTime: duration / Double(operationCount),
            errors: errors,
            memoryUsage: getCurrentMemoryUsage(),
            passed: errors.isEmpty && duration < performanceThresholds.updateThreshold
        )
    }
    
    private func testDeletePerformance() async -> PerformanceTestResult {
        let testName = "Delete Performance"
        let startTime = CFAbsoluteTimeGetCurrent()
        var operationCount = 0
        var errors: [Error] = []
        
        // Test deleting records
        do {
            let listings = try await queryLimitedListings()
            
            for listing in listings.prefix(50) {
                do {
                    try await deleteListing(listing)
                    operationCount += 1
                } catch {
                    errors.append(error)
                }
            }
        } catch {
            errors.append(error)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return PerformanceTestResult(
            testName: testName,
            duration: duration,
            operationCount: operationCount,
            operationsPerSecond: Double(operationCount) / duration,
            averageOperationTime: duration / Double(operationCount),
            errors: errors,
            memoryUsage: getCurrentMemoryUsage(),
            passed: errors.isEmpty && duration < performanceThresholds.deleteThreshold
        )
    }
    
    private func testConcurrentOperations() async -> PerformanceTestResult {
        let testName = "Concurrent Operations"
        let startTime = CFAbsoluteTimeGetCurrent()
        var operationCount = 0
        var errors: [Error] = []
        
        // Test concurrent database operations
        await withTaskGroup(of: Result<Int, Error>.self) { group in
            // Add 10 concurrent tasks
            for i in 0..<10 {
                group.addTask {
                    do {
                        let testListing = self.createTestListing(id: "concurrent_\(i)")
                        try await self.insertSingleListing(testListing)
                        _ = try await self.queryAllListings()
                        return .success(1)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            for await result in group {
                switch result {
                case .success(let count):
                    operationCount += count
                case .failure(let error):
                    errors.append(error)
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return PerformanceTestResult(
            testName: testName,
            duration: duration,
            operationCount: operationCount,
            operationsPerSecond: Double(operationCount) / duration,
            averageOperationTime: duration / Double(operationCount),
            errors: errors,
            memoryUsage: getCurrentMemoryUsage(),
            passed: errors.isEmpty && duration < performanceThresholds.concurrentThreshold
        )
    }
    
    private func testMemoryUsage() async -> PerformanceTestResult {
        let testName = "Memory Usage Test"
        let startTime = CFAbsoluteTimeGetCurrent()
        let initialMemory = getCurrentMemoryUsage()
        
        // Perform memory-intensive operations
        var operationCount = 0
        var errors: [Error] = []
        
        do {
            // Load a large dataset
            let largeDataset = try await queryAllListings()
            operationCount += largeDataset.count
            
            // Perform operations on the dataset
            for _ in 0..<100 {
                _ = largeDataset.filter { $0.price > 1000 }
                _ = largeDataset.sorted { $0.price < $1.price }
                operationCount += 2
            }
        } catch {
            errors.append(error)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        let finalMemory = getCurrentMemoryUsage()
        let memoryDelta = finalMemory - initialMemory
        
        return PerformanceTestResult(
            testName: testName,
            duration: duration,
            operationCount: operationCount,
            operationsPerSecond: Double(operationCount) / duration,
            averageOperationTime: duration / Double(operationCount),
            errors: errors,
            memoryUsage: memoryDelta,
            passed: errors.isEmpty && memoryDelta < performanceThresholds.memoryThreshold
        )
    }
    
    // MARK: - Database Operations
    
    private func insertSingleListing(_ listing: Listing) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let cdListing = CDListing(context: context)
                cdListing.updateFromListing(listing)
                
                do {
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func insertBatchListings(_ listings: [Listing]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                for listing in listings {
                    let cdListing = CDListing(context: context)
                    cdListing.updateFromListing(listing)
                }
                
                do {
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func queryAllListings() async throws -> [Listing] {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                
                do {
                    let cdListings = try context.fetch(fetchRequest)
                    let listings = cdListings.map { $0.toListing() }
                    continuation.resume(returning: listings)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func queryFilteredListings() async throws -> [Listing] {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "price > %@ AND isActive == true", NSNumber(value: 1000))
                
                do {
                    let cdListings = try context.fetch(fetchRequest)
                    let listings = cdListings.map { $0.toListing() }
                    continuation.resume(returning: listings)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func querySortedListings() async throws -> [Listing] {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "price", ascending: true)]
                
                do {
                    let cdListings = try context.fetch(fetchRequest)
                    let listings = cdListings.map { $0.toListing() }
                    continuation.resume(returning: listings)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func queryLimitedListings() async throws -> [Listing] {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                fetchRequest.fetchLimit = 100
                
                do {
                    let cdListings = try context.fetch(fetchRequest)
                    let listings = cdListings.map { $0.toListing() }
                    continuation.resume(returning: listings)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func countListings() async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                
                do {
                    let count = try context.count(for: fetchRequest)
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func queryPriceRangeListings() async throws -> [Listing] {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "price BETWEEN %@", [1000, 3000])
                
                do {
                    let cdListings = try context.fetch(fetchRequest)
                    let listings = cdListings.map { $0.toListing() }
                    continuation.resume(returning: listings)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func queryMultiFilterListings() async throws -> [Listing] {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "price > %@ AND bedrooms >= %@ AND bathrooms >= %@ AND isActive == true", 
                                                   NSNumber(value: 1000), NSNumber(value: 2), NSNumber(value: 1))
                
                do {
                    let cdListings = try context.fetch(fetchRequest)
                    let listings = cdListings.map { $0.toListing() }
                    continuation.resume(returning: listings)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func queryAggregateListings() async throws -> [String: Any] {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "CDListing")
                fetchRequest.resultType = .dictionaryResultType
                fetchRequest.propertiesToFetch = [
                    "propertyType",
                    NSExpression(forFunction: "average:", arguments: [NSExpression(forKeyPath: "price")]),
                    NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "id")])
                ]
                fetchRequest.propertiesToGroupBy = ["propertyType"]
                
                do {
                    let results = try context.fetch(fetchRequest)
                    let aggregateResults = results.reduce(into: [String: Any]()) { dict, result in
                        if let resultDict = result as? [String: Any] {
                            dict.merge(resultDict) { _, new in new }
                        }
                    }
                    continuation.resume(returning: aggregateResults)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func queryWithRelationships() async throws -> [Listing] {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                fetchRequest.relationshipKeyPathsForPrefetching = ["owner", "images"]
                
                do {
                    let cdListings = try context.fetch(fetchRequest)
                    let listings = cdListings.map { $0.toListing() }
                    continuation.resume(returning: listings)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func updateListing(_ listing: Listing) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", listing.id)
                
                do {
                    let cdListings = try context.fetch(fetchRequest)
                    if let cdListing = cdListings.first {
                        cdListing.price = Double(listing.price + 100) // Update price
                        cdListing.updatedAt = Date()
                        try context.save()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func deleteListing(_ listing: Listing) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataService.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<CDListing> = CDListing.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", listing.id)
                
                do {
                    let cdListings = try context.fetch(fetchRequest)
                    if let cdListing = cdListings.first {
                        context.delete(cdListing)
                        try context.save()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Monitoring
    
    private func handleCoreDataSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        
        let insertedObjects = context.insertedObjects
        let updatedObjects = context.updatedObjects
        let deletedObjects = context.deletedObjects
        
        let operation = DatabaseOperation(
            type: .save,
            timestamp: Date(),
            duration: 0, // We don't have timing info from notification
            entityCounts: [
                "inserted": insertedObjects.count,
                "updated": updatedObjects.count,
                "deleted": deletedObjects.count
            ],
            success: true,
            error: nil
        )
        
        addRecentOperation(operation)
        updatePerformanceMetrics(operation)
    }
    
    private func handleCoreDataMerge(_ notification: Notification) {
        let operation = DatabaseOperation(
            type: .merge,
            timestamp: Date(),
            duration: 0,
            entityCounts: [:],
            success: true,
            error: nil
        )
        
        addRecentOperation(operation)
        updatePerformanceMetrics(operation)
    }
    
    private func addRecentOperation(_ operation: DatabaseOperation) {
        DispatchQueue.main.async {
            self.recentOperations.insert(operation, at: 0)
            if self.recentOperations.count > self.maxRecentOperations {
                self.recentOperations.removeLast()
            }
        }
    }
    
    private func updatePerformanceMetrics(_ operation: DatabaseOperation) {
        DispatchQueue.main.async {
            self.performanceMetrics.totalOperations += 1
            
            if operation.success {
                self.performanceMetrics.successfulOperations += 1
            } else {
                self.performanceMetrics.failedOperations += 1
            }
            
            self.performanceMetrics.averageOperationTime = 
                (self.performanceMetrics.averageOperationTime + operation.duration) / 2
            
            self.performanceMetrics.lastOperationTime = operation.timestamp
        }
    }
    
    // MARK: - Utilities
    
    private func createTestListing(id: String) -> Listing {
        return Listing(
            id: id,
            title: "Performance Test Listing \(id)",
            description: "Test listing for performance testing",
            price: Int.random(in: 1000...5000),
            city: "Test City",
            street: "123 Test St",
            postalCode: "12345",
            houseType: PropertyType.allCases.randomElement()?.rawValue ?? "apartment",
            bedrooms: Int.random(in: 1...4),
            utilities: "Heat, Water, Electricity",
            media: ["test-image.jpg"],
            userEmail: "test@example.com",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    private func calculateOverallScore(_ results: [PerformanceTestResult]) -> Double {
        let totalTests = results.count
        let passedTests = results.filter { $0.passed }.count
        let passRate = Double(passedTests) / Double(totalTests)
        
        let avgOperationsPerSecond = results.map { $0.operationsPerSecond }.reduce(0, +) / Double(totalTests)
        let avgOperationTime = results.map { $0.averageOperationTime }.reduce(0, +) / Double(totalTests)
        
        // Normalize scores (higher is better)
        let passRateScore = passRate * 100
        let operationsScore = min(avgOperationsPerSecond, 1000) / 10 // Cap at 1000 ops/sec
        let timeScore = max(0, 100 - (avgOperationTime * 1000)) // Lower time is better
        
        return (passRateScore + operationsScore + timeScore) / 3
    }
}

// MARK: - Performance Models

struct DatabasePerformanceMetrics {
    var totalOperations: Int = 0
    var successfulOperations: Int = 0
    var failedOperations: Int = 0
    var averageOperationTime: TimeInterval = 0
    var lastOperationTime: Date?
    
    var successRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(successfulOperations) / Double(totalOperations)
    }
    
    var failureRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(failedOperations) / Double(totalOperations)
    }
}

struct DatabaseOperation {
    let type: OperationType
    let timestamp: Date
    let duration: TimeInterval
    let entityCounts: [String: Int]
    let success: Bool
    let error: Error?
    
    enum OperationType {
        case insert
        case update
        case delete
        case select
        case save
        case merge
    }
}

struct PerformanceTestResult {
    let testName: String
    let duration: TimeInterval
    let operationCount: Int
    let operationsPerSecond: Double
    let averageOperationTime: TimeInterval
    let errors: [Error]
    let memoryUsage: Int64
    let passed: Bool
    
    var score: Double {
        let baseScore = passed ? 100 : 0
        let speedBonus = min(operationsPerSecond / 10, 50) // Up to 50 bonus points
        let penaltyForErrors = Double(errors.count) * 10
        
        return max(0, Double(baseScore) + speedBonus - penaltyForErrors)
    }
}

struct DatabasePerformanceReport {
    let testDate: Date
    let deviceInfo: DeviceInfo
    var testResults: [PerformanceTestResult] = []
    var overallScore: Double = 0
    
    var passedTests: Int {
        return testResults.filter { $0.passed }.count
    }
    
    var failedTests: Int {
        return testResults.filter { !$0.passed }.count
    }
    
    var totalErrors: Int {
        return testResults.reduce(0) { $0 + $1.errors.count }
    }
    
    var averageOperationsPerSecond: Double {
        guard !testResults.isEmpty else { return 0 }
        return testResults.map { $0.operationsPerSecond }.reduce(0, +) / Double(testResults.count)
    }
    
    var totalMemoryUsage: Int64 {
        return testResults.map { $0.memoryUsage }.reduce(0, +)
    }
}

struct PerformanceThresholds {
    let singleInsertThreshold: TimeInterval = 10.0 // 10 seconds for 100 inserts
    let batchInsertThreshold: TimeInterval = 5.0 // 5 seconds for 1000 inserts
    let queryThreshold: TimeInterval = 2.0 // 2 seconds for basic queries
    let complexQueryThreshold: TimeInterval = 5.0 // 5 seconds for complex queries
    let updateThreshold: TimeInterval = 5.0 // 5 seconds for 50 updates
    let deleteThreshold: TimeInterval = 5.0 // 5 seconds for 50 deletes
    let concurrentThreshold: TimeInterval = 10.0 // 10 seconds for concurrent operations
    let memoryThreshold: Int64 = 50 * 1024 * 1024 // 50MB memory increase
}

// MARK: - Device Info Extension

extension DeviceInfo {
    static var current: DeviceInfo {
        return DeviceInfo(
            model: UIDevice.current.model,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            identifierForVendor: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            preferredLanguage: Locale.current.languageCode ?? "en",
            timeZone: TimeZone.current.identifier,
            batteryLevel: UIDevice.current.batteryLevel,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            availableMemory: 0, // Will need a static method for this
            totalMemory: ProcessInfo.processInfo.physicalMemory,
            diskSpace: getDiskSpace(),
            networkType: getNetworkType()
        )
    }
    
    private static func getDiskSpace() -> UInt64 {
        guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return 0
        }
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            return attributes[.systemSize] as? UInt64 ?? 0
        } catch {
            return 0
        }
    }
    
    private static func getNetworkType() -> String {
        // This would typically use Network framework to determine connection type
        return "WiFi"
    }
}

// Required imports for mach task info
import Darwin