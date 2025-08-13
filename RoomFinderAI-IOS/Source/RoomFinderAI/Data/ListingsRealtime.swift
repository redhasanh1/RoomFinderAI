import Foundation
import Supabase

final class ListingsRealtime {
    private let client = SupabaseConfig.client
    private var channel: RealtimeChannelV2?
    
    func start(onChange: @escaping (RealtimeChange<Listing>) -> Void) {
        let channel = client.realtimeV2.channel("public:listings")
        
        channel.onPostgresChange(InsertAction.self, schema: "public", table: "listings") { action in
            do {
                let listing = try action.decodeRecord(as: Listing.self, decoder: JSONDecoder())
                onChange(.insert(listing))
            } catch {
                print("Error decoding inserted listing: \(error)")
            }
        }
        
        channel.onPostgresChange(UpdateAction.self, schema: "public", table: "listings") { action in
            do {
                let listing = try action.decodeRecord(as: Listing.self, decoder: JSONDecoder())
                onChange(.update(listing))
            } catch {
                print("Error decoding updated listing: \(error)")
            }
        }
        
        channel.onPostgresChange(DeleteAction.self, schema: "public", table: "listings") { action in
            do {
                let listing = try action.decodeOldRecord(as: Listing.self, decoder: JSONDecoder())
                onChange(.delete(listing))
            } catch {
                print("Error decoding deleted listing: \(error)")
            }
        }
        
        self.channel = channel
        
        Task {
            do {
                try await channel.subscribe()
                print("Listings realtime subscription successful")
            } catch {
                print("Listings realtime subscription error: \(error)")
            }
        }
    }
    
    func stop() {
        Task {
            await channel?.unsubscribe()
            channel = nil
        }
    }
}