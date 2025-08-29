import SwiftUI
import Supabase
import Combine

@MainActor
final class ListingsViewModel: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isRealtimeConnected = false
    
    private let listingsService: ListingsService
    private var cancellables = Set<AnyCancellable>()
    
    init(supabaseClient: SupabaseClient) {
        self.listingsService = ListingsService(client: supabaseClient)
        
        // Subscribe to service updates
        listingsService.$listings
            .receive(on: DispatchQueue.main)
            .assign(to: \.listings, on: self)
            .store(in: &cancellables)
        
        listingsService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        listingsService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
        
        listingsService.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRealtimeConnected, on: self)
            .store(in: &cancellables)
    }
    
    func loadListings() async {
        await listingsService.fetchListings()
    }
    
    func connectRealtime() async {
        await listingsService.connectRealtime()
    }
    
    func disconnectRealtime() async {
        await listingsService.disconnectRealtime()
    }
    
    func testConnection() async {
        await listingsService.testConnection()
    }
}