import SwiftUI

struct RootTabView: View {

    @EnvironmentObject private var state: AppState

    var body: some View {
        TabView(selection: selection) {
            ForEach(AppTab.allCases) { tab in
                Group {
                    // Listings is native: browsing and searching rooms is the
                    // app's primary task, so it is built with real controls
                    // rather than handed to a web view. Every other tab renders
                    // the site, which is where that functionality lives.
                    if tab == .listings {
                        ListingsScreen()
                    } else if tab == .negotiator {
                        NegotiatorScreen()
                    } else {
                        BrowserScreen(tab: tab, store: state.store(for: tab))
                    }
                }
                .tabItem { Label(tab.title, systemImage: tab.symbol) }
                .tag(tab)
            }
        }
        .tint(Theme.brand)
    }

    /// Intercepts selection so tapping the tab you are already on scrolls to
    /// the top or returns to that section's root — the behaviour every Apple
    /// app has, and the one people try without thinking.
    private var selection: Binding<AppTab> {
        Binding(
            get: { state.selectedTab },
            set: { newValue in
                if newValue == state.selectedTab {
                    Haptics.impact(.light)
                    // The native tabs manage their own scrolling and have no
                    // web view; asking for a store here would build one that
                    // never gets shown.
                    if newValue != .listings && newValue != .negotiator {
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
