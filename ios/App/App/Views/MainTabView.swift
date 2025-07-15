import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab: String, CaseIterable {
        case home = "Home"
        case search = "Search"
        case chat = "Messages"
        case profile = "Profile"
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .search: return "magnifyingglass"
            case .chat: return "message.fill"
            case .profile: return "person.fill"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: Tab.home.icon)
                    Text(Tab.home.rawValue)
                }
                .tag(Tab.home)
            
            SearchView()
                .tabItem {
                    Image(systemName: Tab.search.icon)
                    Text(Tab.search.rawValue)
                }
                .tag(Tab.search)
            
            ChatListView()
                .tabItem {
                    Image(systemName: Tab.chat.icon)
                    Text(Tab.chat.rawValue)
                }
                .tag(Tab.chat)
            
            ProfileView()
                .tabItem {
                    Image(systemName: Tab.profile.icon)
                    Text(Tab.profile.rawValue)
                }
                .tag(Tab.profile)
        }
        .accentColor(.blue)
}

#Preview {
    MainTabView()
}