import SwiftUI

@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.supabase, SupabaseFactory.makeClient())
    }
  }
}