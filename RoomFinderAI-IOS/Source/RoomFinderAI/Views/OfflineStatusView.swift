import SwiftUI

struct OfflineStatusView: View {
    @StateObject private var offlineDataService = OfflineDataService.shared
    @State private var showSyncDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Bar
            HStack {
                // Connection Status
                HStack(spacing: 4) {
                    Image(systemName: offlineDataService.isOnline ? "wifi" : "wifi.slash")
                        .foregroundColor(offlineDataService.isOnline ? .green : .orange)
                        .font(.caption)
                    
                    Text(offlineDataService.isOnline ? "Online" : "Offline")
                        .font(.caption)
                        .foregroundColor(offlineDataService.isOnline ? .green : .orange)
                }
                
                Spacer()
                
                // Sync Status
                HStack(spacing: 4) {
                    syncStatusIcon
                    
                    Text(offlineDataService.syncStatus.displayText)
                        .font(.caption)
                        .foregroundColor(syncStatusColor)
                }
                
                // Pending Sync Count
                if offlineDataService.pendingSyncCount > 0 {
                    HStack(spacing: 2) {
                        Text("(\(offlineDataService.pendingSyncCount))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusBarBackground)
            .onTapGesture {
                showSyncDetails.toggle()
            }
            
            // Sync Details (expandable)
            if showSyncDetails {
                VStack(spacing: 8) {
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sync Status")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text(syncStatusDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if offlineDataService.syncStatus == .syncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if offlineDataService.pendingSyncCount > 0 && offlineDataService.isOnline {
                            Button("Sync Now") {
                                offlineDataService.syncPendingData()
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .background(statusBarBackground)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSyncDetails)
    }
    
    private var syncStatusIcon: some View {
        Group {
            switch offlineDataService.syncStatus {
            case .synced:
                Image(systemName: "checkmark.circle")
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
            case .failed:
                Image(systemName: "exclamationmark.triangle")
            case .pending:
                Image(systemName: "clock")
            }
        }
        .font(.caption)
        .foregroundColor(syncStatusColor)
    }
    
    private var syncStatusColor: Color {
        switch offlineDataService.syncStatus {
        case .synced:
            return .green
        case .syncing:
            return .blue
        case .failed:
            return .red
        case .pending:
            return .orange
        }
    }
    
    private var statusBarBackground: Color {
        if !offlineDataService.isOnline {
            return Color.orange.opacity(0.1)
        } else if offlineDataService.syncStatus == .failed {
            return Color.red.opacity(0.1)
        } else if offlineDataService.pendingSyncCount > 0 {
            return Color.blue.opacity(0.1)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    private var syncStatusDescription: String {
        switch offlineDataService.syncStatus {
        case .synced:
            return "All data is synchronized"
        case .syncing:
            return "Synchronizing data with server..."
        case .failed:
            return "Sync failed. Check your connection."
        case .pending:
            return offlineDataService.pendingSyncCount > 0 
                ? "\(offlineDataService.pendingSyncCount) items pending sync"
                : "Sync pending"
        }
    }
}

struct OfflineIndicatorView: View {
    @StateObject private var offlineDataService = OfflineDataService.shared
    
    var body: some View {
        HStack(spacing: 8) {
            if !offlineDataService.isOnline {
                HStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Offline Mode")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            if offlineDataService.pendingSyncCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("\(offlineDataService.pendingSyncCount)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

struct SyncStatusBadge: View {
    @StateObject private var offlineDataService = OfflineDataService.shared
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundColor(statusColor)
            
            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var statusIcon: String {
        if !offlineDataService.isOnline {
            return "wifi.slash"
        }
        
        switch offlineDataService.syncStatus {
        case .synced:
            return "checkmark.circle"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .failed:
            return "exclamationmark.triangle"
        case .pending:
            return "clock"
        }
    }
    
    private var statusColor: Color {
        if !offlineDataService.isOnline {
            return .orange
        }
        
        switch offlineDataService.syncStatus {
        case .synced:
            return .green
        case .syncing:
            return .blue
        case .failed:
            return .red
        case .pending:
            return .orange
        }
    }
    
    private var statusText: String {
        if !offlineDataService.isOnline {
            return "Offline"
        }
        
        switch offlineDataService.syncStatus {
        case .synced:
            return "Synced"
        case .syncing:
            return "Syncing"
        case .failed:
            return "Failed"
        case .pending:
            return "Pending"
        }
    }
}

// MARK: - View Extensions

extension View {
    func withOfflineStatus() -> some View {
        VStack(spacing: 0) {
            OfflineStatusView()
            self
        }
    }
    
    func withOfflineIndicator() -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                OfflineIndicatorView()
            }
            .padding(.horizontal)
            .padding(.top, 4)
            
            self
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        OfflineStatusView()
        
        Divider()
        
        HStack {
            OfflineIndicatorView()
            Spacer()
            SyncStatusBadge()
        }
        .padding()
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}