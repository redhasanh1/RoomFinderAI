import Combine
import Foundation
import UIKit
import UserNotifications

/// How many messages are waiting, for the tab bar and the app icon.
///
/// Nothing in the app said. A landlord could reply and the only sign was a push
/// notification, which is gone the moment it is swiped away — after that the
/// Messages tab looked exactly as it does when there is nothing there, so
/// somebody who missed the banner had no way to know a reply had arrived, or
/// where to look for it.
@MainActor
final class UnreadCounter: ObservableObject {

    static let shared = UnreadCounter()

    @Published private(set) var count = 0

    /// Polled rather than pushed. A push tells the phone about one message at a
    /// time and can be refused permission entirely; this is what keeps the
    /// number right regardless.
    private static let interval: TimeInterval = 30

    private var timer: Timer?
    private var watching: AnyCancellable?

    private init() {
        // Whoever is signed in owns the count, and signing out must clear it
        // rather than leave the last person's number on a stranger's screen.
        watching = CurrentUser.shared.$email
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.count = 0
                    self?.applyToAppIcon()
                    await self?.refresh()
                }
            }
    }

    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { _ in
            Task { @MainActor in await UnreadCounter.shared.refresh() }
        }

        // Coming back to the app is the moment the number is most likely to be
        // stale and most likely to be looked at.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in await UnreadCounter.shared.refresh() }
        }

        Task { await refresh() }
    }

    /// Called after a thread is opened, which marks it read server-side, so the
    /// badge stops claiming otherwise without waiting for the next poll.
    func refreshSoon() {
        Task {
            // A moment, because the read is written as the thread loads.
            try? await Task.sleep(for: .milliseconds(600))
            await refresh()
        }
    }

    /// Whoever is signed in, asked of the thing that actually knows.
    ///
    /// CurrentUser is populated by AuthService and by the web bridge, and is
    /// empty until one of them has run. Reading the auth session first means a
    /// restored sign-in counts even if nothing has touched CurrentUser yet.
    private var signedInEmail: String? {
        AuthService.shared.profile?.email ?? CurrentUser.shared.email
    }

    func refresh() async {
        guard let email = signedInEmail else {
            count = 0
            applyToAppIcon()
            return
        }

        var components = URLComponents(url: AppConfig.url("api/conversations"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "userEmail", value: email)]

        var request = URLRequest(url: components.url!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) == true,
              let decoded = try? JSONDecoder().decode(ConversationsResponse.self, from: data) else {
            // Left alone on failure. Zeroing it on a dropped connection would
            // quietly hide messages that are still waiting.
            return
        }

        count = (decoded.data ?? []).reduce(0) { $0 + ($1.unreadCount ?? 0) }
        applyToAppIcon()
    }

    /// The number on the home screen icon, which is where someone who is not in
    /// the app at all finds out.
    private func applyToAppIcon() {
        let value = count
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(value)
        }
    }
}
