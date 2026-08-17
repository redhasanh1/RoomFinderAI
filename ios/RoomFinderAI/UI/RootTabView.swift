import SwiftUI

struct RootTabView: View {

    @EnvironmentObject private var state: AppState
    @State private var isPosting = false

    var body: some View {
        TabView(selection: selection) {
            ForEach(AppTab.tabBar) { tab in
                Group {
                    // Four of the five are native. Profile stays on the site:
                    // it is login, billing, verification and account deletion,
                    // and duplicating that is how auth bugs are born.
                    switch tab {
                    case .home:       HomeScreen()
                    case .listings:   ListingsScreen()
                    case .messages:   MessagesScreen()
                    case .profile:    BrowserScreen(tab: tab, store: state.store(for: tab))
                    case .post:
                        // Never actually shown — selecting this slot opens the
                        // sheet and bounces the selection back. It exists so
                        // the tab bar has a middle item, the way it did before.
                        Color.clear
                    }
                }
                .tabItem { Label(tab.title, systemImage: tab.symbol) }
                .tag(tab)
            }
        }
        .tint(Theme.brand)
        .sheet(isPresented: $isPosting) {
            PostListingSheet()
        }
    }

    /// Intercepts selection for two things: tapping the tab you are already on
    /// returns to its root, and tapping Post opens the sheet instead of
    /// navigating anywhere.
    private var selection: Binding<AppTab> {
        Binding(
            get: { state.selectedTab },
            set: { newValue in
                guard newValue != .post else {
                    Haptics.impact(.medium)
                    isPosting = true
                    // Deliberately does NOT assign selectedTab: the user stays
                    // where they were, so dismissing the sheet puts them back
                    // rather than on a blank screen.
                    return
                }

                if newValue == state.selectedTab {
                    Haptics.impact(.light)
                    // Only the web-backed tab keeps a store to pop; the native
                    // screens manage their own scrolling.
                    if newValue == .profile {
                        state.store(for: newValue).popToRoot()
                    }
                } else {
                    Haptics.select()
                    state.selectedTab = newValue
                }
            }
        )
    }
}
