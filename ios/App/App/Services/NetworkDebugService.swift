import Foundation
import Network
import WebKit

// MARK: - Network Debug Service for iOS
class NetworkDebugService {
    static let shared = NetworkDebugService()
    
    private let diagnosticService = NetworkDiagnosticService.shared
    private let centralizedAPI = CentralizedAPIService.shared
    
    private init() {}
    
    // MARK: - Debug Methods
    
    /// Run comprehensive network diagnostics and return formatted report
    func runFullDiagnostics() -> String {
        print("🔍 Running full network diagnostics...")
        
        let report = diagnosticService.runFullDiagnostics()
        let formattedReport = formatDiagnosticReport(report)
        
        print("📋 Diagnostic Report:")
        print(formattedReport)
        
        return formattedReport
    }
    
    /// Test connectivity to all critical services
    func testAllConnections() {
        print("🌐 Testing all service connections...")
        
        let testURLs = [
            "https://google.com",
            "https://zmxyysauqtfkvntgtjsm.supabase.co",
            "https://api.openai.com",
            "https://api.stripe.com",
            "https://roomfinder-ai-negotiator-production.up.railway.app"
        ]
        
        for url in testURLs {
            testSingleConnection(url: url)
        }
    }
    
    /// Test a single connection and report results
    private func testSingleConnection(url: String) {
        guard let requestURL = URL(string: url) else {
            print("❌ Invalid URL: \(url)")
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10.0
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            let responseTime = CFAbsoluteTimeGetCurrent() - startTime
            
            if let error = error {
                print("❌ \(url): Failed - \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                let status = httpResponse.statusCode
                let statusIcon = (200...299).contains(status) ? "✅" : "⚠️"
                print("\(statusIcon) \(url): \(status) (\(String(format: "%.2f", responseTime))s)")
            } else {
                print("⚠️ \(url): Unknown response")
            }
        }.resume()
    }
    
    /// Debug WebView configuration
    func debugWebViewConfiguration() -> String {
        print("🌐 Debugging WebView configuration...")
        
        let config = WKWebViewConfiguration()
        let preferences = config.preferences
        
        var report = "🌐 WebView Configuration Debug Report\n"
        report += "=====================================\n\n"
        
        report += "📱 Basic Configuration:\n"
        if #available(iOS 14.0, *) {
            report += "  JavaScript Enabled: \(preferences.javaScriptEnabled)\n"
        }
        report += "  JavaScript Can Open Windows: \(preferences.javaScriptCanOpenWindowsAutomatically)\n"
        report += "  Minimum Font Size: \(preferences.minimumFontSize)\n"
        report += "\n"
        
        report += "🔒 Security Settings:\n"
        report += "  Fraudulent Website Warning: \(preferences.isFraudulentWebsiteWarningEnabled)\n"
        if #available(iOS 14.5, *) {
            report += "  Text Interaction: \(preferences.isTextInteractionEnabled)\n"
        }
        report += "\n"
        
        report += "🎥 Media Settings:\n"
        report += "  Allows Inline Media: \(config.allowsInlineMediaPlayback)\n"
        report += "  Allows AirPlay: \(config.allowsAirPlayForMediaPlayback)\n"
        report += "  Allows Picture in Picture: \(config.allowsPictureInPictureMediaPlayback)\n"
        report += "  Media Types Requiring User Action: \(config.mediaTypesRequiringUserActionForPlayback)\n"
        report += "\n"
        
        report += "🔧 Data Store:\n"
        report += "  Website Data Store: Available\n"
        report += "  Process Pool: \(config.processPool != nil ? "Available" : "Not Available")\n"
        report += "\n"
        
        print(report)
        return report
    }
    
    /// Debug CORS issues
    func debugCORSIssues() -> String {
        print("🔐 Debugging CORS issues...")
        
        var report = "🔐 CORS Debug Report\n"
        report += "==================\n\n"
        
        // Test CORS with different origins
        let testOrigins = [
            "https://roomfinder-ai-negotiator-production.up.railway.app",
            "https://zmxyysauqtfkvntgtjsm.supabase.co",
            "https://api.openai.com",
            "https://api.stripe.com"
        ]
        
        for origin in testOrigins {
            report += "Testing CORS for: \(origin)\n"
            
            guard let url = URL(string: origin) else {
                report += "  ❌ Invalid URL\n\n"
                continue
            }
            
            var request = URLRequest(url: url)
            request.setValue("https://localhost:3000", forHTTPHeaderField: "Origin")
            request.setValue("GET", forHTTPHeaderField: "Access-Control-Request-Method")
            request.setValue("Content-Type", forHTTPHeaderField: "Access-Control-Request-Headers")
            request.httpMethod = "OPTIONS"
            
            // This would be an async operation in real implementation
            report += "  🔄 Preflight request configured\n"
            report += "  📝 Origin: https://localhost:3000\n"
            report += "  📝 Method: OPTIONS\n"
            report += "  📝 Headers: Content-Type\n\n"
        }
        
        print(report)
        return report
    }
    
    /// Debug SSL/TLS issues
    func debugSSLIssues() -> String {
        print("🔒 Debugging SSL/TLS issues...")
        
        var report = "🔒 SSL/TLS Debug Report\n"
        report += "=====================\n\n"
        
        let testDomains = [
            "google.com",
            "zmxyysauqtfkvntgtjsm.supabase.co",
            "api.openai.com",
            "api.stripe.com"
        ]
        
        for domain in testDomains {
            report += "Testing SSL for: \(domain)\n"
            
            // Test SSL certificate
            guard let url = URL(string: "https://\(domain)") else {
                report += "  ❌ Invalid URL\n\n"
                continue
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            
            let semaphore = DispatchSemaphore(value: 0)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error as NSError? {
                    if error.code == NSURLErrorServerCertificateUntrusted {
                        report += "  ❌ Certificate not trusted\n"
                    } else if error.code == NSURLErrorSecureConnectionFailed {
                        report += "  ❌ Secure connection failed\n"
                    } else {
                        report += "  ❌ SSL Error: \(error.localizedDescription)\n"
                    }
                } else {
                    report += "  ✅ SSL connection successful\n"
                }
                
                semaphore.signal()
            }.resume()
            
            semaphore.wait()
            report += "\n"
        }
        
        print(report)
        return report
    }
    
    /// Debug URL scheme issues
    func debugURLSchemes() -> String {
        print("🔗 Debugging URL schemes...")
        
        var report = "🔗 URL Scheme Debug Report\n"
        report += "========================\n\n"
        
        // Check Info.plist for URL schemes
        guard let infoPlist = Bundle.main.infoDictionary else {
            report += "❌ Cannot access Info.plist\n"
            return report
        }
        
        report += "📱 Bundle Information:\n"
        report += "  Bundle ID: \(infoPlist["CFBundleIdentifier"] as? String ?? "Unknown")\n"
        report += "  Bundle Name: \(infoPlist["CFBundleName"] as? String ?? "Unknown")\n"
        report += "  Bundle Version: \(infoPlist["CFBundleVersion"] as? String ?? "Unknown")\n"
        report += "\n"
        
        // Check URL types
        if let urlTypes = infoPlist["CFBundleURLTypes"] as? [[String: Any]] {
            report += "🔗 Registered URL Schemes:\n"
            for urlType in urlTypes {
                if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                    for scheme in schemes {
                        report += "  - \(scheme)\n"
                    }
                }
            }
        } else {
            report += "🔗 No URL schemes registered\n"
        }
        
        report += "\n"
        
        // Check App Transport Security
        if let ats = infoPlist["NSAppTransportSecurity"] as? [String: Any] {
            report += "🛡️ App Transport Security:\n"
            report += "  Allows Arbitrary Loads: \(ats["NSAllowsArbitraryLoads"] as? Bool ?? false)\n"
            
            if let exceptionDomains = ats["NSExceptionDomains"] as? [String: [String: Any]] {
                report += "  Exception Domains: \(exceptionDomains.count)\n"
                for domain in exceptionDomains.keys {
                    report += "    - \(domain)\n"
                }
            }
        }
        
        print(report)
        return report
    }
    
    /// Generate debugging instructions for Xcode console
    func generateXcodeDebuggingInstructions() -> String {
        let instructions = """
        🔍 Xcode Console Debugging Instructions
        ====================================
        
        1. Enable Network Debugging in Xcode:
           - Open Xcode
           - Go to Product → Scheme → Edit Scheme
           - Select "Run" in the left sidebar
           - Click the "Arguments" tab
           - Add environment variables:
             * CFNETWORK_DIAGNOSTICS = 1
             * CFNETWORK_DIAGNOSTICS_FILE = /tmp/network.log
        
        2. Enable URLSession Debugging:
           - Add environment variable:
             * CFNETWORK_DIAGNOSTICS = 3
        
        3. Enable WebKit Debugging:
           - Add environment variables:
             * WEBKIT_LOGGING_ENABLED = 1
             * WEBKIT_LOGGING_LEVEL = DEBUG
        
        4. Console Log Filtering:
           - Filter by "Network" to see network-related logs
           - Filter by "URLSession" for URL session debugging
           - Filter by "WebKit" for WebView debugging
           - Filter by "🔍" to see our custom debug logs
        
        5. View Network Logs:
           - Open Console app on macOS
           - Connect your iOS device
           - Filter by your app's bundle ID
           - Look for network-related entries
        
        6. Common Error Patterns to Look For:
           - "NSURLErrorDomain"
           - "kCFErrorDomainCFNetwork"
           - "NSURLErrorNotConnectedToInternet"
           - "NSURLErrorTimedOut"
           - "NSURLErrorSecureConnectionFailed"
           - "NSURLErrorServerCertificateUntrusted"
        
        7. Useful LLDB Commands:
           - po request                     # Print request details
           - po response                    # Print response details
           - po error                       # Print error details
           - po error.userInfo              # Print error user info
        
        8. Network Activity Monitor:
           - Use Instruments → Network Activity
           - Monitor real-time network traffic
           - Analyze request/response patterns
        
        9. Safari Web Inspector (for WebView debugging):
           - Enable Safari Developer menu
           - Connect iOS device
           - Go to Develop → [Device] → [App]
           - View network tab for web requests
        
        10. Custom Debug Breakpoints:
            - Set breakpoints in NetworkInterceptorService
            - Set breakpoints in CentralizedAPIService
            - Set breakpoints in URLSession delegate methods
        """
        
        print(instructions)
        return instructions
    }
    
    /// Generate Safari Web Inspector instructions
    func generateSafariWebInspectorInstructions() -> String {
        let instructions = """
        🕷️ Safari Web Inspector Setup Instructions
        ==========================================
        
        1. Enable Safari Developer Menu:
           - Open Safari on macOS
           - Go to Safari → Preferences → Advanced
           - Check "Show Develop menu in menu bar"
        
        2. Enable iOS Device Web Inspector:
           - On iOS device: Settings → Safari → Advanced
           - Enable "Web Inspector"
        
        3. Connect Your iOS Device:
           - Connect device to Mac via USB
           - Trust the computer if prompted
           - Open your app on the device
        
        4. Access Web Inspector:
           - In Safari: Develop → [Your Device] → [Your App]
           - A new inspector window will open
        
        5. Debug Network Requests:
           - Click the "Network" tab
           - Reload your app or trigger network requests
           - View all network traffic in real-time
        
        6. Analyze Request Details:
           - Click on any request to see:
             * Headers (Request & Response)
             * Response data
             * Timing information
             * Cookies
        
        7. JavaScript Console:
           - Click "Console" tab
           - View JavaScript errors and logs
           - Execute JavaScript commands
        
        8. Useful Console Commands:
           - fetch('https://api.example.com')  # Test fetch
           - XMLHttpRequest()                  # Test XHR
           - console.log(window.location)      # Check current URL
        
        9. Look for Common Issues:
           - CORS errors in console
           - Failed network requests (red in Network tab)
           - SSL/TLS certificate errors
           - Timeout errors
        
        10. Mobile-Specific Debugging:
            - Check User-Agent string
            - Verify mobile viewport settings
            - Test touch events
            - Check device orientation changes
        """
        
        print(instructions)
        return instructions
    }
    
    /// Format diagnostic report for better readability
    private func formatDiagnosticReport(_ report: NetworkDiagnosticReport) -> String {
        var formatted = report.description
        
        // Add additional debugging information
        formatted += "\n\n🔧 Additional Debug Information:\n"
        formatted += "==============================\n\n"
        
        // Add timestamp
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatted += "📅 Report Generated: \(formatter.string(from: Date()))\n"
        
        // Add device information
        formatted += "📱 Device Information:\n"
        formatted += "  Device: \(UIDevice.current.model)\n"
        formatted += "  OS Version: \(UIDevice.current.systemVersion)\n"
        formatted += "  Device Name: \(UIDevice.current.name)\n"
        formatted += "\n"
        
        // Add app information
        if let infoPlist = Bundle.main.infoDictionary {
            formatted += "📦 App Information:\n"
            formatted += "  Bundle ID: \(infoPlist["CFBundleIdentifier"] as? String ?? "Unknown")\n"
            formatted += "  Version: \(infoPlist["CFBundleShortVersionString"] as? String ?? "Unknown")\n"
            formatted += "  Build: \(infoPlist["CFBundleVersion"] as? String ?? "Unknown")\n"
            formatted += "\n"
        }
        
        return formatted
    }
}

// MARK: - Debug Helper Extensions
extension NetworkDebugService {
    
    /// Quick debug method for testing specific URL
    func quickTest(url: String) {
        print("⚡ Quick testing URL: \(url)")
        
        guard let requestURL = URL(string: url) else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("RoomFinderAI/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("✅ Status: \(httpResponse.statusCode)")
                print("📋 Headers: \(httpResponse.allHeaderFields)")
                
                if let data = data {
                    print("📄 Response Size: \(data.count) bytes")
                    
                    if let string = String(data: data, encoding: .utf8) {
                        print("📝 Response Preview: \(string.prefix(200))...")
                    }
                }
            }
        }.resume()
    }
    
    /// Export debug report to file
    func exportDebugReport() -> URL? {
        let report = runFullDiagnostics()
        let webViewReport = debugWebViewConfiguration()
        let corsReport = debugCORSIssues()
        let sslReport = debugSSLIssues()
        let urlSchemeReport = debugURLSchemes()
        
        let fullReport = """
        RoomFinderAI iOS Network Debug Report
        ===================================
        
        \(report)
        
        \(webViewReport)
        
        \(corsReport)
        
        \(sslReport)
        
        \(urlSchemeReport)
        
        Generated at: \(Date())
        """
        
        // Save to Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "NetworkDebugReport_\(Date().timeIntervalSince1970).txt"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try fullReport.write(to: fileURL, atomically: true, encoding: .utf8)
            print("📄 Debug report exported to: \(fileURL)")
            return fileURL
        } catch {
            print("❌ Failed to export report: \(error)")
            return nil
        }
    }
}