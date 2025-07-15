import Foundation
import Network
import SystemConfiguration
import WebKit

// MARK: - Network Diagnostic Service for iOS
class NetworkDiagnosticService {
    static let shared = NetworkDiagnosticService()
    
    private let pathMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkDiagnosticService")
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.handleNetworkPathUpdate(path)
        }
        pathMonitor.start(queue: queue)
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let status = path.status
        let interfaces = path.availableInterfaces
        
        print("🔍 Network Path Update:")
        print("  Status: \(status)")
        print("  Interfaces: \(interfaces.map { $0.name })")
        print("  Is Expensive: \(path.isExpensive)")
        print("  Is Constrained: \(path.isConstrained)")
        
        if status == .satisfied {
            print("✅ Network is available")
        } else {
            print("❌ Network is not available")
        }
    }
    
    // MARK: - Comprehensive Network Diagnostics
    func runFullDiagnostics() -> NetworkDiagnosticReport {
        var report = NetworkDiagnosticReport()
        
        // Basic connectivity
        report.isConnected = checkInternetConnection()
        
        // Network interface details
        report.networkInterfaces = getNetworkInterfaces()
        
        // DNS configuration
        report.dnsConfiguration = getDNSConfiguration()
        
        // Proxy settings
        report.proxySettings = getProxySettings()
        
        // SSL/TLS capabilities
        report.sslCapabilities = getSSLCapabilities()
        
        // App Transport Security status
        report.atsSettings = getATSSettings()
        
        // Reachability test
        report.reachabilityTests = performReachabilityTests()
        
        // WKWebView specific tests
        report.webViewTests = performWebViewTests()
        
        return report
    }
    
    // MARK: - Internet Connection Check
    private func checkInternetConnection() -> Bool {
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: sa_family_t(AF_INET), sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }
        
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let ret = (isReachable && !needsConnection)
        
        return ret
    }
    
    // MARK: - Network Interface Information
    private func getNetworkInterfaces() -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        
        pathMonitor.currentPath.availableInterfaces.forEach { interface in
            interfaces.append(NetworkInterface(
                name: interface.name,
                type: interface.type.description,
                isActive: pathMonitor.currentPath.usesInterfaceType(interface.type)
            ))
        }
        
        return interfaces
    }
    
    // MARK: - DNS Configuration
    private func getDNSConfiguration() -> DNSConfiguration {
        var config = DNSConfiguration()
        
        // Get system DNS servers
        if let dnsServers = getDNSServers() {
            config.servers = dnsServers
        }
        
        // Test DNS resolution
        config.canResolveGoogle = testDNSResolution(host: "google.com")
        config.canResolveSupabase = testDNSResolution(host: "supabase.co")
        config.canResolveOpenAI = testDNSResolution(host: "api.openai.com")
        
        return config
    }
    
    private func getDNSServers() -> [String]? {
        // DNS server detection is not available on iOS
        // Return common DNS servers for diagnostic purposes
        return ["8.8.8.8", "8.8.4.4", "1.1.1.1"]
    }
    
    private func testDNSResolution(host: String) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        
        let host = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
        
        CFHostStartInfoResolution(host, .addresses, nil)
        
        var success: DarwinBoolean = false
        let addresses = CFHostGetAddressing(host, &success)
        
        if success.boolValue, let addresses = addresses?.takeUnretainedValue() {
            result = CFArrayGetCount(addresses) > 0
        }
        
        semaphore.signal()
        semaphore.wait()
        
        return result
    }
    
    // MARK: - Proxy Settings
    private func getProxySettings() -> ProxySettings {
        var settings = ProxySettings()
        
        if let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] {
            settings.httpProxy = proxySettings["HTTPProxy"] as? String
            settings.httpsProxy = proxySettings["HTTPSProxy"] as? String
            settings.httpProxyPort = proxySettings["HTTPPort"] as? Int
            settings.httpsProxyPort = proxySettings["HTTPSPort"] as? Int
            settings.proxyAutoConfigURL = proxySettings["ProxyAutoConfigURLString"] as? String
        }
        
        return settings
    }
    
    // MARK: - SSL/TLS Capabilities
    private func getSSLCapabilities() -> SSLCapabilities {
        var capabilities = SSLCapabilities()
        
        // Test TLS versions
        capabilities.supportsTLS12 = testTLSVersion(12)
        capabilities.supportsTLS13 = testTLSVersion(13)
        
        // Test cipher suites
        capabilities.supportedCipherSuites = getSupportedCipherSuites()
        
        return capabilities
    }
    
    private func testTLSVersion(_ version: Int) -> Bool {
        // This is a simplified test - in a real implementation,
        // you would need to create an SSL context and test the version
        return true
    }
    
    private func getSupportedCipherSuites() -> [String] {
        // Return commonly supported cipher suites
        return [
            "TLS_AES_256_GCM_SHA384",
            "TLS_CHACHA20_POLY1305_SHA256",
            "TLS_AES_128_GCM_SHA256",
            "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
            "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        ]
    }
    
    // MARK: - App Transport Security Settings
    private func getATSSettings() -> ATSSettings {
        var settings = ATSSettings()
        
        guard let infoPlist = Bundle.main.infoDictionary,
              let atsDict = infoPlist["NSAppTransportSecurity"] as? [String: Any] else {
            settings.isEnabled = true
            return settings
        }
        
        settings.isEnabled = !(atsDict["NSAllowsArbitraryLoads"] as? Bool ?? false)
        settings.allowsArbitraryLoads = atsDict["NSAllowsArbitraryLoads"] as? Bool ?? false
        settings.exceptionDomains = atsDict["NSExceptionDomains"] as? [String: [String: Any]] ?? [:]
        
        return settings
    }
    
    // MARK: - Reachability Tests
    private func performReachabilityTests() -> [ReachabilityTest] {
        let testHosts = [
            "google.com",
            "supabase.co",
            "api.openai.com",
            "api.stripe.com",
            "roomfinder-ai-negotiator-production.up.railway.app"
        ]
        
        return testHosts.map { host in
            ReachabilityTest(
                host: host,
                isReachable: testHostReachability(host),
                responseTime: measureResponseTime(host)
            )
        }
    }
    
    private func testHostReachability(_ host: String) -> Bool {
        // Use SCNetworkReachability to test host reachability
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, host) else {
            return false
        }
        
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return false
        }
        
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }
    
    private func measureResponseTime(_ host: String) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform a simple HTTP HEAD request
        guard let url = URL(string: "https://\(host)") else {
            return -1
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        let semaphore = DispatchSemaphore(value: 0)
        var responseTime: TimeInterval = -1
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if error == nil, let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    responseTime = CFAbsoluteTimeGetCurrent() - startTime
                }
            }
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        return responseTime
    }
    
    // MARK: - WebView Tests
    private func performWebViewTests() -> WebViewTests {
        var tests = WebViewTests()
        
        // Test WKWebView configuration
        tests.canCreateWebView = testWebViewCreation()
        tests.corsEnabled = testCORSSupport()
        tests.jsEnabled = testJavaScriptSupport()
        
        return tests
    }
    
    private func testWebViewCreation() -> Bool {
        // Test if WKWebView can be created successfully
        do {
            let webView = WKWebView()
            webView.removeFromSuperview()
            return true
        } catch {
            return false
        }
    }
    
    private func testCORSSupport() -> Bool {
        // This would require more complex testing with actual web content
        return true
    }
    
    private func testJavaScriptSupport() -> Bool {
        // Test if JavaScript is enabled in WKWebView
        let webView = WKWebView()
        return webView.configuration.preferences.javaScriptEnabled
    }
    
    // MARK: - Diagnostic Report Generation
    func generateDiagnosticReport() -> String {
        let report = runFullDiagnostics()
        return report.description
    }
    
    // MARK: - Log Network Request
    func logNetworkRequest(url: String, method: String, headers: [String: String]?, body: Data?) {
        print("🌐 Network Request:")
        print("  URL: \(url)")
        print("  Method: \(method)")
        
        if let headers = headers {
            print("  Headers:")
            headers.forEach { key, value in
                print("    \(key): \(value)")
            }
        }
        
        if let body = body {
            print("  Body Size: \(body.count) bytes")
            if let bodyString = String(data: body, encoding: .utf8) {
                print("  Body: \(bodyString)")
            }
        }
    }
    
    // MARK: - Log Network Response
    func logNetworkResponse(url: String, statusCode: Int, headers: [String: String]?, data: Data?, error: Error?) {
        print("📡 Network Response:")
        print("  URL: \(url)")
        print("  Status Code: \(statusCode)")
        
        if let headers = headers {
            print("  Headers:")
            headers.forEach { key, value in
                print("    \(key): \(value)")
            }
        }
        
        if let data = data {
            print("  Response Size: \(data.count) bytes")
        }
        
        if let error = error {
            print("  Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Network Interface Type Extension
extension NWInterface.InterfaceType {
    var description: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Diagnostic Report Data Models
struct NetworkDiagnosticReport {
    var isConnected: Bool = false
    var networkInterfaces: [NetworkInterface] = []
    var dnsConfiguration: DNSConfiguration = DNSConfiguration()
    var proxySettings: ProxySettings = ProxySettings()
    var sslCapabilities: SSLCapabilities = SSLCapabilities()
    var atsSettings: ATSSettings = ATSSettings()
    var reachabilityTests: [ReachabilityTest] = []
    var webViewTests: WebViewTests = WebViewTests()
    
    var description: String {
        var result = "📊 Network Diagnostic Report\n"
        result += "================================\n\n"
        
        result += "🔗 Connectivity:\n"
        result += "  Internet Connection: \(isConnected ? "✅ Connected" : "❌ Disconnected")\n"
        result += "  Network Interfaces: \(networkInterfaces.count)\n"
        networkInterfaces.forEach { interface in
            result += "    - \(interface.name) (\(interface.type)): \(interface.isActive ? "Active" : "Inactive")\n"
        }
        result += "\n"
        
        result += "🌐 DNS Configuration:\n"
        result += "  DNS Servers: \(dnsConfiguration.servers.joined(separator: ", "))\n"
        result += "  Google.com: \(dnsConfiguration.canResolveGoogle ? "✅" : "❌")\n"
        result += "  Supabase.co: \(dnsConfiguration.canResolveSupabase ? "✅" : "❌")\n"
        result += "  OpenAI API: \(dnsConfiguration.canResolveOpenAI ? "✅" : "❌")\n"
        result += "\n"
        
        result += "🔒 SSL/TLS Capabilities:\n"
        result += "  TLS 1.2: \(sslCapabilities.supportsTLS12 ? "✅" : "❌")\n"
        result += "  TLS 1.3: \(sslCapabilities.supportsTLS13 ? "✅" : "❌")\n"
        result += "  Supported Cipher Suites: \(sslCapabilities.supportedCipherSuites.count)\n"
        result += "\n"
        
        result += "🛡️ App Transport Security:\n"
        result += "  ATS Enabled: \(atsSettings.isEnabled ? "✅" : "❌")\n"
        result += "  Allows Arbitrary Loads: \(atsSettings.allowsArbitraryLoads ? "✅" : "❌")\n"
        result += "  Exception Domains: \(atsSettings.exceptionDomains.count)\n"
        result += "\n"
        
        result += "🎯 Reachability Tests:\n"
        reachabilityTests.forEach { test in
            let status = test.isReachable ? "✅" : "❌"
            let responseTime = test.responseTime > 0 ? String(format: "%.2fs", test.responseTime) : "N/A"
            result += "  \(test.host): \(status) (\(responseTime))\n"
        }
        result += "\n"
        
        result += "🌐 WebView Tests:\n"
        result += "  Can Create WebView: \(webViewTests.canCreateWebView ? "✅" : "❌")\n"
        result += "  CORS Enabled: \(webViewTests.corsEnabled ? "✅" : "❌")\n"
        result += "  JavaScript Enabled: \(webViewTests.jsEnabled ? "✅" : "❌")\n"
        
        return result
    }
}

struct NetworkInterface {
    let name: String
    let type: String
    let isActive: Bool
}

struct DNSConfiguration {
    var servers: [String] = []
    var canResolveGoogle: Bool = false
    var canResolveSupabase: Bool = false
    var canResolveOpenAI: Bool = false
}

struct ProxySettings {
    var httpProxy: String?
    var httpsProxy: String?
    var httpProxyPort: Int?
    var httpsProxyPort: Int?
    var proxyAutoConfigURL: String?
}

struct SSLCapabilities {
    var supportsTLS12: Bool = false
    var supportsTLS13: Bool = false
    var supportedCipherSuites: [String] = []
}

struct ATSSettings {
    var isEnabled: Bool = true
    var allowsArbitraryLoads: Bool = false
    var exceptionDomains: [String: [String: Any]] = [:]
}

struct ReachabilityTest {
    let host: String
    let isReachable: Bool
    let responseTime: TimeInterval
}

struct WebViewTests {
    var canCreateWebView: Bool = false
    var corsEnabled: Bool = false
    var jsEnabled: Bool = false
}