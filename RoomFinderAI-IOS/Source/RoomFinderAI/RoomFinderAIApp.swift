import SwiftUI
import Supabase

// STEP 4: Exactly correct Secrets as per specification
enum Secrets {
  static let supabaseURL = "https://qzxoyzqoknywffwewrxi.supabase.co"
  static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6eG95enFva255d2Zmd2V3cnhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE5MzY0NzEsImV4cCI6MjAzNzUxMjQ3MX0.d2VDnCKX-8oJG3riFGCWLv8f5Pd8WcvgIWzjJnfKFn4"
}

@main
struct RoomFinderAIApp: App {
    private let supabase: SupabaseClient
    
    init() {
        // STEP 4: Create Supabase client with exactly correct credentials
        precondition(Secrets.supabaseURL.hasPrefix("https://"), "Supabase URL must start with https://")
        precondition(Secrets.supabaseURL.contains(".supabase.co"), "Use the Project URL ending with .supabase.co")
        precondition(!Secrets.supabaseURL.contains("app.supabase.com"), "Do NOT use dashboard URL")
        
        let url = URL(string: Secrets.supabaseURL)!
        supabase = SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
    }

    var body: some Scene {
        WindowGroup {
            ListingsScreen(supabaseClient: supabase)
        }
    }
}