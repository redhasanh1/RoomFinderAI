import Foundation
import Network
import Combine
import SystemConfiguration

// MARK: - Network Monitoring Service
class NetworkMonitoringService: ObservableObject {
    static let shared = NetworkMonitoringService()
    
    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var connectionType: ConnectionType = .unavailable
    @Published var connectionQuality: ConnectionQuality = .unknown
    @Published var isExpensive: Bool = false
    @Published var isConstrained: Bool = false
    @Published var networkStatistics: NetworkStatistics = NetworkStatistics()
    
    // MARK: - Private Properties
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitoringService", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // Network quality testing
    private var qualityTestTimer: Timer?
    private var speedTestResults: [SpeedTestResult] = []
    private let maxSpeedTestResults = 10
    
    // Network reachability
    private var reachability: SCNetworkReachability?
    
    // MARK: - Initialization
    private init() {
        setupNetworkMonitoring()
        setupQualityMonitoring()
        setupReachabilityMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Setup Methods
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path: path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func setupQualityMonitoring() {
        // Test network quality every 30 seconds when connected
        qualityTestTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            if self?.isConnected == true {
                self?.testNetworkQuality()
            }
        }
    }
    
    private func setupReachabilityMonitoring() {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        reachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }
        
        if let reachability = reachability {
            var context = SCNetworkReachabilityContext()
            context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            
            let callback: SCNetworkReachabilityCallBack = { (reachability, flags, info) in
                guard let info = info else { return }
                let instance = Unmanaged<NetworkMonitoringService>.fromOpaque(info).takeUnretainedValue()
                instance.updateReachabilityStatus(flags: flags)
            }
            
            SCNetworkReachabilitySetCallback(reachability, callback, &context)
            SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        }
    }
    
    // MARK: - Network Status Updates
    private func updateNetworkStatus(path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        // Determine connection type
        connectionType = determineConnectionType(path: path)
        
        // Update statistics
        networkStatistics.updateConnectionChange(
            isConnected: isConnected,
            connectionType: connectionType,
            timestamp: Date()
        )
        
        // Log network change
        LoggingService.shared.info(
            "Network status changed: \(connectionType.displayName) - \(isConnected ? "Connected" : "Disconnected")",
            category: .network,
            metadata: [
                "connectionType": connectionType.rawValue,
                "isExpensive": isExpensive,
                "isConstrained": isConstrained,
                "wasConnected": wasConnected
            ]
        )
        
        // Post notifications
        if wasConnected != isConnected {
            NotificationCenter.default.post(
                name: .networkStatusChanged,
                object: self,
                userInfo: [
                    "isConnected": isConnected,
                    "connectionType": connectionType.rawValue
                ]
            )
        }
    }
    
    private func updateReachabilityStatus(flags: SCNetworkReachabilityFlags) {
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let isConnectedViaWiFi = flags.contains(.isWWAN) == false
        
        DispatchQueue.main.async { [weak self] in
            self?.networkStatistics.updateReachabilityFlags(flags: flags)
        }
    }
    
    private func determineConnectionType(path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.other) {
            return .other
        } else {
            return .unavailable
        }
    }
    
    // MARK: - Network Quality Testing
    private func testNetworkQuality() {
        Task {
            await performSpeedTest()
        }
    }
    
    private func performSpeedTest() async {
        let startTime = Date()
        
        do {
            // Test with a small file download
            let testURL = URL(string: "https://httpbin.org/bytes/1024")!
            let (data, response) = try await URLSession.shared.data(from: testURL)
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            let bytesTransferred = data.count
            
            let speedResult = SpeedTestResult(
                timestamp: startTime,
                duration: duration,
                bytesTransferred: bytesTransferred,
                connectionType: connectionType
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.processSpeedTestResult(speedResult)
            }
            
        } catch {
            LoggingService.shared.error(
                "Network speed test failed: \(error.localizedDescription)",
                category: .network
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.connectionQuality = .poor
            }
        }
    }
    
    private func processSpeedTestResult(_ result: SpeedTestResult) {
        speedTestResults.append(result)
        
        // Keep only the last N results
        if speedTestResults.count > maxSpeedTestResults {
            speedTestResults.removeFirst()
        }
        
        // Calculate average speed
        let averageSpeed = speedTestResults.map { $0.speedMbps }.reduce(0, +) / Double(speedTestResults.count)
        
        // Determine quality based on average speed
        connectionQuality = determineConnectionQuality(speedMbps: averageSpeed)
        
        // Update statistics
        networkStatistics.updateSpeedTest(result: result, averageSpeed: averageSpeed)
        
        LoggingService.shared.info(
            "Network speed test completed: \(String(format: "%.2f", averageSpeed)) Mbps",
            category: .network,
            metadata: [
                "speedMbps": averageSpeed,
                "quality": connectionQuality.rawValue,
                "duration": result.duration
            ]
        )
    }
    
    private func determineConnectionQuality(speedMbps: Double) -> ConnectionQuality {
        switch speedMbps {
        case 0..<1:
            return .poor
        case 1..<5:
            return .fair
        case 5..<25:
            return .good
        case 25...:
            return .excellent
        default:
            return .unknown
        }
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        guard !monitor.queue.isSuspended else { return }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
        qualityTestTimer?.invalidate()
        qualityTestTimer = nil
        
        if let reachability = reachability {
            SCNetworkReachabilityUnscheduleFromRunLoop(reachability, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        }
    }
    
    func forceQualityTest() {
        testNetworkQuality()
    }
    
    func resetStatistics() {
        networkStatistics = NetworkStatistics()
        speedTestResults.removeAll()
    }
    
    // MARK: - Utility Methods
    func isWiFiAvailable() -> Bool {
        return isConnected && connectionType == .wifi
    }
    
    func isCellularAvailable() -> Bool {
        return isConnected && connectionType == .cellular
    }
    
    func shouldUseDataSaver() -> Bool {
        return isExpensive || isConstrained || connectionQuality == .poor
    }
    
    func getConnectionDescription() -> String {
        var description = connectionType.displayName
        
        if isExpensive {
            description += " (Expensive)"
        }
        
        if isConstrained {
            description += " (Constrained)"
        }
        
        if connectionQuality != .unknown {
            description += " - \(connectionQuality.displayName)"
        }
        
        return description
    }
}

// MARK: - Connection Type
enum ConnectionType: String, CaseIterable {
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
    case other = "other"
    case unavailable = "unavailable"
    
    var displayName: String {
        switch self {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .other:
            return "Other"
        case .unavailable:
            return "Unavailable"
        }
    }
    
    var iconName: String {
        switch self {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .ethernet:
            return "ethernet"
        case .other:
            return "network"
        case .unavailable:
            return "wifi.slash"
        }
    }
}

// MARK: - Connection Quality
enum ConnectionQuality: String, CaseIterable {
    case unknown = "unknown"
    case poor = "poor"
    case fair = "fair"
    case good = "good"
    case excellent = "excellent"
    
    var displayName: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .poor:
            return "Poor"
        case .fair:
            return "Fair"
        case .good:
            return "Good"
        case .excellent:
            return "Excellent"
        }
    }
    
    var color: String {
        switch self {
        case .unknown:
            return "gray"
        case .poor:
            return "red"
        case .fair:
            return "orange"
        case .good:
            return "yellow"
        case .excellent:
            return "green"
        }
    }
}

// MARK: - Speed Test Result
struct SpeedTestResult {
    let timestamp: Date
    let duration: TimeInterval
    let bytesTransferred: Int
    let connectionType: ConnectionType
    
    var speedMbps: Double {
        guard duration > 0 else { return 0 }
        let bytesPerSecond = Double(bytesTransferred) / duration
        return (bytesPerSecond * 8) / 1_000_000 // Convert to Mbps
    }
    
    var speedKbps: Double {
        return speedMbps * 1000
    }
}

// MARK: - Network Statistics
struct NetworkStatistics {
    var connectionChanges: Int = 0
    var totalUptime: TimeInterval = 0
    var totalDowntime: TimeInterval = 0
    var lastConnectionTime: Date?
    var lastDisconnectionTime: Date?
    
    var averageSpeedMbps: Double = 0
    var bestSpeedMbps: Double = 0
    var worstSpeedMbps: Double = 0
    var totalSpeedTests: Int = 0
    
    var wifiConnectionTime: TimeInterval = 0
    var cellularConnectionTime: TimeInterval = 0
    var ethernetConnectionTime: TimeInterval = 0
    
    mutating func updateConnectionChange(isConnected: Bool, connectionType: ConnectionType, timestamp: Date) {
        connectionChanges += 1
        
        if isConnected {
            lastConnectionTime = timestamp
            if let lastDisconnection = lastDisconnectionTime {
                totalDowntime += timestamp.timeIntervalSince(lastDisconnection)
            }
        } else {
            lastDisconnectionTime = timestamp
            if let lastConnection = lastConnectionTime {
                let sessionDuration = timestamp.timeIntervalSince(lastConnection)
                totalUptime += sessionDuration
                
                // Track connection time by type
                switch connectionType {
                case .wifi:
                    wifiConnectionTime += sessionDuration
                case .cellular:
                    cellularConnectionTime += sessionDuration
                case .ethernet:
                    ethernetConnectionTime += sessionDuration
                default:
                    break
                }
            }
        }
    }
    
    mutating func updateSpeedTest(result: SpeedTestResult, averageSpeed: Double) {
        totalSpeedTests += 1
        averageSpeedMbps = averageSpeed
        
        if result.speedMbps > bestSpeedMbps {
            bestSpeedMbps = result.speedMbps
        }
        
        if worstSpeedMbps == 0 || result.speedMbps < worstSpeedMbps {
            worstSpeedMbps = result.speedMbps
        }
    }
    
    mutating func updateReachabilityFlags(flags: SCNetworkReachabilityFlags) {
        // Additional reachability-specific statistics can be added here
    }
    
    var uptimePercentage: Double {
        let total = totalUptime + totalDowntime
        guard total > 0 else { return 0 }
        return (totalUptime / total) * 100
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
    static let networkQualityChanged = Notification.Name("networkQualityChanged")
}