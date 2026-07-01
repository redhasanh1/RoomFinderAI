import Foundation
import Supabase
import Combine

// MARK: - Listings Service
@MainActor
final class ListingsService: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isConnected = false
    
    private let client: SupabaseClient
    private var realtimeChannel: RealtimeChannelV2?
    private var cancellables = Set<AnyCancellable>()
    
    init(client: SupabaseClient) {
        self.client = client
        print("📱 ListingsService initialized")
    }
    
    deinit {
        Task {
            await disconnectRealtime()
        }
    }
    
    // MARK: - Fetch Listings
    func fetchListings() async {
        isLoading = true
        error = nil
        
        do {
            print("📡 Fetching listings from Supabase...")
            
            let response = try await client
                .from("listings")
                .select("*")
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
            
            print("✅ Raw response: \(response.data.count) bytes")
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📄 Response preview: \(jsonString.prefix(200))...")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formatters = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'+00:00'",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSS'+00:00'",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSS'+00:00'",
                    "yyyy-MM-dd'T'HH:mm:ss.SSS'+00:00'",
                    "yyyy-MM-dd'T'HH:mm:ss.SS'+00:00'",
                    "yyyy-MM-dd'T'HH:mm:ss.S'+00:00'",
                    "yyyy-MM-dd'T'HH:mm:ss'+00:00'",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd'T'HH:mm:ss"
                ]
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                
                for format in formatters {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
                
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }
            
            let fetchedListings = try decoder.decode([Listing].self, from: response.data)
            self.listings = fetchedListings
            
            print("✅ Successfully fetched \(fetchedListings.count) listings")
            
            if let first = fetchedListings.first {
                print("   - First: \(first.title) - $\(first.price)")
            }
            
        } catch {
            print("❌ Error fetching listings: \(error)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Realtime Subscription
    func connectRealtime() async {
        print("🔄 Connecting to realtime listings...")
        
        realtimeChannel = client.realtimeV2.channel("public:listings")
        
        guard let channel = realtimeChannel else {
            print("❌ Failed to create realtime channel")
            return
        }
        
        // Subscribe to INSERT events
        channel
            .onPostgresChange(InsertAction.self, schema: "public", table: "listings") { [weak self] action in
                Task { @MainActor in
                    await self?.handleInsert(action)
                }
            }
        
        // Subscribe to UPDATE events  
        channel
            .onPostgresChange(UpdateAction.self, schema: "public", table: "listings") { [weak self] action in
                Task { @MainActor in
                    await self?.handleUpdate(action)
                }
            }
        
        // Subscribe to DELETE events
        channel
            .onPostgresChange(DeleteAction.self, schema: "public", table: "listings") { [weak self] action in
                Task { @MainActor in
                    await self?.handleDelete(action)
                }
            }
        
        // Monitor connection status
        Task {
            for await status in channel.statusChange {
                await MainActor.run {
                    self.handleStatusChange(status)
                }
            }
        }
        
        // Subscribe to the channel
        await channel.subscribe()
    }
    
    func disconnectRealtime() async {
        print("🔴 Disconnecting realtime...")
        
        if let channel = realtimeChannel {
            await channel.unsubscribe()
        }
        
        realtimeChannel = nil
        isConnected = false
    }
    
    // MARK: - Realtime Event Handlers
    private func handleInsert(_ action: InsertAction) async {
        do {
            let listing = try action.decodeRecord(as: Listing.self, decoder: createRealtimeDecoder())
            print("📨 New listing: \(listing.title)")
            
            // Add to beginning of list
            listings.insert(listing, at: 0)
        } catch {
            print("❌ Failed to decode insert: \(error)")
        }
    }
    
    private func handleUpdate(_ action: UpdateAction) async {
        do {
            let updatedListing = try action.decodeRecord(as: Listing.self, decoder: createRealtimeDecoder())
            print("📝 Updated listing: \(updatedListing.title)")
            
            // Find and replace existing listing
            if let index = listings.firstIndex(where: { $0.id == updatedListing.id }) {
                listings[index] = updatedListing
            }
        } catch {
            print("❌ Failed to decode update: \(error)")
        }
    }
    
    private func handleDelete(_ action: DeleteAction) async {
        do {
            let deletedListing = try action.decodeOldRecord(as: Listing.self, decoder: createRealtimeDecoder())
            print("🗑️ Deleted listing: \(deletedListing.title)")
            
            // Remove from list
            listings.removeAll { $0.id == deletedListing.id }
        } catch {
            print("❌ Failed to decode delete: \(error)")
        }
    }
    
    private func handleStatusChange(_ status: RealtimeChannelStatus) {
        switch status {
        case .subscribed:
            isConnected = true
            print("✅ Realtime connected")
        case .unsubscribed:
            isConnected = false
            print("🔴 Realtime disconnected")
        case .subscribing:
            print("🔄 Realtime connecting...")
        case .unsubscribing:
            print("🔄 Realtime disconnecting...")
        @unknown default:
            print("❓ Unknown realtime status: \(status)")
        }
    }
    
    private func createRealtimeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatters = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'+00:00'",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSS'+00:00'",
                "yyyy-MM-dd'T'HH:mm:ss.SSSS'+00:00'",
                "yyyy-MM-dd'T'HH:mm:ss.SSS'+00:00'",
                "yyyy-MM-dd'T'HH:mm:ss.SS'+00:00'",
                "yyyy-MM-dd'T'HH:mm:ss.S'+00:00'",
                "yyyy-MM-dd'T'HH:mm:ss'+00:00'",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss"
            ]
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            for format in formatters {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
            
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        
        return decoder
    }
}

// MARK: - Test Functions
extension ListingsService {
    func testConnection() async {
        print("🧪 Testing Supabase connection...")
        
        do {
            let response = try await client
                .from("listings")
                .select("count", head: true)
                .execute()
            
            let count = response.count ?? 0
            print("✅ Connection test successful: \(count) listings")
        } catch {
            print("❌ Connection test failed: \(error)")
            self.error = "Connection failed: \(error.localizedDescription)"
        }
    }
}