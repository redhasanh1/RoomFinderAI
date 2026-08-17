import SafariServices
import UIKit

@MainActor
enum SafariPresenter {

    /// Off-site links open here rather than in the app's own web view.
    ///
    /// Two reasons. Honesty: `SFSafariViewController` shows the real domain and
    /// padlock, so nobody can be walked into typing a password on a page they
    /// think is ours. And it shares Safari's cookie jar, which is what makes
    /// third-party sign-in work — Google refuses to authenticate inside an
    /// embedded web view.
    static func present(_ url: URL, from presenter: UIViewController) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            UIApplication.shared.open(url)
            return
        }

        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true

        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = UIColor(Theme.brand)
        safari.dismissButtonStyle = .done

        // Present from whatever is actually on screen; presenting from a
        // controller that already has something modal up silently does nothing.
        var top: UIViewController = presenter
        while let presented = top.presentedViewController { top = presented }
        top.present(safari, animated: true)
    }
}
