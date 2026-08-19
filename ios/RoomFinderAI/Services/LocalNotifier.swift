import UserNotifications

/// Notifications the app raises itself, with no server involved.
///
/// A landlord agreeing is decided here, by the app reading the negotiator's
/// verdict, so there is nothing for a push server to send. Waiting for a remote
/// push would also mean the one moment the product exists for arrives late, or
/// not at all if push permission was never granted for messages.
enum LocalNotifier {

    /// Fires only if notifications are already allowed. Deliberately does not
    /// ask: a permission prompt in the middle of a negotiation is the worst
    /// possible time, and the banner on screen already carries the news.
    static func dealAgreed(headline: String, detail: String) {
        let centre = UNUserNotificationCenter.current()
        centre.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = headline
            content.body = detail
            content.sound = .default

            centre.add(UNNotificationRequest(
                identifier: "deal-\(headline)",
                content: content,
                trigger: nil          // now
            ))
        }
    }
}
