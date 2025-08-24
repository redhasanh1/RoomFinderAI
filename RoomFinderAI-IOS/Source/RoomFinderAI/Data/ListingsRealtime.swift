import Foundation
import Supabase
import Combine

enum RealtimeChange<T> {
    case insert(T)
    case update(T)
    case delete(T)
}

enum RealtimeConnectionStatus {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)
}

final class ListingsRealtime: ObservableObject {
    private let client = SupabaseClientProvider.shared
    private var channel: RealtimeChannelV2?
    private var onChange: ((RealtimeChange<Listing>) -> Void)?
    private var reconnectionTimer: Timer?
    private let maxReconnectAttempts = 5
    private var reconnectAttempts = 0
    
    @Published var connectionStatus: RealtimeConnectionStatus = .disconnected
    @Published var lastUpdateTime: Date?
    
    deinit {
        stop()
    }
    
    func start(onChange: @escaping (RealtimeChange<Listing>) -> Void) {
        self.onChange = onChange
        
        print("🔄 Starting real-time listings subscription...")
        connectionStatus = .connecting
        
        // Clean up existing channel
        if let existingChannel = channel {
            Task {
                await existingChannel.unsubscribe()
            }
        }
        
        // Create new channel with unique identifier
        let channelId = "listings_realtime_\(UUID().uuidString.prefix(8))"
        let channel = client.realtimeV2.channel(channelId)
        
        // Enhanced decoder with better error handling
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try multiple date formats
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSZ",
                "yyyy-MM-dd'T'HH:mm:ss.SZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss"
            ]
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            for format in formats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
            
            // Fallback to ISO8601
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        // INSERT handler
        channel.onPostgresChange(InsertAction.self, schema: "public", table: "listings") { [weak self] action in
            print("📥 Real-time INSERT event received")
            self?.handleDatabaseChange(action: action, type: .insert, decoder: decoder)
        }
        
        // UPDATE handler
        channel.onPostgresChange(UpdateAction.self, schema: "public", table: "listings") { [weak self] action in
            print("📝 Real-time UPDATE event received")
            self?.handleDatabaseChange(action: action, type: .update, decoder: decoder)
        }
        
        // DELETE handler
        channel.onPostgresChange(DeleteAction.self, schema: "public", table: "listings") { [weak self] action in
            print("🗑️ Real-time DELETE event received")
            self?.handleDatabaseChange(action: action, type: .delete, decoder: decoder)
        }
        
        self.channel = channel
        
        // Subscribe with connection status monitoring
        Task {
            do {
                // Monitor connection status
                for await status in channel.statusChange {
                    await MainActor.run {
                        self.handleConnectionStatusChange(status)
                    }
                }
            }
        }
        
        // Actually subscribe to the channel
        Task {
            do {
                try await channel.subscribe()
                await MainActor.run {
                    print("✅ Real-time listings subscription successful")
                    self.connectionStatus = .connected
                    self.reconnectAttempts = 0
                    self.reconnectionTimer?.invalidate()
                }
            } catch {
                await MainActor.run {
                    print("❌ Real-time subscription failed: \(error)")
                    self.connectionStatus = .error(error.localizedDescription)
                    self.attemptReconnection()
                }
            }
        }
    }
    
    private func handleDatabaseChange<T>(action: T, type: RealtimeChangeType, decoder: JSONDecoder) {
        Task { @MainActor in
            do {
                let listing: Listing
                
                switch type {
                case .insert:
                    if let insertAction = action as? InsertAction {
                        listing = try insertAction.decodeRecord(as: Listing.self, decoder: decoder)
                        print("✅ Decoded INSERT: \(listing.title ?? "Untitled")")
                        self.onChange?(.insert(listing))
                    }
                case .update:
                    if let updateAction = action as? UpdateAction {
                        listing = try updateAction.decodeRecord(as: Listing.self, decoder: decoder)
                        print("✅ Decoded UPDATE: \(listing.title ?? "Untitled")")
                        self.onChange?(.update(listing))
                    }
                case .delete:
                    if let deleteAction = action as? DeleteAction {
                        listing = try deleteAction.decodeOldRecord(as: Listing.self, decoder: decoder)
                        print("✅ Decoded DELETE: \(listing.title ?? "Untitled")")
                        self.onChange?(.delete(listing))
                    }
                }
                
                self.lastUpdateTime = Date()
                
            } catch {
                print("❌ Error decoding real-time listing change: \(error)")
                print("   Change type: \(type)")
                print("   Error details: \(error.localizedDescription)")
                
                // Log the raw action for debugging
                print("   Raw action: \(action)")
            }
        }
    }
    
    private func handleConnectionStatusChange(_ status: RealtimeChannelStatus) {
        switch status {
        case .subscribed:
            connectionStatus = .connected
            reconnectAttempts = 0
            print("✅ Real-time connection established")
            
        case .unsubscribed:
            connectionStatus = .disconnected
            print("🔴 Real-time connection closed")
            attemptReconnection()
            
        case .subscribing:
            connectionStatus = .connecting
            print("🔄 Real-time connection establishing...")
            
        case .unsubscribing:
            connectionStatus = .disconnected
            print("🔄 Real-time connection closing...")
            
        @unknown default:
            connectionStatus = .error("Unknown connection status")
            print("❓ Unknown real-time connection status: \(status)")
        }
    }
    
    private func attemptReconnection() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("❌ Max reconnection attempts reached")
            connectionStatus = .error("Connection failed after \(maxReconnectAttempts) attempts")
            return
        }
        
        reconnectAttempts += 1
        connectionStatus = .reconnecting
        
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // Exponential backoff, max 30s
        print("🔄 Attempting reconnection in \(delay) seconds (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
        
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performReconnection()
            }
        }
    }
    
    private func performReconnection() {
        guard let onChange = self.onChange else { return }
        print("🔄 Performing reconnection attempt \(reconnectAttempts)")
        start(onChange: onChange)
    }
    
    func stop() {
        print("🛑 Stopping real-time listings subscription")
        
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        onChange = nil
        
        Task {
            await channel?.unsubscribe()
            channel = nil
        }
        
        Task { @MainActor in
            connectionStatus = .disconnected
            lastUpdateTime = nil
        }
    }
    
    func forceReconnect() {
        print("🔄 Force reconnecting real-time subscription")
        reconnectAttempts = 0
        guard let onChange = self.onChange else { return }
        stop()
        start(onChange: onChange)
    }
}

private enum RealtimeChangeType {
    case insert, update, delete
}