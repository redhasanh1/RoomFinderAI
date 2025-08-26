import SwiftUI

@main
struct RoomFinderAIApp: App {
    private let supabase: SupabaseClient
    @StateObject private var authService: AuthService
    @StateObject private var authViewModel = SimpleAuthViewModel()
    @StateObject private var listingsViewModel: SimpleListingsViewModel
    
    init() {
        let url = URL(string: Secrets.supabaseURL)!
        let client = SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
        self.supabase = client
        _authService = StateObject(wrappedValue: AuthService(supabaseClient: client))
        _listingsViewModel = StateObject(wrappedValue: SimpleListingsViewModel(supabaseClient: client))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.supabase, supabase)
                .environmentObject(authService)
                .environmentObject(authViewModel)
                .environmentObject(listingsViewModel)
                .onAppear {
                    authViewModel.checkAuthStatus()
                }
        }
    }
}



