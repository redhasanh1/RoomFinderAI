import SwiftUI
import Supabase

struct ContentView: View {
    @EnvironmentObject private var authViewModel: SimpleAuthViewModel
    @EnvironmentObject private var listingsViewModel: SimpleListingsViewModel
    @State private var selectedTab = 0
    @State private var showingLogin = false
    
    var body: some View {
        Group {
            // Check authentication status
            if authViewModel.isAuthenticated {
                // Main app interface for authenticated users
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .tag(0)
                    
                    ListingsView()
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .tag(1)
                    
                    ProfileView()
                        .tabItem {
                            Image(systemName: "person.fill")
                            Text("Profile")
                        }
                        .tag(2)
                }
                .accentColor(.blue)
            } else {
                // Guest mode - show main app with login prompt
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .tag(0)
                    
                    ListingsView()
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .tag(1)
                    
                    // Profile tab shows login when not authenticated
                    LoginView()
                        .tabItem {
                            Image(systemName: "person.fill")
                            Text("Profile")
                        }
                        .tag(2)
                }
                .accentColor(.blue)
            }
        }
        .preferredColorScheme(nil)
        .onAppear {
            authViewModel.checkAuthStatus()
        }
    }
}

#Preview {
    let supabaseClient = SupabaseClient(
        supabaseURL: URL(string: "https://qzxoyzqoknywffwewrxi.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6eG95enFva255d2Zmd2V3cnhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjE1OTM5NDcsImV4cCI6MjAzNzE2OTk0N30.lO-6aKnAVaZSQYkiw6_gFJN2g48PEXK4N5h1mYqvHy4"
    )
    
    return ContentView()
        .environmentObject(SimpleAuthViewModel())
        .environmentObject(SimpleListingsViewModel(supabaseClient: supabaseClient))
}