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

    /// Restored from the last session. Someone who lives in Listings should
    /// not be dropped back on Home every launch.
    ///
    /// Only the tab is remembered, deliberately — not each tab's URL. Coming
    /// back hours later to a half-finished checkout page or a stale listing
    /// would be worse than starting at a section's root.
    @Published var selectedTab: AppTab = AppState.restoredTab() {
        didSet { UserDefaults.standard.set(selectedTab.rawValue, forKey: Self.tabKey) }
    }

    /// The room someone tapped "Negotiate this rent" on, waiting to be picked
    /// up by the Messages tab.
    ///
    /// That button used to switch tabs and nothing else, so the negotiator
    /// opened on its blank "tell me what you're after" screen with no idea
    /// which room had just been chosen. From the outside it looked like the
    /// button did nothing at all.
    ///
    /// Cleared by whoever consumes it, so returning to Messages later does not
    /// re-open a negotiation about a listing from an hour ago.
    @Published var pendingNegotiationListing: Listing?

    private static let tabKey = "lastSelectedTab"

    private static func restoredTab() -> AppTab {
        // UI tests each relaunch the app but share one install, so a restored
        // tab would leak from one test into the next and make them pass or fail
        // depending on the order they happened to run in.
        if ProcessInfo.processInfo.arguments.contains("-uiTestingResetState") {
            UserDefaults.standard.removeObject(forKey: tabKey)
            return .home
        }
        guard let raw = UserDefaults.standard.string(forKey: tabKey),
              let tab = AppTab(rawValue: raw) else { return .home }
        return tab
    }

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

    /// Tabs that render the site. Only Profile does now — the other four are
    /// native and have no web view, so a URL cannot be handed to them.
    private var webCapableTabs: Set<AppTab> { [.profile] }

    /// Send a URL to the tab that owns it and bring that tab forward.
    func route(to tab: AppTab, url: URL) {
        guard webCapableTabs.contains(tab) else {
            // Selecting the native tab is the whole action; it fetches its own
            // data and has nothing to navigate to.
            select(tab)
            return
        }
        let target = store(for: tab)
        target.loadIfNeeded()
        target.load(url)
        select(tab)
    }

    private func select(_ tab: AppTab) {
        guard selectedTab != tab else { return }
        Haptics.select()
        selectedTab = tab
    }

    /// Any site URL, routed to its owning tab. Paths with no owner — Sublease,
    /// Support, a policy page — open on the current tab so the user is not
    /// bounced somewhere unrelated to what they tapped.
    func open(_ url: URL) {
        if let owner = AppTab.owning(path: url.path) {
            route(to: owner, url: url)
            return
        }
        // Falls back to Profile, the one tab that can render a page. Sending
        // a site URL to a native tab would silently swallow the link.
        let host = webCapableTabs.contains(selectedTab) ? selectedTab : .profile
        route(to: host, url: url)
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
