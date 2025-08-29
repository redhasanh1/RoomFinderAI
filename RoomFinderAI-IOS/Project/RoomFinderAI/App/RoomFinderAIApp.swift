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
          .tabItem { Label("Search", systemImage: "magnifyingglass") }
        NavigationView { AINegotiatorViewPreview() }
          .tabItem { Label("AI", systemImage: "brain.head.profile") }
        NavigationView { Text("Messages") }
          .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }
        NavigationView { Text("Profile") }
          .tabItem { Label("Profile", systemImage: "person") }
      }
      .environment(\.supabase, supabase)
    }
  }
}