import SwiftUI

/// One tab: native navigation bar over a live page.
struct BrowserScreen: View {

    let tab: AppTab

    @EnvironmentObject private var state: AppState
    @ObservedObject private var network = NetworkMonitor.shared
    @ObservedObject private var push = PushService.shared

    @ObservedObject var store: WebViewStore

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // The proxy measures the safe area *inside* the navigation
                // stack, which is the only place the navigation bar and the
                // floating tab bar are both accounted for. Those numbers are
                // handed to the web view as a content inset; the view itself
                // still runs edge to edge.
                GeometryReader { proxy in
                    WebViewContainer(store: store, safeArea: proxy.safeAreaInsets)
                        .ignoresSafeArea()
                }

                LoadingBar(progress: store.progress, isLoading: store.isLoading)

                if let failure = store.loadFailure {
                    StatusScreen(
                        symbol: failure.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill",
                        title: failure.isOffline ? "No connection" : "This page didn't load",
                        message: failure.isOffline
                            ? "RoomFinderAI needs the internet to show rooms. Reconnect and try again."
                            : failure.message,
                        actionTitle: "Try Again",
                        action: { Haptics.impact(.light); store.reload() }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: store.loadFailure)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
        }
        // Reaching the offline state while a page is already up is worth a
        // banner, not a takeover — what is on screen is still readable.
        .overlay(alignment: .bottom) {
            if !network.isOnline && store.loadFailure == nil {
                OfflineBanner()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: network.isOnline)
    }

    /// The tab's own name at its root, the page's name once you have navigated
    /// away from it. Showing the SEO title on the root screen ("Find Your
    /// Perfect Room With AI") reads like a headline, not a location.
    private var title: String {
        guard let current = store.currentURL,
              current.absoluteString != store.homeURL.absoluteString,
              !store.pageTitle.isEmpty else {
            return tab.title
        }
        return store.pageTitle
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if store.canGoBack {
                Button {
                    Haptics.impact(.light)
                    store.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel("Back")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    guard let url = store.currentURL, let presenter = store.presenter else { return }
                    ShareService.present(url: url, title: store.pageTitle, from: presenter)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Button {
                    Haptics.impact(.light)
                    store.reload()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Divider()

                ForEach(MoreDestination.all) { destination in
                    Button {
                        Haptics.select()
                        state.open(AppConfig.url(destination.path))
                    } label: {
                        Label(destination.title, systemImage: destination.symbol)
                    }
                }

                // Only offered while iOS would still show the system prompt.
                // Once it has been answered this button could do nothing at
                // all, which is worse than not being there.
                if push.authorizationStatus == .notDetermined {
                    Divider()
                    Button {
                        push.requestAuthorization()
                    } label: {
                        Label("Turn On Notifications", systemImage: "bell.badge")
                    }
                }

                Divider()

                Button {
                    guard let url = store.currentURL else { return }
                    UIApplication.shared.open(url)
                } label: {
                    Label("Open in Safari", systemImage: "safari")
                }
            } label: {
                MoreMenuLabel()
            }
            .accessibilityLabel("Menu")
        }
    }
}

/// A two-point bar under the navigation bar. Deliberately not a spinner: a
/// determinate bar tells you the page is arriving, and it is the one signal a
/// web view can give honestly.
private struct LoadingBar: View {
    let progress: Double
    let isLoading: Bool

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Theme.gradient)
                .frame(width: geo.size.width * progress, height: 2.5)
                .opacity(isLoading && progress < 1 ? 1 : 0)
                .animation(.linear(duration: 0.15), value: progress)
                .animation(.easeOut(duration: 0.3), value: isLoading)
        }
        .frame(height: 2.5)
        .allowsHitTesting(false)
    }
}

private struct OfflineBanner: View {
    var body: some View {
        Label("You're offline", systemImage: "wifi.slash")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(.black.opacity(0.75)))
            .padding(.bottom, 12)
    }
}
