  import SwiftUI

@main
struct RoomFinderAIApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var listingsViewModel = ListingsViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    
    init() {
        // Runtime startup log to confirm correct OpenAI key is loaded
        print("🔐 OpenAI key loaded: \(Secrets.openAIKey.hasPrefix("sk-proj-") ? "project key" : "classic key") (\(Secrets.openAIModel))")
        Secrets.assertValid()
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

