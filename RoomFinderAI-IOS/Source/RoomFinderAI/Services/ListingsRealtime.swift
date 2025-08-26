import SwiftUI
import Supabase

final class ListingsRealtime: ObservableObject {
    @Published var events: [String] = []
    private var channel: RealtimeChannel?

    func start(using supabase: SupabaseClient) {
        channel = supabase.channel("realtime:listings")
            .on(.postgresChanges, event: .insert, schema: "public", table: "listings") { [weak self] payload in
                Task { @MainActor in 
                    self?.events.append("INSERT \(payload)")
                }
            }
            .on(.postgresChanges, event: .update, schema: "public", table: "listings") { [weak self] payload in
                Task { @MainActor in 
                    self?.events.append("UPDATE \(payload)")
                }
            }
            .on(.postgresChanges, event: .delete, schema: "public", table: "listings") { [weak self] payload in
                Task { @MainActor in 
                    self?.events.append("DELETE \(payload)")
                }
            }

        Task { 
            do {
                try await channel?.subscribe()
            } catch {
                await MainActor.run {
                    events.append("Subscription failed: \(error)")
                }
            }
        }
    }

    deinit { 
        Task { 
            try? await channel?.unsubscribe() 
        } 
    }
}