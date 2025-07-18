import Foundation
import os.log
import UIKit

// MARK: - Log Level
enum LogLevel: String, CaseIterable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.priority < rhs.priority
    }
}

// MARK: - Log Category
enum LogCategory: String, CaseIterable {
    case auth = "Auth"
    case database = "Database"
    case network = "Network"
    case ui = "UI"
    case payment = "Payment"
    case ai = "AI"
    case cache = "Cache"
    case analytics = "Analytics"
    case performance = "Performance"
    case security = "Security"
    case general = "General"
    
    var subsystem: String {
        return "com.roomfinder.app.\(self.rawValue.lowercased())"
    }
}

// MARK: - Log Entry
struct LogEntry {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let function: String
    let file: String
    let line: Int
    let metadata: [String: Any]
    let userID: String?
    let sessionID: String?
    let deviceInfo: DeviceInfo
    let appVersion: String
    let buildNumber: String
    
    init(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: Any] = [:],
        userID: String? = nil,
        sessionID: String? = nil,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.userID = userID
        self.sessionID = sessionID
        self.function = function
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.line = line
        self.deviceInfo = DeviceInfo.current
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - Device Info
struct DeviceInfo {
    let model: String
    let systemName: String
    let systemVersion: String
    let identifierForVendor: String
    let preferredLanguage: String
    let timeZone: String
    let batteryLevel: Float
    let isLowPowerModeEnabled: Bool
    let availableMemory: UInt64
    let totalMemory: UInt64
    let diskSpace: UInt64
    let networkType: String
    
    static var currentDevice: DeviceInfo {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo
        
        return DeviceInfo(
            model: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            identifierForVendor: device.identifierForVendor?.uuidString ?? "Unknown",
            preferredLanguage: Locale.preferredLanguages.first ?? "Unknown",
            timeZone: TimeZone.current.identifier,
            batteryLevel: device.batteryLevel,
            isLowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
            availableMemory: getAvailableMemory(),
            totalMemory: getTotalMemory(),
            diskSpace: getAvailableDiskSpace(),
            networkType: getNetworkType()
        )
    }
    
    private static func getAvailableMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
    
    private static func getTotalMemory() -> UInt64 {
        return UInt64(ProcessInfo.processInfo.physicalMemory)
    }
    
    private static func getAvailableDiskSpace() -> UInt64 {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            return attributes[.systemFreeSize] as? UInt64 ?? 0
        } catch {
            return 0
        }
    }
    
    private static func getNetworkType() -> String {
        // Simplified network type detection
        return "WiFi" // This would need proper network detection implementation
    }
}

// MARK: - Log Configuration
struct LogConfiguration {
    let minimumLevel: LogLevel
    let enableConsoleLogging: Bool
    let enableFileLogging: Bool
    let enableRemoteLogging: Bool
    let enableOSLogging: Bool
    let maxLogFileSize: UInt64
    let maxLogFiles: Int
    let logFileRetentionDays: Int
    let enableMetrics: Bool
    let enableCrashReporting: Bool
    let samplingRate: Double
    
    static let debug = LogConfiguration(
        minimumLevel: .debug,
        enableConsoleLogging: true,
        enableFileLogging: true,
        enableRemoteLogging: false,
        enableOSLogging: true,
        maxLogFileSize: 10 * 1024 * 1024, // 10 MB
        maxLogFiles: 5,
        logFileRetentionDays: 7,
        enableMetrics: true,
        enableCrashReporting: true,
        samplingRate: 1.0
    )
    
    static let production = LogConfiguration(
        minimumLevel: .warning,
        enableConsoleLogging: false,
        enableFileLogging: true,
        enableRemoteLogging: true,
        enableOSLogging: true,
        maxLogFileSize: 5 * 1024 * 1024, // 5 MB
        maxLogFiles: 3,
        logFileRetentionDays: 30,
        enableMetrics: true,
        enableCrashReporting: true,
        samplingRate: 0.1
    )
    
    static let testing = LogConfiguration(
        minimumLevel: .info,
        enableConsoleLogging: true,
        enableFileLogging: false,
        enableRemoteLogging: false,
        enableOSLogging: false,
        maxLogFileSize: 1 * 1024 * 1024, // 1 MB
        maxLogFiles: 1,
        logFileRetentionDays: 1,
        enableMetrics: false,
        enableCrashReporting: false,
        samplingRate: 1.0
    )
}

// MARK: - Log Destination
protocol LogDestination {
    func log(_ entry: LogEntry)
    func flush()
}

// MARK: - Console Log Destination
class ConsoleLogDestination: LogDestination {
    private let dateFormatter: DateFormatter
    
    init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    func log(_ entry: LogEntry) {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        let prefix = "[\(timestamp)] \(entry.level.emoji) \(entry.level.rawValue)"
        let location = "[\(entry.category.rawValue)] \(entry.file):\(entry.line) \(entry.function)"
        let message = entry.message
        
        var logString = "\(prefix) \(location)\n\(message)"
        
        if !entry.metadata.isEmpty {
            logString += "\nMetadata: \(entry.metadata)"
        }
        
        if let userID = entry.userID {
            logString += "\nUser: \(userID)"
        }
        
        if let sessionID = entry.sessionID {
            logString += "\nSession: \(sessionID)"
        }
        
        print(logString)
    }
    
    func flush() {
        // Console doesn't need flushing
    }
}

// MARK: - File Log Destination
class FileLogDestination: LogDestination {
    private let fileManager = FileManager.default
    private let configuration: LogConfiguration
    private let logDirectory: URL
    private let dateFormatter: DateFormatter
    private var currentLogFile: URL?
    private let queue = DispatchQueue(label: "com.roomfinder.logging.file", qos: .utility)
    
    init(configuration: LogConfiguration) {
        self.configuration = configuration
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Create logs directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.logDirectory = documentsPath.appendingPathComponent("logs")
        
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // Clean up old log files
        cleanupOldLogs()
        
        // Set up current log file
        setupCurrentLogFile()
    }
    
    func log(_ entry: LogEntry) {
        queue.async {
            self.writeToFile(entry)
        }
    }
    
    func flush() {
        queue.sync {
            // Force flush if needed
        }
    }
    
    private func writeToFile(_ entry: LogEntry) {
        guard let currentLogFile = currentLogFile else { return }
        
        // Check if we need to rotate the log file
        if shouldRotateLogFile() {
            rotateLogFile()
        }
        
        let logString = formatLogEntry(entry)
        
        do {
            if fileManager.fileExists(atPath: currentLogFile.path) {
                let fileHandle = try FileHandle(forWritingTo: currentLogFile)
                fileHandle.seekToEndOfFile()
                fileHandle.write(logString.data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                try logString.write(to: currentLogFile, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to write to log file: \(error)")
        }
    }
    
    private func formatLogEntry(_ entry: LogEntry) -> String {
        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        let jsonData: [String: Any] = [
            "timestamp": timestamp,
            "level": entry.level.rawValue,
            "category": entry.category.rawValue,
            "message": entry.message,
            "function": entry.function,
            "file": entry.file,
            "line": entry.line,
            "metadata": entry.metadata,
            "userID": entry.userID as Any,
            "sessionID": entry.sessionID as Any,
            "deviceInfo": [
                "model": entry.deviceInfo.model,
                "systemVersion": entry.deviceInfo.systemVersion,
                "appVersion": entry.appVersion,
                "buildNumber": entry.buildNumber
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonData)
            return String(data: jsonData, encoding: .utf8)! + "\n"
        } catch {
            return "\(timestamp) ERROR Failed to serialize log entry: \(error)\n"
        }
    }
    
    private func setupCurrentLogFile() {
        let dateString = dateFormatter.string(from: Date())
        let filename = "app-\(dateString).log"
        currentLogFile = logDirectory.appendingPathComponent(filename)
    }
    
    private func shouldRotateLogFile() -> Bool {
        guard let currentLogFile = currentLogFile else { return false }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: currentLogFile.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            return fileSize > configuration.maxLogFileSize
        } catch {
            return false
        }
    }
    
    private func rotateLogFile() {
        setupCurrentLogFile()
        cleanupOldLogs()
    }
    
    private func cleanupOldLogs() {
        do {
            let files = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            let logFiles = files.filter { $0.pathExtension == "log" }
            
            // Sort by modification date (newest first)
            let sortedFiles = logFiles.sorted { file1, file2 in
                let date1 = try? file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                let date2 = try? file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                return date1! > date2!
            }
            
            // Keep only the newest files up to maxLogFiles
            let filesToDelete = sortedFiles.suffix(from: configuration.maxLogFiles)
            
            for file in filesToDelete {
                try? fileManager.removeItem(at: file)
            }
            
            // Also delete files older than retention period
            let cutoffDate = Date().addingTimeInterval(-TimeInterval(configuration.logFileRetentionDays * 24 * 60 * 60))
            
            for file in sortedFiles {
                if let modificationDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modificationDate < cutoffDate {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Failed to cleanup old logs: \(error)")
        }
    }
}

// MARK: - OS Log Destination
class OSLogDestination: LogDestination {
    private let osLogs: [LogCategory: OSLog]
    
    init() {
        var logs: [LogCategory: OSLog] = [:]
        for category in LogCategory.allCases {
            logs[category] = OSLog(subsystem: category.subsystem, category: category.rawValue)
        }
        self.osLogs = logs
    }
    
    func log(_ entry: LogEntry) {
        guard let osLog = osLogs[entry.category] else { return }
        
        let message = "\(entry.file):\(entry.line) \(entry.function) - \(entry.message)"
        os_log("%{public}@", log: osLog, type: entry.level.osLogType, message)
    }
    
    func flush() {
        // OS Log doesn't need flushing
    }
}

// MARK: - Remote Log Destination
class RemoteLogDestination: LogDestination {
    private let endpoint: URL
    private let session: URLSession
    private let queue = DispatchQueue(label: "com.roomfinder.logging.remote", qos: .utility)
    private var pendingLogs: [LogEntry] = []
    private let maxBatchSize = 50
    private let flushInterval: TimeInterval = 30.0
    private var flushTimer: Timer?
    
    init(endpoint: URL) {
        self.endpoint = endpoint
        self.session = URLSession(configuration: .default)
        
        // Start flush timer
        DispatchQueue.main.async {
            self.flushTimer = Timer.scheduledTimer(withTimeInterval: self.flushInterval, repeats: true) { _ in
                self.flush()
            }
        }
    }
    
    deinit {
        flushTimer?.invalidate()
    }
    
    func log(_ entry: LogEntry) {
        queue.async {
            self.pendingLogs.append(entry)
            
            if self.pendingLogs.count >= self.maxBatchSize {
                self.sendLogs()
            }
        }
    }
    
    func flush() {
        queue.async {
            if !self.pendingLogs.isEmpty {
                self.sendLogs()
            }
        }
    }
    
    private func sendLogs() {
        let logsToSend = pendingLogs
        pendingLogs.removeAll()
        
        let logData = logsToSend.compactMap { entry in
            return [
                "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                "level": entry.level.rawValue,
                "category": entry.category.rawValue,
                "message": entry.message,
                "metadata": entry.metadata,
                "userID": entry.userID as Any,
                "sessionID": entry.sessionID as Any,
                "deviceInfo": [
                    "model": entry.deviceInfo.model,
                    "systemVersion": entry.deviceInfo.systemVersion,
                    "appVersion": entry.appVersion
                ]
            ]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: ["logs": logData])
            
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Failed to send logs to remote server: \(error)")
                    // Re-queue failed logs
                    self.queue.async {
                        self.pendingLogs.append(contentsOf: logsToSend)
                    }
                }
            }.resume()
        } catch {
            print("Failed to serialize logs for remote sending: \(error)")
        }
    }
}

// MARK: - Logging Service
class LoggingService {
    static let shared = LoggingService()
    
    private var configuration: LogConfiguration
    private var destinations: [LogDestination] = []
    private let queue = DispatchQueue(label: "com.roomfinder.logging", qos: .utility)
    private var currentUserID: String?
    private var currentSessionID: String?
    
    private init() {
        #if DEBUG
        self.configuration = .debug
        #else
        self.configuration = .production
        #endif
        
        setupDestinations()
    }
    
    // MARK: - Configuration
    
    func configure(with configuration: LogConfiguration) {
        self.configuration = configuration
        destinations.removeAll()
        setupDestinations()
    }
    
    func setUserID(_ userID: String?) {
        self.currentUserID = userID
    }
    
    func setSessionID(_ sessionID: String?) {
        self.currentSessionID = sessionID
    }
    
    // MARK: - Logging Methods
    
    func debug(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any] = [:],
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .debug, category: category, message: message, metadata: metadata, function: function, file: file, line: line)
    }
    
    func info(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any] = [:],
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .info, category: category, message: message, metadata: metadata, function: function, file: file, line: line)
    }
    
    func warning(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any] = [:],
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .warning, category: category, message: message, metadata: metadata, function: function, file: file, line: line)
    }
    
    func error(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any] = [:],
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .error, category: category, message: message, metadata: metadata, function: function, file: file, line: line)
    }
    
    func critical(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any] = [:],
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .critical, category: category, message: message, metadata: metadata, function: function, file: file, line: line)
    }
    
    // MARK: - Error Logging
    
    func logError(_ error: Error, category: LogCategory = .general, metadata: [String: Any] = [:]) {
        var errorMetadata = metadata
        errorMetadata["error_type"] = String(describing: type(of: error))
        errorMetadata["error_description"] = error.localizedDescription
        
        if let appError = error as? AppError {
            errorMetadata["error_code"] = appError.errorCode
            errorMetadata["error_severity"] = appError.severity.rawValue
        }
        
        log(level: .error, category: category, message: "Error occurred: \(error.localizedDescription)", metadata: errorMetadata, function: #function, file: #file, line: #line)
    }
    
    // MARK: - Performance Logging
    
    func logPerformance(
        operation: String,
        duration: TimeInterval,
        category: LogCategory = .performance,
        metadata: [String: Any] = [:]
    ) {
        var perfMetadata = metadata
        perfMetadata["operation"] = operation
        perfMetadata["duration_ms"] = duration * 1000
        
        let level: LogLevel = duration > 1.0 ? .warning : .info
        log(level: level, category: category, message: "Performance: \(operation) took \(String(format: "%.2f", duration * 1000))ms", metadata: perfMetadata, function: #function, file: #file, line: #line)
    }
    
    // MARK: - Network Logging
    
    func logNetworkRequest(
        url: String,
        method: String,
        statusCode: Int?,
        duration: TimeInterval,
        error: Error? = nil
    ) {
        let metadata: [String: Any] = [
            "url": url,
            "method": method,
            "status_code": statusCode as Any,
            "duration_ms": duration * 1000,
            "error": error?.localizedDescription as Any
        ]
        
        let level: LogLevel = error != nil ? .error : .info
        let message = "Network request: \(method) \(url) - \(statusCode ?? 0) (\(String(format: "%.2f", duration * 1000))ms)"
        
        log(level: level, category: .network, message: message, metadata: metadata, function: #function, file: #file, line: #line)
    }
    
    // MARK: - Private Methods
    
    private func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: Any],
        function: String,
        file: String,
        line: Int
    ) {
        guard level >= configuration.minimumLevel else { return }
        
        // Apply sampling rate
        if Double.random(in: 0...1) > configuration.samplingRate {
            return
        }
        
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            userID: currentUserID,
            sessionID: currentSessionID,
            function: function,
            file: file,
            line: line
        )
        
        queue.async {
            for destination in self.destinations {
                destination.log(entry)
            }
        }
    }
    
    private func setupDestinations() {
        if configuration.enableConsoleLogging {
            destinations.append(ConsoleLogDestination())
        }
        
        if configuration.enableFileLogging {
            destinations.append(FileLogDestination(configuration: configuration))
        }
        
        if configuration.enableOSLogging {
            destinations.append(OSLogDestination())
        }
        
        if configuration.enableRemoteLogging {
            // Configure remote endpoint
            if let remoteURL = URL(string: "https://your-logging-endpoint.com/logs") {
                destinations.append(RemoteLogDestination(endpoint: remoteURL))
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func flush() {
        queue.sync {
            for destination in destinations {
                destination.flush()
            }
        }
    }
    
    func getLogFiles() -> [URL] {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logDirectory = documentsPath.appendingPathComponent("logs")
        
        do {
            let files = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "log" }
        } catch {
            return []
        }
    }
}

// MARK: - Logging Extensions
extension LoggingService {
    func measure<T>(
        operation: String,
        category: LogCategory = .performance,
        metadata: [String: Any] = [:],
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logPerformance(operation: operation, duration: duration, category: category, metadata: metadata)
        }
        return try block()
    }
    
    func measureAsync<T>(
        operation: String,
        category: LogCategory = .performance,
        metadata: [String: Any] = [:],
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            logPerformance(operation: operation, duration: duration, category: category, metadata: metadata)
        }
        return try await block()
    }
}