import SwiftUI

/// The overflow menu, shared by every tab.
///
/// It carries the pages that are not tabs — Sublease, Saved, Legal, Pricing,
/// Support, and the two Apple expects to be reachable without an account:
/// the privacy policy and the terms.
///
/// It lives here rather than on the web-view screen because three tabs are now
/// native and had no menu at all, which quietly made those pages unreachable
/// from most of the app.
struct MoreMenu<Extra: View>: View {

    @EnvironmentObject private var state: AppState
    @ObservedObject private var push = PushService.shared

    /// Screen-specific items shown above the shared ones — Share and Refresh
    /// on a web page, Start Over in the negotiator.
    @ViewBuilder var extra: Extra

    init(@ViewBuilder extra: () -> Extra = { EmptyView() }) {
        self.extra = extra()
    }

    var body: some View {
        Menu {
            extra

            if !(Extra.self == EmptyView.self) { Divider() }

            ForEach(MoreDestination.all) { destination in
                Button {
                    Haptics.select()
                    state.open(AppConfig.url(destination.path))
                } label: {
                    Label(destination.title, systemImage: destination.symbol)
                }
                // Namespaced because other tabs keep views alive with the same
                // names — Home has its own "Sublease" tile, for instance.
                .accessibilityIdentifier("more-\(destination.title)")
            }

            // Only offered while iOS would still show the system prompt. Once
            // it has been answered this button could do nothing at all, which
            // is worse than not being there.
            if push.authorizationStatus == .notDetermined {
                Divider()
                Button {
                    push.requestAuthorization()
                } label: {
                    Label("Turn On Notifications", systemImage: "bell.badge")
                }
            }
        } label: {
            MoreMenuLabel()
        }
        .accessibilityLabel("Menu")
    }
}

/// The menu button, so every screen shows the same one.
///
/// Three lines, not three dots: an ellipsis is the vaguest control in the
/// language, saying "something else exists" without saying what. It also lived
/// in two places, so changing it on the native screens left the web-backed
/// tabs still showing the old glyph.
struct MoreMenuLabel: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.brand)
            .frame(width: 34, height: 34)
            .background(Circle().fill(Theme.brand.opacity(0.12)))
    }
}
