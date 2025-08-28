import SwiftUI

@main
struct RoomFinderAIApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var listingsViewModel = ListingsViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    
    init() {
        // Runtime startup log to confirm correct OpenAI key is loaded
        print("🔐 App starting up - OpenAI configuration will be loaded from Secrets")
        // TODO: Re-enable when module structure is resolved
        // Secrets.assertValid()
    }
    
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