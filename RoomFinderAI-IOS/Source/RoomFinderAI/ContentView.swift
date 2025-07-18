import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
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
                
                ChatView()
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("Messages")
                    }
                    .tag(2)
                
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
                    .tag(3)
            }
            .accentColor(.blue)
        }
        .preferredColorScheme(nil)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(ListingsViewModel())
        .environmentObject(ChatViewModel())
}