import SwiftUI

/// A single web page pushed onto a navigation stack.
///
/// Used where a native screen needs to hand off to the site for something that
/// belongs to the site — contacting a host from the native listing detail, for
/// instance. Unlike the five tab stores this one is created on push and
/// released on pop, because it represents one page rather than a section.
struct WebPageScreen: View {

    let url: URL
    let title: String

    @StateObject private var store: WebViewStore

    init(url: URL, title: String) {
        self.url = url
        self.title = title
        _store = StateObject(wrappedValue: WebViewStore(homeURL: url))
    }

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                WebViewContainer(store: store, safeArea: proxy.safeAreaInsets)
                    .ignoresSafeArea()
            }

            if store.isLoading && store.progress < 1 {
                ProgressView(value: store.progress)
                    .progressViewStyle(.linear)
                    .tint(Theme.brand)
            }

            if let failure = store.loadFailure {
                StatusScreen(
                    symbol: failure.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill",
                    title: failure.isOffline ? "No connection" : "This page didn't load",
                    message: failure.isOffline
                        ? "Reconnect and try again."
                        : failure.message,
                    actionTitle: "Try Again",
                    action: { store.reload() }
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
