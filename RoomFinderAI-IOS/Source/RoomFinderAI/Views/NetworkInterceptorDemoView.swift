import SwiftUI

struct NetworkInterceptorDemoView: View {
    @StateObject private var interceptorService = NetworkInterceptorService.shared
    @State private var testURL = "https://httpbin.org/get"
    @State private var isLoading = false
    @State private var responseText = ""
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Active Requests Tab
                activeRequestsTab
                    .tabItem {
                        Label("Requests", systemImage: "network")
                    }
                    .tag(0)
                
                // Statistics Tab
                statisticsTab
                    .tabItem {
                        Label("Statistics", systemImage: "chart.bar")
                    }
                    .tag(1)
                
                // Interceptors Tab
                interceptorsTab
                    .tabItem {
                        Label("Interceptors", systemImage: "gear")
                    }
                    .tag(2)
                
                // Test Tab
                testTab
                    .tabItem {
                        Label("Test", systemImage: "play.circle")
                    }
                    .tag(3)
            }
            .navigationTitle("Network Interceptors")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var activeRequestsTab: some View {
        List {
            Section {
                ForEach(Array(interceptorService.activeRequests.values.sorted(by: { $0.timestamp > $1.timestamp })), id: \.id) { request in
                    ActiveRequestRow(request: request)
                }
            } header: {
                HStack {
                    Text("Active Requests")
                    Spacer()
                    Text("\(interceptorService.activeRequests.count)")
                        .foregroundColor(.secondary)
                }
            }
            
            if interceptorService.activeRequests.isEmpty {
                Text("No active requests")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .refreshable {
            // Refresh is handled automatically by @StateObject
        }
    }
    
    private var statisticsTab: some View {
        List {
            Section("Request Statistics") {
                StatRow(title: "Total Requests", value: "\(interceptorService.requestStatistics.totalRequests)")
                StatRow(title: "Total Successes", value: "\(interceptorService.requestStatistics.totalSuccesses)")
                StatRow(title: "Total Errors", value: "\(interceptorService.requestStatistics.totalErrors)")
                StatRow(title: "Success Rate", value: String(format: "%.1f%%", interceptorService.requestStatistics.successRate * 100))
                StatRow(title: "Error Rate", value: String(format: "%.1f%%", interceptorService.requestStatistics.errorRate * 100))
                StatRow(title: "Avg Response Time", value: String(format: "%.2f ms", interceptorService.requestStatistics.averageResponseTime * 1000))
            }
            
            if !interceptorService.requestStatistics.requestsByHost.isEmpty {
                Section("Requests by Host") {
                    ForEach(Array(interceptorService.requestStatistics.requestsByHost.sorted(by: { $0.value > $1.value })), id: \.key) { host, count in
                        HStack {
                            Text(host)
                            Spacer()
                            Text("\(count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if !interceptorService.requestStatistics.errorsByType.isEmpty {
                Section("Errors by Type") {
                    ForEach(Array(interceptorService.requestStatistics.errorsByType.sorted(by: { $0.value > $1.value })), id: \.key) { errorType, count in
                        HStack {
                            Text(errorType)
                                .font(.caption)
                            Spacer()
                            Text("\(count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var interceptorsTab: some View {
        List {
            Section("Active Interceptors") {
                ForEach(Array(interceptorService.getInterceptors().enumerated()), id: \.offset) { index, interceptor in
                    InterceptorRow(interceptor: interceptor, index: index)
                }
            }
            
            Section("Actions") {
                Button("Reset Statistics") {
                    interceptorService.requestStatistics = RequestStatistics()
                }
                .foregroundColor(.blue)
                
                Button("Clear Active Requests") {
                    interceptorService.clearActiveRequests()
                }
                .foregroundColor(.orange)
            }
        }
    }
    
    private var testTab: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Test URL")
                    .font(.headline)
                
                TextField("Enter URL", text: $testURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            VStack(spacing: 12) {
                Button("Test GET Request") {
                    testGETRequest()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading)
                
                Button("Test POST Request") {
                    testPOSTRequest()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isLoading)
                
                Button("Test Error Request") {
                    testErrorRequest()
                }
                .buttonStyle(ErrorButtonStyle())
                .disabled(isLoading)
            }
            
            if isLoading {
                ProgressView("Making request...")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            if !responseText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response")
                        .font(.headline)
                    
                    ScrollView {
                        Text(responseText)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func testGETRequest() {
        guard let url = URL(string: testURL) else {
            responseText = "Invalid URL"
            return
        }
        
        isLoading = true
        responseText = ""
        
        Task {
            do {
                let session = InterceptedURLSession.shared
                let (data, response) = try await session.data(from: url)
                
                let responseString = String(data: data, encoding: .utf8) ?? "No data"
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                
                DispatchQueue.main.async {
                    self.responseText = """
                    Status Code: \(statusCode)
                    Response:
                    \(responseString)
                    """
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.responseText = "Error: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func testPOSTRequest() {
        guard let url = URL(string: "https://httpbin.org/post") else {
            responseText = "Invalid URL"
            return
        }
        
        isLoading = true
        responseText = ""
        
        Task {
            do {
                let session = InterceptedURLSession.shared
                let testData = ["test": "data", "timestamp": Date().timeIntervalSince1970]
                let response = try await session.postJSON(to: url, body: testData, responseType: [String: Any].self)
                
                DispatchQueue.main.async {
                    self.responseText = """
                    POST Response:
                    \(String(describing: response))
                    """
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.responseText = "Error: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func testErrorRequest() {
        let errorURL = URL(string: "https://httpbin.org/status/404")!
        
        isLoading = true
        responseText = ""
        
        Task {
            do {
                let session = InterceptedURLSession.shared
                let (data, response) = try await session.data(from: errorURL)
                
                let responseString = String(data: data, encoding: .utf8) ?? "No data"
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                
                DispatchQueue.main.async {
                    self.responseText = """
                    Status Code: \(statusCode)
                    Response:
                    \(responseString)
                    """
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.responseText = "Error: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct ActiveRequestRow: View {
    let request: InterceptedRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(request.originalRequest.httpMethod ?? "GET")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(methodColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                
                Text(request.originalRequest.url?.absoluteString ?? "Unknown URL")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                statusBadge
            }
            
            HStack {
                Text(request.id)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatTimestamp(request.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let duration = request.duration {
                    Text(String(format: "%.2f ms", duration * 1000))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private var methodColor: Color {
        switch request.originalRequest.httpMethod {
        case "GET":
            return .blue
        case "POST":
            return .green
        case "PUT":
            return .orange
        case "DELETE":
            return .red
        default:
            return .gray
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch request.status {
        case .pending:
            return .yellow
        case .intercepted:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var statusText: String {
        switch request.status {
        case .pending:
            return "Pending"
        case .intercepted:
            return "Intercepted"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct InterceptorRow: View {
    let interceptor: NetworkInterceptor
    let index: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(interceptorName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Priority: \(interceptor.priority)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("#\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private var interceptorName: String {
        String(describing: type(of: interceptor))
            .replacingOccurrences(of: "Interceptor", with: "")
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ErrorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    NetworkInterceptorDemoView()
}