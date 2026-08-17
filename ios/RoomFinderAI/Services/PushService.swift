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
        [.banner, .list, .sound, .badge]
    }

    /// Payloads may carry `{"url": "listings.html?id=..."}`; routing is handled
    /// by the same deep-link path as `roomfinderai://` links.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let raw = info["url"] as? String else { return }
        let url = raw.contains("://") ? URL(string: raw) : AppConfig.url(raw)
        if let url { DeepLinkRouter.shared.handle(url) }
    }
}
