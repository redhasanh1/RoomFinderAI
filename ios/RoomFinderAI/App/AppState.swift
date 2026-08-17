import Combine
import SwiftUI

/// Owns the tab selection and the five long-lived web views.
///
/// Stores are created lazily and never thrown away, which is what lets a tab
/// keep its scroll position and half-filled forms across switches. Five idle
/// `WKWebView`s cost a few tens of megabytes; the alternative is reloading the
/// page every time someone taps a tab, which is the classic tell of a wrapper.
@MainActor
final class AppState: ObservableObject {

    @Published var selectedTab: AppTab = .home
    @Published var moreDestination: MoreDestination?

    private var stores: [AppTab: WebViewStore] = [:]

    func store(for tab: AppTab) -> WebViewStore {
        if let existing = stores[tab] { return existing }
        let store = WebViewStore(homeURL: tab.url)
        store.onCrossTabNavigation = { [weak self] owner, url in
            self?.route(to: owner, url: url)
        }
        stores[tab] = store
        return store
    }

    /// Send a URL to the tab that owns it and bring that tab forward.
    func route(to tab: AppTab, url: URL) {
        let target = store(for: tab)
        target.loadIfNeeded()
        target.load(url)
        if selectedTab != tab {
            Haptics.select()
            selectedTab = tab
        }
    }

    /// Any site URL, routed to its owning tab. Paths with no owner — Sublease,
    /// Support, a policy page — open on the current tab so the user is not
    /// bounced somewhere unrelated to what they tapped.
    func open(_ url: URL) {
        if let owner = AppTab.owning(path: url.path) {
            route(to: owner, url: url)
        } else {
            let current = store(for: selectedTab)
            current.loadIfNeeded()
            current.load(url)
        }
    }

    /// Frees the web content of tabs the user is not looking at. Called on a
    /// memory warning: iOS kills the whole app if it ignores one, and a
    /// backgrounded tab can rebuild itself from its URL.
    func shedMemory() {
        for (tab, store) in stores where tab != selectedTab {
            store.releaseContent()
        }
    }
}
