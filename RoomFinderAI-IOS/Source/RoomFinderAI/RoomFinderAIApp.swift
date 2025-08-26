import SwiftUI
import Supabase
import Foundation

@main
struct RoomFinderAIApp: App {
    private let supabase: SupabaseClient
    @StateObject private var authService: AuthService
    @StateObject private var authViewModel = SimpleAuthViewModel()
    @StateObject private var listingsViewModel: SimpleListingsViewModel
    
    init() {
        let url = URL(string: "https://placeholder.supabase.co")!
        let client = SupabaseClient(supabaseURL: url, supabaseKey: "placeholder-key")
        self.supabase = client
        _authService = StateObject(wrappedValue: AuthService(supabaseClient: client))
        _listingsViewModel = StateObject(wrappedValue: SimpleListingsViewModel(supabaseClient: client))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(authViewModel)
                .environmentObject(listingsViewModel)
                .onAppear {
                    authViewModel.checkAuthStatus()
                }
        }
    }
}