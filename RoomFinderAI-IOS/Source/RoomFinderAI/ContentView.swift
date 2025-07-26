import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: SimpleAuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            // Always show main app interface - authentication is optional
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
        }
        .preferredColorScheme(nil)
    }
}

#Preview {
    ContentView()
        .environmentObject(SimpleAuthViewModel())
        .environmentObject(SimpleListingsViewModel())
}