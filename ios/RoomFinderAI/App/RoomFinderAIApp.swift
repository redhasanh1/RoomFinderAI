import SwiftUI
import UIKit

@main
struct RoomFinderAIApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .tint(Theme.brand)
                .onAppear {
                    DeepLinkRouter.shared.attach(state)
                    AppDelegate.activeState = state
                    Haptics.prepare()
                }
                // Universal links (https://www.roomfinderai.com/...) and the
                // custom scheme land in the same router, so a listing link in
                // an email opens on the Listings tab either way.
                .onOpenURL { DeepLinkRouter.shared.handle($0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { DeepLinkRouter.shared.handle(url) }
                }
        }
    }
}

/// Holds the splash over the tab bar until the first page is actually there.
private struct RootView: View {

    @EnvironmentObject private var state: AppState
    @State private var showSplash = true

    var body: some View {
        ZStack {
            RootTabView()

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // The tab being restored from last session, not necessarily Home —
            // waiting on Home's load while showing Listings would hold the
            // splash over a page nobody is about to see.
            let first = state.store(for: state.selectedTab)
            first.loadIfNeeded()

            // Whichever comes first: the page is ready, or two and a half
            // seconds have passed. The cap matters — on a bad connection an
            // uncapped splash is indistinguishable from a frozen app, and the
            // tab bar underneath is usable regardless.
            let deadline = Date().addingTimeInterval(2.5)
            while !first.hasFinishedFirstLoad && Date() < deadline {
                try? await Task.sleep(for: .milliseconds(60))
            }

            withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Set by the scene once SwiftUI has built it, so UIKit-side callbacks —
    /// memory warnings, push registration — can reach the app's state without
    /// a second source of truth.
    @MainActor static weak var activeState: AppState?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task { @MainActor in PushService.shared.configure() }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushService.shared.handleRegistration(token: deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("Push registration failed: %@", error.localizedDescription)
    }

    /// iOS terminates apps that ignore this. Dropping the inactive tabs' page
    /// content is far cheaper than being killed and relaunched cold.
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        Task { @MainActor in AppDelegate.activeState?.shedMemory() }
    }
}
