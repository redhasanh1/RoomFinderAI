import SwiftUI

struct RootTabView: View {

    @EnvironmentObject private var state: AppState
    /// Where Cancel goes back to.
    @State private var returnTab: AppTab = .home

    @ObservedObject private var push = PushService.shared

    var body: some View {
        TabView(selection: selection) {
            ForEach(AppTab.tabBar) { tab in
                Group {
                    // Four of the five are native. Profile stays on the site:
                    // it is login, billing, verification and account deletion,
                    // and duplicating that is how auth bugs are born.
                    switch tab {
                    case .home:       ListingsScreen(showsHero: true, title: "Home")
                    case .people:     PeopleScreen()
                    case .roompal:    RoomPalScreen()
                    case .listings:   ListingsScreen()
                    case .messages:   MessagesScreen()
                    case .sublease:   SubleaseScreen()
                    case .profile:    BrowserScreen(tab: tab, store: state.store(for: tab))
                    case .post:       postPage
                    }
                }
                .tabItem { Label(tab.title, systemImage: tab.symbol) }
                .tag(tab)
            }
        }
        .tint(Theme.brand)
        .onChange(of: state.wantsToPost) { _, wants in
            guard wants else { return }
            if state.selectedTab != .post { returnTab = state.selectedTab }
            state.selectedTab = .post
            state.wantsToPost = false
        }
        // Menu pages open over the app with their own Done button, so you come
        // back to the tab you were on rather than being left somewhere else.
        .sheet(isPresented: $state.showingLegal) { LegalScreen() }
        .task {
            // Asked once, shortly after the app is up.
            //
            // The prompt only appeared if somebody happened to tap "Yes, notify
            // me" inside Messages, so most people never saw it — and the one
            // thing this app exists to tell you, that a landlord agreed, could
            // not reach them. Delayed a moment so the first screen has drawn:
            // a permission sheet over a blank app is what gets refused.
            guard push.authorizationStatus == .notDetermined else { return }
            try? await Task.sleep(for: .seconds(2))
            guard push.authorizationStatus == .notDetermined else { return }
            push.requestAuthorization()
        }
        .sheet(item: $state.presentedPage) { page in
            NavigationStack {
                WebPageScreen(url: page.url, title: page.title)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { state.presentedPage = nil }
                        }
                    }
            }
        }
    }

    /// Which form, decided by where you were standing when you tapped plus.
    /// Handing someone a room listing form because they tapped plus while
    /// reading subleases is the wrong form entirely.
    @ViewBuilder
    private var postPage: some View {
        if returnTab == .people && state.peopleShowsRoommates {
            PostRoommateSheet(onClose: goBack)
        } else if returnTab == .people {
            PostSubleaseSheet(onClose: goBack)
        } else {
            PostListingSheet(onClose: goBack)
        }
    }

    private func goBack() {
        // Never back to Post itself. If the app was launched straight onto this
        // page there is no tab behind it, and going "back" to where you already
        // are looks exactly like Cancel being broken.
        state.selectedTab = returnTab == .post ? .home : returnTab
    }

    /// Intercepts selection for one thing: tapping the tab you are already on
    /// returns to its root.
    private var selection: Binding<AppTab> {
        Binding(
            get: { state.selectedTab },
            set: { newValue in
                if newValue == .post, state.selectedTab != .post {
                    // Remembered so Cancel can put you back where you were
                    // rather than on Home.
                    returnTab = state.selectedTab
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
