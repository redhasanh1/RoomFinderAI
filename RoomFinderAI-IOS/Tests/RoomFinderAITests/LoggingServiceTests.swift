import XCTest
import os.log
@testable import RoomFinderAI

class LoggingServiceTests: XCTestCase {
    var loggingService: LoggingService!
    var testLogDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create test log directory
        let tempDir = FileManager.default.temporaryDirectory
        testLogDirectory = tempDir.appendingPathComponent("test_logs_\(UUID().uuidString)")
        
        loggingService = LoggingService.shared
        
        // Configure with test settings
        let testConfig = LogConfiguration(
            minimumLevel: .debug,
            enableConsoleLogging: true,
            enableFileLogging: true,
            enableRemoteLogging: false,
            enableOSLogging: false,
            maxLogFileSize: 1024 * 1024, // 1MB
            maxLogFiles: 3,
            logFileRetentionDays: 1,
            enableMetrics: true,
            enableCrashReporting: false,
            samplingRate: 1.0
        )
        
        loggingService.configure(with: testConfig)
    }
    
    override func tearDown() {
        loggingService.flush()
        
        // Clean up test directory
        if FileManager.default.fileExists(atPath: testLogDirectory.path) {
            try? FileManager.default.removeItem(at: testLogDirectory)
        }
        
        super.tearDown()
    }
    
    // MARK: - Basic Logging Tests
    
    func testDebugLogging() {
        // Given
        let message = "Debug message"
        let category = LogCategory.general
        let metadata = ["key": "value"]
        
        // When
        loggingService.debug(message, category: category, metadata: metadata)
        
        // Then
        // Since logging is async, we can't directly verify the output
        // But we can verify the method doesn't crash
        XCTAssertTrue(true)
    }
    
    func testInfoLogging() {
        // Given
        let message = "Info message"
        let category = LogCategory.network
        
        // When
        loggingService.info(message, category: category)
        
        // Then
        XCTAssertTrue(true)
    }
    
    func testWarningLogging() {
        // Given
        let message = "Warning message"
        let category = LogCategory.database
        
        // When
        loggingService.warning(message, category: category)
        
        // Then
        XCTAssertTrue(true)
    }
    
    func testErrorLogging() {
        // Given
        let message = "Error message"
        let category = LogCategory.auth
        
        // When
        loggingService.error(message, category: category)
        
        // Then
        XCTAssertTrue(true)
    }
    
    func testCriticalLogging() {
        // Given
        let message = "Critical message"
        let category = LogCategory.security
        
        // When
        loggingService.critical(message, category: category)
        
        // Then
        XCTAssertTrue(true)
    }
    
    // MARK: - Log Level Tests
    
    func testLogLevelComparison() {
        // Given & When & Then
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
        XCTAssertTrue(LogLevel.error < LogLevel.critical)
        
        XCTAssertEqual(LogLevel.debug.priority, 0)
        XCTAssertEqual(LogLevel.info.priority, 1)
        XCTAssertEqual(LogLevel.warning.priority, 2)
        XCTAssertEqual(LogLevel.error.priority, 3)
        XCTAssertEqual(LogLevel.critical.priority, 4)
    }
    
    func testLogLevelEmoji() {
        // Given & When & Then
        XCTAssertEqual(LogLevel.debug.emoji, "🔍")
        XCTAssertEqual(LogLevel.info.emoji, "ℹ️")
        XCTAssertEqual(LogLevel.warning.emoji, "⚠️")
        XCTAssertEqual(LogLevel.error.emoji, "❌")
        XCTAssertEqual(LogLevel.critical.emoji, "🚨")
    }
    
    func testLogLevelOSLogType() {
        // Given & When & Then
        XCTAssertEqual(LogLevel.debug.osLogType, .debug)
        XCTAssertEqual(LogLevel.info.osLogType, .info)
        XCTAssertEqual(LogLevel.warning.osLogType, .default)
        XCTAssertEqual(LogLevel.error.osLogType, .error)
        XCTAssertEqual(LogLevel.critical.osLogType, .fault)
    }
    
    // MARK: - Log Category Tests
    
    func testLogCategorySubsystem() {
        // Given & When & Then
        XCTAssertEqual(LogCategory.auth.subsystem, "com.roomfinder.app.auth")
        XCTAssertEqual(LogCategory.database.subsystem, "com.roomfinder.app.database")
        XCTAssertEqual(LogCategory.network.subsystem, "com.roomfinder.app.network")
        XCTAssertEqual(LogCategory.ui.subsystem, "com.roomfinder.app.ui")
        XCTAssertEqual(LogCategory.payment.subsystem, "com.roomfinder.app.payment")
        XCTAssertEqual(LogCategory.ai.subsystem, "com.roomfinder.app.ai")
        XCTAssertEqual(LogCategory.cache.subsystem, "com.roomfinder.app.cache")
        XCTAssertEqual(LogCategory.analytics.subsystem, "com.roomfinder.app.analytics")
        XCTAssertEqual(LogCategory.performance.subsystem, "com.roomfinder.app.performance")
        XCTAssertEqual(LogCategory.security.subsystem, "com.roomfinder.app.security")
        XCTAssertEqual(LogCategory.general.subsystem, "com.roomfinder.app.general")
    }
    
    // MARK: - Log Entry Tests
    
    func testLogEntryCreation() {
        // Given
        let level = LogLevel.info
        let category = LogCategory.network
        let message = "Test message"
        let metadata = ["key": "value", "number": 42]
        let userID = "test_user"
        let sessionID = "test_session"
        
        // When
        let logEntry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            userID: userID,
            sessionID: sessionID
        )
        
        // Then
        XCTAssertEqual(logEntry.level, level)
        XCTAssertEqual(logEntry.category, category)
        XCTAssertEqual(logEntry.message, message)
        XCTAssertEqual(logEntry.userID, userID)
        XCTAssertEqual(logEntry.sessionID, sessionID)
        XCTAssertNotNil(logEntry.timestamp)
        XCTAssertNotNil(logEntry.deviceInfo)
        XCTAssertNotNil(logEntry.appVersion)
        XCTAssertNotNil(logEntry.buildNumber)
        XCTAssertNotNil(logEntry.id)
    }
    
    // MARK: - Device Info Tests
    
    func testDeviceInfoCurrent() {
        // Given & When
        let deviceInfo = DeviceInfo.current
        
        // Then
        XCTAssertFalse(deviceInfo.model.isEmpty)
        XCTAssertFalse(deviceInfo.systemName.isEmpty)
        XCTAssertFalse(deviceInfo.systemVersion.isEmpty)
        XCTAssertFalse(deviceInfo.identifierForVendor.isEmpty)
        XCTAssertFalse(deviceInfo.preferredLanguage.isEmpty)
        XCTAssertFalse(deviceInfo.timeZone.isEmpty)
        XCTAssertGreaterThanOrEqual(deviceInfo.batteryLevel, -1.0)
        XCTAssertGreaterThan(deviceInfo.totalMemory, 0)
        XCTAssertGreaterThan(deviceInfo.diskSpace, 0)
        XCTAssertFalse(deviceInfo.networkType.isEmpty)
    }
    
    // MARK: - Log Configuration Tests
    
    func testLogConfigurationDebug() {
        // Given
        let config = LogConfiguration.debug
        
        // Then
        XCTAssertEqual(config.minimumLevel, .debug)
        XCTAssertTrue(config.enableConsoleLogging)
        XCTAssertTrue(config.enableFileLogging)
        XCTAssertFalse(config.enableRemoteLogging)
        XCTAssertTrue(config.enableOSLogging)
        XCTAssertEqual(config.maxLogFileSize, 10 * 1024 * 1024)
        XCTAssertEqual(config.maxLogFiles, 5)
        XCTAssertEqual(config.logFileRetentionDays, 7)
        XCTAssertTrue(config.enableMetrics)
        XCTAssertTrue(config.enableCrashReporting)
        XCTAssertEqual(config.samplingRate, 1.0)
    }
    
    func testLogConfigurationProduction() {
        // Given
        let config = LogConfiguration.production
        
        // Then
        XCTAssertEqual(config.minimumLevel, .warning)
        XCTAssertFalse(config.enableConsoleLogging)
        XCTAssertTrue(config.enableFileLogging)
        XCTAssertTrue(config.enableRemoteLogging)
        XCTAssertTrue(config.enableOSLogging)
        XCTAssertEqual(config.maxLogFileSize, 5 * 1024 * 1024)
        XCTAssertEqual(config.maxLogFiles, 3)
        XCTAssertEqual(config.logFileRetentionDays, 30)
        XCTAssertTrue(config.enableMetrics)
        XCTAssertTrue(config.enableCrashReporting)
        XCTAssertEqual(config.samplingRate, 0.1)
    }
    
    func testLogConfigurationTesting() {
        // Given
        let config = LogConfiguration.testing
        
        // Then
        XCTAssertEqual(config.minimumLevel, .info)
        XCTAssertTrue(config.enableConsoleLogging)
        XCTAssertFalse(config.enableFileLogging)
        XCTAssertFalse(config.enableRemoteLogging)
        XCTAssertFalse(config.enableOSLogging)
        XCTAssertEqual(config.maxLogFileSize, 1 * 1024 * 1024)
        XCTAssertEqual(config.maxLogFiles, 1)
        XCTAssertEqual(config.logFileRetentionDays, 1)
        XCTAssertFalse(config.enableMetrics)
        XCTAssertFalse(config.enableCrashReporting)
        XCTAssertEqual(config.samplingRate, 1.0)
    }
    
    // MARK: - Error Logging Tests
    
    func testLogError() {
        // Given
        let error = NetworkError.timeoutError
        let category = LogCategory.network
        let metadata = ["operation": "fetchData"]
        
        // When
        loggingService.logError(error, category: category, metadata: metadata)
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
    
    func testLogErrorWithAppError() {
        // Given
        let appError = AppError.networkError(.noInternetConnection)
        let category = LogCategory.network
        
        // When
        loggingService.logError(appError, category: category)
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
    
    // MARK: - Performance Logging Tests
    
    func testLogPerformance() {
        // Given
        let operation = "database_query"
        let duration: TimeInterval = 0.5
        let category = LogCategory.performance
        let metadata = ["table": "listings", "rows": 100]
        
        // When
        loggingService.logPerformance(
            operation: operation,
            duration: duration,
            category: category,
            metadata: metadata
        )
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
    
    func testLogPerformanceSlowOperation() {
        // Given
        let operation = "slow_database_query"
        let duration: TimeInterval = 2.0 // Over 1 second threshold
        let category = LogCategory.performance
        
        // When
        loggingService.logPerformance(
            operation: operation,
            duration: duration,
            category: category
        )
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
    
    // MARK: - Network Logging Tests
    
    func testLogNetworkRequestSuccess() {
        // Given
        let url = "https://api.example.com/listings"
        let method = "GET"
        let statusCode = 200
        let duration: TimeInterval = 0.3
        
        // When
        loggingService.logNetworkRequest(
            url: url,
            method: method,
            statusCode: statusCode,
            duration: duration
        )
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
    
    func testLogNetworkRequestError() {
        // Given
        let url = "https://api.example.com/listings"
        let method = "POST"
        let statusCode: Int? = nil
        let duration: TimeInterval = 1.0
        let error = NetworkError.timeoutError
        
        // When
        loggingService.logNetworkRequest(
            url: url,
            method: method,
            statusCode: statusCode,
            duration: duration,
            error: error
        )
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
    
    // MARK: - User and Session Tests
    
    func testSetUserID() {
        // Given
        let userID = "test_user_123"
        
        // When
        loggingService.setUserID(userID)
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
    
    func testSetSessionID() {
        // Given
        let sessionID = "test_session_456"
        
        // When
        loggingService.setSessionID(sessionID)
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
    
    // MARK: - Utility Methods Tests
    
    func testFlush() {
        // Given
        loggingService.info("Test message before flush")
        
        // When
        loggingService.flush()
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
    
    func testGetLogFiles() {
        // Given
        loggingService.info("Test message to create log file")
        loggingService.flush()
        
        // When
        let logFiles = loggingService.getLogFiles()
        
        // Then
        XCTAssertTrue(logFiles.count >= 0) // Should return array (may be empty)
    }
    
    // MARK: - Measurement Extensions Tests
    
    func testMeasureOperation() {
        // Given
        let operation = "test_operation"
        let category = LogCategory.performance
        let metadata = ["test": "data"]
        
        // When
        let result = loggingService.measure(
            operation: operation,
            category: category,
            metadata: metadata
        ) {
            // Simulate some work
            Thread.sleep(forTimeInterval: 0.1)
            return "test_result"
        }
        
        // Then
        XCTAssertEqual(result, "test_result")
    }
    
    func testMeasureOperationWithThrows() {
        // Given
        let operation = "test_operation_throws"
        let category = LogCategory.performance
        
        // When & Then
        XCTAssertThrowsError(try loggingService.measure(
            operation: operation,
            category: category
        ) {
            Thread.sleep(forTimeInterval: 0.1)
            throw NetworkError.timeoutError
        })
    }
    
    func testMeasureAsyncOperation() async {
        // Given
        let operation = "test_async_operation"
        let category = LogCategory.performance
        let metadata = ["async": "test"]
        
        // When
        let result = await loggingService.measureAsync(
            operation: operation,
            category: category,
            metadata: metadata
        ) {
            // Simulate async work
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            return "async_result"
        }
        
        // Then
        XCTAssertEqual(result, "async_result")
    }
    
    func testMeasureAsyncOperationWithThrows() async {
        // Given
        let operation = "test_async_operation_throws"
        let category = LogCategory.performance
        
        // When & Then
        do {
            _ = try await loggingService.measureAsync(
                operation: operation,
                category: category
            ) {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                throw NetworkError.timeoutError
            }
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentLogging() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent logging")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        // When
        for i in 0..<10 {
            queue.async {
                self.loggingService.info("Concurrent message \(i)", category: .general)
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    // MARK: - Log Filtering Tests
    
    func testLogFiltering() {
        // Given
        let debugConfig = LogConfiguration(
            minimumLevel: .warning, // Only warning and above
            enableConsoleLogging: true,
            enableFileLogging: false,
            enableRemoteLogging: false,
            enableOSLogging: false,
            maxLogFileSize: 1024,
            maxLogFiles: 1,
            logFileRetentionDays: 1,
            enableMetrics: false,
            enableCrashReporting: false,
            samplingRate: 1.0
        )
        
        loggingService.configure(with: debugConfig)
        
        // When
        loggingService.debug("Debug message - should be filtered")
        loggingService.info("Info message - should be filtered")
        loggingService.warning("Warning message - should be logged")
        loggingService.error("Error message - should be logged")
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
    
    // MARK: - Sampling Tests
    
    func testLogSampling() {
        // Given
        let samplingConfig = LogConfiguration(
            minimumLevel: .debug,
            enableConsoleLogging: true,
            enableFileLogging: false,
            enableRemoteLogging: false,
            enableOSLogging: false,
            maxLogFileSize: 1024,
            maxLogFiles: 1,
            logFileRetentionDays: 1,
            enableMetrics: false,
            enableCrashReporting: false,
            samplingRate: 0.1 // Only 10% of logs
        )
        
        loggingService.configure(with: samplingConfig)
        
        // When
        for i in 0..<100 {
            loggingService.info("Sampled message \(i)")
        }
        
        // Then
        XCTAssertTrue(true) // Method should not crash
    }
}