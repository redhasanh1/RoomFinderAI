import SwiftUI
import Supabase
import Foundation

@main
struct RoomFinderAIApp: App {
    @StateObject private var listingsViewModel: SimpleListingsViewModel
    @StateObject private var authViewModel = SimpleAuthViewModel()
    
    init() {
        let supabaseClient = SupabaseClient(
            supabaseURL: URL(string: "https://qzxoyzqoknywffwewrxi.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6eG95enFva255d2Zmd2V3cnhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE1OTM5NDcsImV4cCI6MjAzNzE2OTk0N30.lO-6aKnAVaZSQYkiw6_gFJN2g48PEXK4N5h1mYqvHy4"
        )
        _listingsViewModel = StateObject(wrappedValue: SimpleListingsViewModel(supabaseClient: supabaseClient))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel) 
                .environmentObject(listingsViewModel)
        }
    }
}