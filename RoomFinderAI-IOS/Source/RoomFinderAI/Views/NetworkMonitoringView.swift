import SwiftUI

struct NetworkMonitoringView: View {
    @StateObject private var networkMonitor = NetworkMonitoringService.shared
    @State private var showDetails = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Status Card
                    currentStatusCard
                    
                    // Connection Details Card
                    connectionDetailsCard
                    
                    // Speed Test Card
                    speedTestCard
                    
                    // Network Statistics Card
                    networkStatisticsCard
                    
                    // Actions Card
                    actionsCard
                }
                .padding()
            }
            .navigationTitle("Network Status")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Test Speed") {
                        networkMonitor.forceQualityTest()
                    }
                }
            }
        }
    }
    
    private var currentStatusCard: some View {
        VStack(spacing: 16) {
            // Connection Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Status")
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Image(systemName: networkMonitor.connectionType.iconName)
                            .foregroundColor(networkMonitor.isConnected ? .green : .red)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(networkMonitor.isConnected ? "Connected" : "Disconnected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(networkMonitor.isConnected ? .green : .red)
                            
                            Text(networkMonitor.connectionType.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Connection Quality
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Quality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        qualityIndicator
                        
                        Text(networkMonitor.connectionQuality.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Connection Description
            if networkMonitor.isConnected {
                HStack {
                    Text(networkMonitor.getConnectionDescription())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var connectionDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection Details")
                .font(.headline)
            
            VStack(spacing: 12) {
                DetailRow(title: "Network Type", value: networkMonitor.connectionType.displayName)
                DetailRow(title: "Quality", value: networkMonitor.connectionQuality.displayName)
                DetailRow(title: "Expensive", value: networkMonitor.isExpensive ? "Yes" : "No")
                DetailRow(title: "Constrained", value: networkMonitor.isConstrained ? "Yes" : "No")
                DetailRow(title: "Data Saver", value: networkMonitor.shouldUseDataSaver() ? "Recommended" : "Not Needed")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var speedTestCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Speed Test")
                    .font(.headline)
                
                Spacer()
                
                Button("Run Test") {
                    networkMonitor.forceQualityTest()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            VStack(spacing: 12) {
                DetailRow(
                    title: "Average Speed",
                    value: formatSpeed(networkMonitor.networkStatistics.averageSpeedMbps)
                )
                DetailRow(
                    title: "Best Speed",
                    value: formatSpeed(networkMonitor.networkStatistics.bestSpeedMbps)
                )
                DetailRow(
                    title: "Worst Speed",
                    value: formatSpeed(networkMonitor.networkStatistics.worstSpeedMbps)
                )
                DetailRow(
                    title: "Total Tests",
                    value: "\(networkMonitor.networkStatistics.totalSpeedTests)"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var networkStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Statistics")
                .font(.headline)
            
            VStack(spacing: 12) {
                DetailRow(
                    title: "Connection Changes",
                    value: "\(networkMonitor.networkStatistics.connectionChanges)"
                )
                DetailRow(
                    title: "Uptime",
                    value: formatDuration(networkMonitor.networkStatistics.totalUptime)
                )
                DetailRow(
                    title: "Downtime",
                    value: formatDuration(networkMonitor.networkStatistics.totalDowntime)
                )
                DetailRow(
                    title: "Uptime %",
                    value: String(format: "%.1f%%", networkMonitor.networkStatistics.uptimePercentage)
                )
            }
            
            // Connection Time by Type
            if networkMonitor.networkStatistics.wifiConnectionTime > 0 || 
               networkMonitor.networkStatistics.cellularConnectionTime > 0 ||
               networkMonitor.networkStatistics.ethernetConnectionTime > 0 {
                
                Divider()
                    .padding(.vertical, 8)
                
                Text("Connection Time by Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(spacing: 8) {
                    if networkMonitor.networkStatistics.wifiConnectionTime > 0 {
                        DetailRow(
                            title: "Wi-Fi",
                            value: formatDuration(networkMonitor.networkStatistics.wifiConnectionTime)
                        )
                    }
                    
                    if networkMonitor.networkStatistics.cellularConnectionTime > 0 {
                        DetailRow(
                            title: "Cellular",
                            value: formatDuration(networkMonitor.networkStatistics.cellularConnectionTime)
                        )
                    }
                    
                    if networkMonitor.networkStatistics.ethernetConnectionTime > 0 {
                        DetailRow(
                            title: "Ethernet",
                            value: formatDuration(networkMonitor.networkStatistics.ethernetConnectionTime)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button(action: {
                    networkMonitor.forceQualityTest()
                }) {
                    HStack {
                        Image(systemName: "speedometer")
                        Text("Run Speed Test")
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                
                Button(action: {
                    networkMonitor.resetStatistics()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Reset Statistics")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var qualityIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(signalBarColor(for: index))
                    .frame(width: 4, height: CGFloat(4 + index * 2))
                    .cornerRadius(1)
            }
        }
    }
    
    private func signalBarColor(for index: Int) -> Color {
        let qualityLevel = qualityToLevel(networkMonitor.connectionQuality)
        return index < qualityLevel ? Color.green : Color.gray.opacity(0.3)
    }
    
    private func qualityToLevel(_ quality: ConnectionQuality) -> Int {
        switch quality {
        case .unknown:
            return 0
        case .poor:
            return 1
        case .fair:
            return 2
        case .good:
            return 3
        case .excellent:
            return 5
        }
    }
    
    private func formatSpeed(_ speedMbps: Double) -> String {
        if speedMbps == 0 {
            return "Unknown"
        } else if speedMbps < 1 {
            return String(format: "%.1f Kbps", speedMbps * 1000)
        } else {
            return String(format: "%.1f Mbps", speedMbps)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration == 0 {
            return "0s"
        }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct NetworkStatusIndicator: View {
    @StateObject private var networkMonitor = NetworkMonitoringService.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: networkMonitor.connectionType.iconName)
                .foregroundColor(networkMonitor.isConnected ? .green : .red)
                .font(.caption)
            
            if networkMonitor.isConnected {
                // Signal strength indicator
                HStack(spacing: 1) {
                    ForEach(0..<3) { index in
                        Rectangle()
                            .fill(signalBarColor(for: index))
                            .frame(width: 2, height: CGFloat(2 + index))
                            .cornerRadius(0.5)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.systemBackground))
        .cornerRadius(4)
        .shadow(radius: 1)
    }
    
    private func signalBarColor(for index: Int) -> Color {
        let qualityLevel = qualityToLevel(networkMonitor.connectionQuality)
        return index < qualityLevel ? Color.green : Color.gray.opacity(0.3)
    }
    
    private func qualityToLevel(_ quality: ConnectionQuality) -> Int {
        switch quality {
        case .unknown:
            return 0
        case .poor:
            return 1
        case .fair:
            return 2
        case .good:
            return 3
        case .excellent:
            return 3
        }
    }
}

struct NetworkQualityBadge: View {
    @StateObject private var networkMonitor = NetworkMonitoringService.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(qualityColor)
                .frame(width: 8, height: 8)
            
            Text(networkMonitor.connectionQuality.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(qualityColor.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var qualityColor: Color {
        switch networkMonitor.connectionQuality {
        case .unknown:
            return .gray
        case .poor:
            return .red
        case .fair:
            return .orange
        case .good:
            return .yellow
        case .excellent:
            return .green
        }
    }
}

#Preview {
    NetworkMonitoringView()
}