import XCTest
import Network
import Combine
@testable import RoomFinderAI

class NetworkMonitoringServiceTests: XCTestCase {
    var networkMonitor: NetworkMonitoringService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        networkMonitor = NetworkMonitoringService.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Connection Type Tests
    
    func testConnectionTypeProperties() {
        // Given
        let connectionTypes = ConnectionType.allCases
        
        // When & Then
        for connectionType in connectionTypes {
            XCTAssertFalse(connectionType.displayName.isEmpty)
            XCTAssertFalse(connectionType.iconName.isEmpty)
            XCTAssertFalse(connectionType.rawValue.isEmpty)
        }
    }
    
    func testConnectionTypeDisplayNames() {
        // Given & When & Then
        XCTAssertEqual(ConnectionType.wifi.displayName, "Wi-Fi")
        XCTAssertEqual(ConnectionType.cellular.displayName, "Cellular")
        XCTAssertEqual(ConnectionType.ethernet.displayName, "Ethernet")
        XCTAssertEqual(ConnectionType.other.displayName, "Other")
        XCTAssertEqual(ConnectionType.unavailable.displayName, "Unavailable")
    }
    
    func testConnectionTypeIcons() {
        // Given & When & Then
        XCTAssertEqual(ConnectionType.wifi.iconName, "wifi")
        XCTAssertEqual(ConnectionType.cellular.iconName, "antenna.radiowaves.left.and.right")
        XCTAssertEqual(ConnectionType.ethernet.iconName, "ethernet")
        XCTAssertEqual(ConnectionType.other.iconName, "network")
        XCTAssertEqual(ConnectionType.unavailable.iconName, "wifi.slash")
    }
    
    // MARK: - Connection Quality Tests
    
    func testConnectionQualityProperties() {
        // Given
        let connectionQualities = ConnectionQuality.allCases
        
        // When & Then
        for quality in connectionQualities {
            XCTAssertFalse(quality.displayName.isEmpty)
            XCTAssertFalse(quality.color.isEmpty)
            XCTAssertFalse(quality.rawValue.isEmpty)
        }
    }
    
    func testConnectionQualityDisplayNames() {
        // Given & When & Then
        XCTAssertEqual(ConnectionQuality.unknown.displayName, "Unknown")
        XCTAssertEqual(ConnectionQuality.poor.displayName, "Poor")
        XCTAssertEqual(ConnectionQuality.fair.displayName, "Fair")
        XCTAssertEqual(ConnectionQuality.good.displayName, "Good")
        XCTAssertEqual(ConnectionQuality.excellent.displayName, "Excellent")
    }
    
    func testConnectionQualityColors() {
        // Given & When & Then
        XCTAssertEqual(ConnectionQuality.unknown.color, "gray")
        XCTAssertEqual(ConnectionQuality.poor.color, "red")
        XCTAssertEqual(ConnectionQuality.fair.color, "orange")
        XCTAssertEqual(ConnectionQuality.good.color, "yellow")
        XCTAssertEqual(ConnectionQuality.excellent.color, "green")
    }
    
    // MARK: - Speed Test Result Tests
    
    func testSpeedTestResultCalculations() {
        // Given
        let bytesTransferred = 1024 * 1024 // 1MB
        let duration: TimeInterval = 1.0 // 1 second
        let connectionType = ConnectionType.wifi
        
        // When
        let speedResult = SpeedTestResult(
            timestamp: Date(),
            duration: duration,
            bytesTransferred: bytesTransferred,
            connectionType: connectionType
        )
        
        // Then
        XCTAssertEqual(speedResult.speedMbps, 8.0, accuracy: 0.1) // 1MB/s = 8 Mbps
        XCTAssertEqual(speedResult.speedKbps, 8000.0, accuracy: 0.1)
        XCTAssertEqual(speedResult.connectionType, connectionType)
    }
    
    func testSpeedTestResultZeroDuration() {
        // Given
        let bytesTransferred = 1024
        let duration: TimeInterval = 0
        
        // When
        let speedResult = SpeedTestResult(
            timestamp: Date(),
            duration: duration,
            bytesTransferred: bytesTransferred,
            connectionType: .wifi
        )
        
        // Then
        XCTAssertEqual(speedResult.speedMbps, 0)
        XCTAssertEqual(speedResult.speedKbps, 0)
    }
    
    func testSpeedTestResultVariousValues() {
        // Given
        let testCases = [
            (bytes: 512, duration: 0.5, expectedMbps: 8.0),
            (bytes: 1024, duration: 2.0, expectedMbps: 4.0),
            (bytes: 2048, duration: 1.0, expectedMbps: 16.0)
        ]
        
        // When & Then
        for testCase in testCases {
            let speedResult = SpeedTestResult(
                timestamp: Date(),
                duration: testCase.duration,
                bytesTransferred: testCase.bytes,
                connectionType: .wifi
            )
            
            XCTAssertEqual(
                speedResult.speedMbps,
                testCase.expectedMbps,
                accuracy: 0.1,
                "Failed for bytes: \(testCase.bytes), duration: \(testCase.duration)"
            )
        }
    }
    
    // MARK: - Network Statistics Tests
    
    func testNetworkStatisticsInitialization() {
        // Given
        let statistics = NetworkStatistics()
        
        // When & Then
        XCTAssertEqual(statistics.connectionChanges, 0)
        XCTAssertEqual(statistics.totalUptime, 0)
        XCTAssertEqual(statistics.totalDowntime, 0)
        XCTAssertNil(statistics.lastConnectionTime)
        XCTAssertNil(statistics.lastDisconnectionTime)
        XCTAssertEqual(statistics.averageSpeedMbps, 0)
        XCTAssertEqual(statistics.bestSpeedMbps, 0)
        XCTAssertEqual(statistics.worstSpeedMbps, 0)
        XCTAssertEqual(statistics.totalSpeedTests, 0)
        XCTAssertEqual(statistics.uptimePercentage, 0)
    }
    
    func testNetworkStatisticsConnectionChange() {
        // Given
        var statistics = NetworkStatistics()
        let connectionTime = Date()
        let disconnectionTime = connectionTime.addingTimeInterval(60) // 1 minute later
        
        // When
        statistics.updateConnectionChange(isConnected: true, connectionType: .wifi, timestamp: connectionTime)
        statistics.updateConnectionChange(isConnected: false, connectionType: .wifi, timestamp: disconnectionTime)
        
        // Then
        XCTAssertEqual(statistics.connectionChanges, 2)
        XCTAssertEqual(statistics.totalUptime, 60, accuracy: 0.1)
        XCTAssertEqual(statistics.wifiConnectionTime, 60, accuracy: 0.1)
        XCTAssertEqual(statistics.lastConnectionTime, connectionTime)
        XCTAssertEqual(statistics.lastDisconnectionTime, disconnectionTime)
    }
    
    func testNetworkStatisticsSpeedTest() {
        // Given
        var statistics = NetworkStatistics()
        let speedResult1 = SpeedTestResult(timestamp: Date(), duration: 1.0, bytesTransferred: 1024, connectionType: .wifi)
        let speedResult2 = SpeedTestResult(timestamp: Date(), duration: 1.0, bytesTransferred: 2048, connectionType: .wifi)
        
        // When
        statistics.updateSpeedTest(result: speedResult1, averageSpeed: speedResult1.speedMbps)
        statistics.updateSpeedTest(result: speedResult2, averageSpeed: (speedResult1.speedMbps + speedResult2.speedMbps) / 2)
        
        // Then
        XCTAssertEqual(statistics.totalSpeedTests, 2)
        XCTAssertEqual(statistics.bestSpeedMbps, speedResult2.speedMbps, accuracy: 0.1)
        XCTAssertEqual(statistics.worstSpeedMbps, speedResult1.speedMbps, accuracy: 0.1)
        XCTAssertEqual(statistics.averageSpeedMbps, (speedResult1.speedMbps + speedResult2.speedMbps) / 2, accuracy: 0.1)
    }
    
    func testNetworkStatisticsUptimePercentage() {
        // Given
        var statistics = NetworkStatistics()
        statistics.totalUptime = 80
        statistics.totalDowntime = 20
        
        // When
        let uptimePercentage = statistics.uptimePercentage
        
        // Then
        XCTAssertEqual(uptimePercentage, 80.0, accuracy: 0.1)
    }
    
    func testNetworkStatisticsUptimePercentageZeroTotal() {
        // Given
        var statistics = NetworkStatistics()
        statistics.totalUptime = 0
        statistics.totalDowntime = 0
        
        // When
        let uptimePercentage = statistics.uptimePercentage
        
        // Then
        XCTAssertEqual(uptimePercentage, 0.0)
    }
    
    // MARK: - Network Monitoring Service Tests
    
    func testNetworkMonitoringServiceInitialization() {
        // Given & When
        let monitor = NetworkMonitoringService.shared
        
        // Then
        XCTAssertNotNil(monitor)
        XCTAssertEqual(monitor.connectionType, .unavailable)
        XCTAssertEqual(monitor.connectionQuality, .unknown)
        XCTAssertFalse(monitor.isExpensive)
        XCTAssertFalse(monitor.isConstrained)
    }
    
    func testUtilityMethods() {
        // Given
        let monitor = NetworkMonitoringService.shared
        
        // When - Test WiFi methods
        monitor.isConnected = true
        monitor.connectionType = .wifi
        monitor.connectionQuality = .good
        monitor.isExpensive = false
        monitor.isConstrained = false
        
        // Then
        XCTAssertTrue(monitor.isWiFiAvailable())
        XCTAssertFalse(monitor.isCellularAvailable())
        XCTAssertFalse(monitor.shouldUseDataSaver())
        XCTAssertFalse(monitor.getConnectionDescription().isEmpty)
        XCTAssertTrue(monitor.getConnectionDescription().contains("Wi-Fi"))
    }
    
    func testUtilityMethodsWithExpensiveConnection() {
        // Given
        let monitor = NetworkMonitoringService.shared
        
        // When
        monitor.isConnected = true
        monitor.connectionType = .cellular
        monitor.connectionQuality = .poor
        monitor.isExpensive = true
        monitor.isConstrained = true
        
        // Then
        XCTAssertFalse(monitor.isWiFiAvailable())
        XCTAssertTrue(monitor.isCellularAvailable())
        XCTAssertTrue(monitor.shouldUseDataSaver())
        XCTAssertTrue(monitor.getConnectionDescription().contains("Cellular"))
        XCTAssertTrue(monitor.getConnectionDescription().contains("Expensive"))
        XCTAssertTrue(monitor.getConnectionDescription().contains("Constrained"))
    }
    
    func testConnectionDescription() {
        // Given
        let monitor = NetworkMonitoringService.shared
        
        // When
        monitor.connectionType = .wifi
        monitor.connectionQuality = .excellent
        monitor.isExpensive = false
        monitor.isConstrained = false
        
        let description = monitor.getConnectionDescription()
        
        // Then
        XCTAssertTrue(description.contains("Wi-Fi"))
        XCTAssertTrue(description.contains("Excellent"))
        XCTAssertFalse(description.contains("Expensive"))
        XCTAssertFalse(description.contains("Constrained"))
    }
    
    func testConnectionDescriptionWithFlags() {
        // Given
        let monitor = NetworkMonitoringService.shared
        
        // When
        monitor.connectionType = .cellular
        monitor.connectionQuality = .fair
        monitor.isExpensive = true
        monitor.isConstrained = true
        
        let description = monitor.getConnectionDescription()
        
        // Then
        XCTAssertTrue(description.contains("Cellular"))
        XCTAssertTrue(description.contains("Fair"))
        XCTAssertTrue(description.contains("Expensive"))
        XCTAssertTrue(description.contains("Constrained"))
    }
    
    // MARK: - Network Status Change Tests
    
    func testNetworkStatusChangeNotification() {
        // Given
        let expectation = XCTestExpectation(description: "Network status change notification")
        var receivedNotification = false
        
        NotificationCenter.default.addObserver(
            forName: .networkStatusChanged,
            object: nil,
            queue: .main
        ) { notification in
            receivedNotification = true
            expectation.fulfill()
        }
        
        // When
        NotificationCenter.default.post(
            name: .networkStatusChanged,
            object: networkMonitor,
            userInfo: [
                "isConnected": true,
                "connectionType": ConnectionType.wifi.rawValue
            ]
        )
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedNotification)
    }
    
    // MARK: - Reactive Properties Tests
    
    func testReactiveProperties() {
        // Given
        let expectation = XCTestExpectation(description: "Reactive property change")
        var receivedValue: Bool?
        
        networkMonitor.$isConnected
            .sink { isConnected in
                receivedValue = isConnected
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        DispatchQueue.main.async {
            // This would typically be updated by the actual network monitoring
            // For testing, we just verify the reactive property works
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedValue)
    }
    
    // MARK: - Reset Statistics Tests
    
    func testResetStatistics() {
        // Given
        let monitor = NetworkMonitoringService.shared
        
        // Simulate some network activity
        monitor.networkStatistics.connectionChanges = 5
        monitor.networkStatistics.totalUptime = 100
        monitor.networkStatistics.totalDowntime = 20
        monitor.networkStatistics.averageSpeedMbps = 10.0
        monitor.networkStatistics.totalSpeedTests = 3
        
        // When
        monitor.resetStatistics()
        
        // Then
        XCTAssertEqual(monitor.networkStatistics.connectionChanges, 0)
        XCTAssertEqual(monitor.networkStatistics.totalUptime, 0)
        XCTAssertEqual(monitor.networkStatistics.totalDowntime, 0)
        XCTAssertEqual(monitor.networkStatistics.averageSpeedMbps, 0)
        XCTAssertEqual(monitor.networkStatistics.totalSpeedTests, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testConnectionTypeEdgeCases() {
        // Given
        let allTypes = ConnectionType.allCases
        
        // When & Then
        for connectionType in allTypes {
            XCTAssertNotNil(connectionType.displayName)
            XCTAssertNotNil(connectionType.iconName)
            XCTAssertNotNil(connectionType.rawValue)
            XCTAssertFalse(connectionType.displayName.isEmpty)
            XCTAssertFalse(connectionType.iconName.isEmpty)
            XCTAssertFalse(connectionType.rawValue.isEmpty)
        }
    }
    
    func testConnectionQualityEdgeCases() {
        // Given
        let allQualities = ConnectionQuality.allCases
        
        // When & Then
        for quality in allQualities {
            XCTAssertNotNil(quality.displayName)
            XCTAssertNotNil(quality.color)
            XCTAssertNotNil(quality.rawValue)
            XCTAssertFalse(quality.displayName.isEmpty)
            XCTAssertFalse(quality.color.isEmpty)
            XCTAssertFalse(quality.rawValue.isEmpty)
        }
    }
    
    func testSpeedTestResultEdgeCases() {
        // Given
        let zeroBytes = SpeedTestResult(timestamp: Date(), duration: 1.0, bytesTransferred: 0, connectionType: .wifi)
        let negativeDuration = SpeedTestResult(timestamp: Date(), duration: -1.0, bytesTransferred: 1024, connectionType: .wifi)
        
        // When & Then
        XCTAssertEqual(zeroBytes.speedMbps, 0.0)
        XCTAssertEqual(zeroBytes.speedKbps, 0.0)
        
        XCTAssertEqual(negativeDuration.speedMbps, 0.0)
        XCTAssertEqual(negativeDuration.speedKbps, 0.0)
    }
}