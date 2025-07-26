  import SwiftUI

@main
struct RoomFinderAIApp: App {
    @StateObject private var authViewModel = SimpleAuthViewModel()
    @StateObject private var listingsViewModel = SimpleListingsViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(listingsViewModel)
                .onAppear {
                    authViewModel.checkAuthStatus()
                }
        }
    }
}

