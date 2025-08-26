import SwiftUI

@main
struct RoomFinderAIApp: App {
    private let supabase: SupabaseClient
    @StateObject private var authService: AuthService
    @StateObject private var authViewModel = SimpleAuthViewModel()
    @StateObject private var listingsViewModel: SimpleListingsViewModel
    
    init() {
        let client = SupabaseFactory.makeClient()
        self.supabase = client
        _authService = StateObject(wrappedValue: AuthService(supabaseClient: client))
        _listingsViewModel = StateObject(wrappedValue: SimpleListingsViewModel(supabaseClient: client))
    }
    /Users/arsalanamirali/Downloads/Arsalan's Career Vault/Development and CodeBase/Code Projects Portfolio/RoomFinderAI/RoomFinderAI-IOS/Project/Source/RoomFinderAI/RoomFinderAIApp.swift:12:22 Cannot find 'SupabaseFactory' in scope

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



