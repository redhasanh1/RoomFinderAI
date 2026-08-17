import SwiftUI

struct RootTabView: View {

    @EnvironmentObject private var state: AppState

    var body: some View {
        TabView(selection: selection) {
            ForEach(AppTab.allCases) { tab in
                BrowserScreen(tab: tab, store: state.store(for: tab))
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
                    state.store(for: newValue).popToRoot()
                } else {
                    Haptics.select()
                    state.selectedTab = newValue
                }
            }
        )
    }
}
