import SwiftUI

struct ContentView: View {
    @StateObject private var authService = SimpleAuthViewModel()
    @State private var selectedTab = 0
    @State private var showingLogin = false
    
    var body: some View {
        Group {
            // Check authentication status
            if authService.isAuthenticated {
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
            Task {
                await authService.checkAuthStatus()
            }
        }
    }
}

#Preview {
    ContentView()
}