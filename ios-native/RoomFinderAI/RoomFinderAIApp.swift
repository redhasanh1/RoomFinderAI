import SwiftUI

@main
struct RoomFinderAIApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var listingsViewModel = ListingsViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(listingsViewModel)
                .environmentObject(chatViewModel)
                .onAppear {
                    authViewModel.checkAuthStatus()
                }
        }
    }
}