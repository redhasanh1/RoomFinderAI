import SwiftUI
import Supabase
import Foundation

@main
struct RoomFinderAIApp: App {
    @StateObject private var listingsViewModel: ListingsViewModel
    @StateObject private var authService: AuthService
    @StateObject private var authViewModel = SimpleAuthViewModel()
    
    init() {
        let client = SupabaseClientFactory.makeClient()
        _listingsViewModel = StateObject(wrappedValue: ListingsViewModel(supabaseClient: client))
        _authService = StateObject(wrappedValue: AuthService(supabaseClient: client))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(authViewModel) 
                .environmentObject(listingsViewModel)
                .task {
                    await listingsViewModel.testConnection()
                    await listingsViewModel.loadListings()
                    await listingsViewModel.connectRealtime()
                }
        }
    }
}