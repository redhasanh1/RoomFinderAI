import SwiftUI

struct RootTabView: View {

    @EnvironmentObject private var state: AppState
    /// Where Cancel goes back to.
    @State private var returnTab: AppTab = .home

    @ObservedObject private var push = PushService.shared
    @ObservedObject private var unread = UnreadCounter.shared

    var body: some View {
        TabView(selection: selection) {
            ForEach(AppTab.tabBar) { tab in
                Group {
                    // All of them, now including Profile. It was the last one
                    // left on the site, and being a web page is what made
                    // sign-in unreachable to VoiceOver, invisible to the app's
                    // own tests, and unable to tell the rest of the app who was
                    // signed in without a bridge posting it back.
                    switch tab {
                    case .home:       ListingsScreen(showsHero: true, title: "Home")
                    case .people:     PeopleScreen()
                    case .roompal:    RoomPalScreen()
                    case .listings:   ListingsScreen()
                    case .messages:   MessagesScreen()
                    case .sublease:   SubleaseScreen()
                    case .profile:    ProfileScreen()
                    case .post:       postPage
                    }
                }
                .tabItem { Label(tab.title, systemImage: tab.symbol) }
                // The red number every other app puts here. Without it a reply
                // that arrived while the app was closed left the tab looking
                // exactly as it does when there is nothing waiting, so there
                // was nothing to tell somebody where to tap.
                .badge(tab == .messages && unread.count > 0 ? unread.count : 0)
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
        .sheet(isPresented: $state.showingSaved) { SavedScreen() }
        .sheet(isPresented: $state.showingSupport) { SupportScreen() }
        .task {
            // Touching AuthService is what restores the saved session: its
            // init reads the stored profile and tells CurrentUser who is signed
            // in. Nothing at launch referenced it, so until somebody opened the
            // Profile tab the app believed nobody was signed in — which left
            // the unread count at zero and the badge absent for a signed-in
            // person with messages waiting.
            _ = AuthService.shared
            UnreadCounter.shared.start()
        }
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
