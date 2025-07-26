import Foundation
import os.log

// Simple logging categories for the simplified app
enum LogCategory: String, CaseIterable {
    case general = "General"
    case network = "Network"
    case auth = "Authentication"
    case data = "Data"
    case ui = "UI"
    
    var error: OSLog {
        return OSLog(subsystem: Bundle.main.bundleIdentifier ?? "RoomFinderAI", category: self.rawValue)
    }
}

// Simplified error handler for the app
class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    // Log error with category
    func logError(_ error: Error, category: LogCategory = .general, function: String = #function, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        let message = "[\(filename):\(line)] \(function) - \(error.localizedDescription)"
        
        os_log("%@", log: category.error, type: .error, message)
        
        // In debug mode, also print to console
        #if DEBUG
        print("🔴 ERROR [\(category.rawValue)]: \(message)")
        #endif
    }
    
    // Log info message
    func logInfo(_ message: String, category: LogCategory = .general) {
        os_log("%@", log: category.error, type: .info, message)
        
        #if DEBUG
        print("ℹ️ INFO [\(category.rawValue)]: \(message)")
        #endif
    }
    
    // Log warning
    func logWarning(_ message: String, category: LogCategory = .general) {
        os_log("%@", log: category.error, type: .default, message)
        
        #if DEBUG
        print("⚠️ WARNING [\(category.rawValue)]: \(message)")
        #endif
    }
    
    // Handle and display user-friendly error
    func handleError(_ error: Error, showToUser: Bool = false) {
        logError(error)
        
        if showToUser {
            // In a real app, this would show an alert or toast
            // For now, just log it
            logInfo("User should see: \(error.localizedDescription)")
        }
    }
}

// Common app errors
enum AppError: LocalizedError {
    case networkUnavailable
    case invalidData
    case authenticationFailed
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable"
        case .invalidData:
            return "Invalid data received"
        case .authenticationFailed:
            return "Authentication failed"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}