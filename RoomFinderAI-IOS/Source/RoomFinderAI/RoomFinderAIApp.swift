import SwiftUI
import Supabase

@main
struct RoomFinderAIApp: App {
    private let supabase: SupabaseClient
    
    init() {
        // Create Supabase client directly with validated credentials
        let supabaseURL = "https://qzxoyzqoknywffwewrxi.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6eG95enFva255d2Zmd2V3cnhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE5MzY0NzEsImV4cCI6MjAzNzUxMjQ3MX0.d2VDnCKX-8oJG3riFGCWLv8f5Pd8WcvgIWzjJnfKFn4"
        
        precondition(supabaseURL.hasPrefix("https://"), "Supabase URL must start with https://")
        precondition(supabaseURL.contains(".supabase.co"), "Use the Project URL ending with .supabase.co")
        
        let url = URL(string: supabaseURL)!
        supabase = SupabaseClient(supabaseURL: url, supabaseKey: supabaseKey)
    }

    var body: some Scene {
        WindowGroup {
            ListingsScreen(supabaseClient: supabase) // minimal screen that just shows DB rows
        }
    }
}