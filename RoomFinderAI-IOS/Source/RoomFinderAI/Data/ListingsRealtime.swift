import Foundation
import Supabase

final class ListingsRealtime {
    private let client = SupabaseClientProvider.shared
    private var channel: RealtimeChannel?
    
    func start(onChange: @escaping (RealtimeChange<Listing>) -> Void) {
        channel = client.realtime.channel("public:listings")
            .on(.postgresChanges(.insert, schema: "public", table: "listings")) { payload in
                do {
                    let listing = try payload.decodeRecord(as: Listing.self)
                    onChange(.insert(listing))
                } catch {
                    print("Error decoding inserted listing: \(error)")
                }
            }
            .on(.postgresChanges(.update, schema: "public", table: "listings")) { payload in
                do {
                    let listing = try payload.decodeRecord(as: Listing.self)
                    onChange(.update(listing))
                } catch {
                    print("Error decoding updated listing: \(error)")
                }
            }
            .on(.postgresChanges(.delete, schema: "public", table: "listings")) { payload in
                do {
                    let listing = try payload.decodeOldRecord(as: Listing.self)
                    onChange(.delete(listing))
                } catch {
                    print("Error decoding deleted listing: \(error)")
                }
            }
        
        channel?.subscribe { status in
            print("Listings realtime subscription status: \(status)")
        }
    }
    
    func stop() {
        channel?.unsubscribe()
        channel = nil
    }
}