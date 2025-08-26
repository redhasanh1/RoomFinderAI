import SwiftUI
import Supabase

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
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
                    
                    NewListingsView(supabaseClient: listingsViewModel.supabaseService.client)
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
                    
                    NewListingsView(supabaseClient: listingsViewModel.supabaseService.client)
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
            Task {
                authViewModel.checkAuthStatus()
            }
        }
    }
}

#Preview {
    ContentView()
}