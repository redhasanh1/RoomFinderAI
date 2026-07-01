import SwiftUI
import Supabase

@main
struct RoomFinderAIApp: App {
    private let supabase = SupabaseKey.defaultValue
    init() { Secrets.assertValid() }
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationView { ListingsView() }
                    .tabItem { Label("Home", systemImage: "house") }
                NavigationView { ChatView() }
                    .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
            }
            .environment(\.supabase, supabase)
        }
    }
}