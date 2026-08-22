import UIKit
import UserNotifications

/// Push registration and badge handling.
///
/// Permission is deliberately NOT requested at launch. iOS gives each app one
/// chance at the system prompt, and asking before the user has seen a listing
/// is how apps end up permanently denied. It is requested from the Profile tab
/// and from `RoomFinderNative.requestPushPermission()` once the site has a
/// reason to send something.
@MainActor
final class PushService: NSObject, ObservableObject {

    static let shared = PushService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?

    private override init() { super.init() }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        refreshStatus()
    }

    func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in self.authorizationStatus = settings.authorizationStatus }
        }
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Task { @MainActor in
                self.refreshStatus()
                guard granted else { return }
                Haptics.notify(.success)
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func handleRegistration(token: Data) {
        deviceToken = token.map { String(format: "%02x", $0) }.joined()
        Task { await registerWithServer() }
    }

    /// Hand the token to the server, which is the only thing that can turn it
    /// into a notification.
    ///
    /// This used to be the end of the line: the token was computed, stored in
    /// the property above, and nothing ever read it — so the app asked for
    /// permission to send notifications it had no way of sending.
    ///
    /// Called again whenever the signed-in address changes, because the token
    /// belongs to the phone and the server files it under whoever is using it.
    func registerWithServer() async {
        guard let deviceToken, let email = CurrentUser.shared.email else { return }

        var request = URLRequest(url: AppConfig.url("api/push/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "userEmail": email,
            "token": deviceToken,
            "environment": Self.apnsEnvironment
        ])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            // Worth a line either way: "I never get notifications" is
            // otherwise invisible from the outside.
            if (200..<300).contains(code) {
                print("Push: registered device with server")
            } else {
                print("Push: server rejected the device token (HTTP \(code))")
            }
        } catch {
            // Not worth surfacing or retrying hard — the next launch registers
            // again, and nothing the user is doing right now depends on it.
            print("Push: could not reach the server to register: \(error.localizedDescription)")
        }
    }

    /// Release the token when someone signs out, so the next person to use
    /// this phone does not get the last one's messages.
    func unregisterWithServer() async {
        guard let deviceToken else { return }

        var request = URLRequest(url: AppConfig.url("api/push/unregister"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["token": deviceToken])

        _ = try? await URLSession.shared.data(for: request)
    }

    /// Debug builds get a sandbox token, which the production APNs host
    /// rejects outright, so the server has to be told which one this is.
    private static var apnsEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(max(0, count))
    }
}

extension PushService: UNUserNotificationCenterDelegate {

    /// Show notifications even while the app is in the foreground — a message
    /// from a landlord matters whether or not you happen to be on that tab.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // The count, the moment the message lands. Polling every thirty seconds
        // meant the banner arrived and the red number followed up to half a
        // minute later, which reads as the app not having noticed.
        await UnreadCounter.shared.refresh()
        return [.banner, .list, .sound, .badge]
    }

    /// Payloads may carry `{"url": "listings.html?id=..."}`.
    ///
    /// Only paths that belong to a tab are followed. A payload pointing at a
    /// page that does not exist used to be opened anyway, which is how tapping a
    /// message notification landed on a 404 — the server was sending
    /// `messages.html`, a page this site has never had. Anything unrecognised
    /// now opens Messages, which is where a notification about a message should
    /// go regardless.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // Tapping one means going to read it, so the count is refreshed here
        // too rather than waiting for the next poll to catch up.
        await UnreadCounter.shared.refresh()

        let info = response.notification.request.content.userInfo
        let raw = (info["url"] as? String) ?? ""

        let path = raw.contains("://")
            ? (URL(string: raw)?.path.split(separator: "/").last.map(String.init) ?? "")
            : String(raw.split(separator: "?").first ?? "")

        await MainActor.run {
            if !path.isEmpty, AppTab.owning(path: path) != nil,
               let url = raw.contains("://") ? URL(string: raw) : AppConfig.url(raw) {
                DeepLinkRouter.shared.handle(url)
            } else {
                DeepLinkRouter.shared.handle(AppConfig.url("ai-negotiator.html"))
            }
        }
    }
}
