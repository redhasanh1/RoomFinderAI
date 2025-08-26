import Supabase
import SwiftUI
import Foundation

final class ListingsRealtime: ObservableObject {
    @Published var eventsLog: [String] = []
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    
    private var channel: RealtimeChannel?
    private weak var supabaseClient: SupabaseClient?
    
    func start(using supabase: SupabaseClient) {
        self.supabaseClient = supabase
        
        DispatchQueue.main.async {
            self.eventsLog.append("🚀 Starting realtime connection...")
            self.connectionStatus = "Connecting..."
        }
        
        channel = supabase.channel("realtime:listings")
            .on(.postgresChanges, event: .insert, schema: "public", table: "listings") { [weak self] payload in
                Task { @MainActor in 
                    self?.eventsLog.append("✅ INSERT: \(payload)")
                }
            }
            .on(.postgresChanges, event: .update, schema: "public", table: "listings") { [weak self] payload in
                Task { @MainActor in 
                    self?.eventsLog.append("🔄 UPDATE: \(payload)")
                }
            }
            .on(.postgresChanges, event: .delete, schema: "public", table: "listings") { [weak self] payload in
                Task { @MainActor in 
                    self?.eventsLog.append("🗑️ DELETE: \(payload)")
                }
            }
            .on(.system, event: .join) { [weak self] _ in
                Task { @MainActor in
                    self?.isConnected = true
                    self?.connectionStatus = "Connected ✅"
                    self?.eventsLog.append("🎉 Realtime connected successfully!")
                }
            }
            .on(.system, event: .leave) { [weak self] _ in
                Task { @MainActor in
                    self?.isConnected = false
                    self?.connectionStatus = "Disconnected ❌"
                    self?.eventsLog.append("👋 Realtime disconnected")
                }
            }
            .on(.system, event: .error) { [weak self] payload in
                Task { @MainActor in
                    self?.connectionStatus = "Error ❌"
                    self?.eventsLog.append("❌ Realtime error: \(payload)")
                }
            }
        
        Task {
            do {
                try await channel?.subscribe()
                await MainActor.run {
                    self.eventsLog.append("📡 Subscription request sent")
                }
            } catch {
                await MainActor.run {
                    self.connectionStatus = "Subscription failed ❌"
                    self.eventsLog.append("❌ Subscription error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stop() {
        channel?.unsubscribe()
        channel = nil
        
        Task { @MainActor in
            self.isConnected = false
            self.connectionStatus = "Disconnected"
            self.eventsLog.append("🛑 Realtime stopped")
        }
    }
    
    func clearLog() {
        eventsLog.removeAll()
    }
    
    deinit {
        stop()
    }
}