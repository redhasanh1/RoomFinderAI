import SwiftUI

@main
struct RoomFinderAIApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var authViewModel = SimpleAuthViewModel()
    @StateObject private var listingsViewModel = SimpleListingsViewModel()
    
    init() {
        // Debug schema probe temporarily removed to fix build
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



