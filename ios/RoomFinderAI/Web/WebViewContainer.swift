import SwiftUI
import WebKit

/// Bridges the long-lived `WKWebView` into SwiftUI.
///
/// A `UIViewControllerRepresentable` rather than a `UIViewRepresentable`
/// because the store needs a real view controller to present from — the share
/// sheet, JavaScript alerts and `SFSafariViewController` all require one, and
/// digging for the key window's root controller breaks the moment anything
/// else is already presented.
struct WebViewContainer: UIViewControllerRepresentable {

    @ObservedObject var store: WebViewStore

    /// Measured by SwiftUI *inside* the navigation stack, so it already
    /// accounts for the navigation bar and the floating tab bar.
    let safeArea: EdgeInsets

    func makeUIViewController(context: Context) -> WebHostController {
        let controller = WebHostController(store: store)
        controller.apply(safeArea: safeArea)
        return controller
    }

    func updateUIViewController(_ controller: WebHostController, context: Context) {
        controller.apply(safeArea: safeArea)
    }
}

final class WebHostController: UIViewController {

    private let store: WebViewStore
    private var appliedInsets: UIEdgeInsets = .zero

    init(store: WebViewStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let webView = store.webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // Edge to edge on purpose. The page paints behind the translucent
        // navigation bar and the floating tab bar, the way Safari does, and the
        // content inset below keeps anything from being trapped under them.
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        store.presenter = self
    }

    /// Insets the scrollable content by the bar heights.
    ///
    /// `contentInsetAdjustmentBehavior` is `.never` because the web view is
    /// laid out ignoring the safe area — left to itself it would compute zero
    /// and let the page's last control sit permanently under the tab bar,
    /// which is exactly what happened to the negotiator's "Login Required"
    /// button.
    func apply(safeArea: EdgeInsets) {
        let insets = UIEdgeInsets(
            top: safeArea.top,
            left: 0,
            bottom: safeArea.bottom,
            right: 0
        )
        guard insets != appliedInsets else { return }
        appliedInsets = insets

        let scrollView = store.webView.scrollView
        // Preserve where the user is: changing contentInset shifts the visible
        // region, so the offset has to move with it or the page jumps.
        let previousTop = scrollView.contentInset.top
        scrollView.contentInset = insets
        scrollView.verticalScrollIndicatorInsets = insets

        if scrollView.contentOffset.y <= -previousTop + 1 {
            scrollView.contentOffset.y = -insets.top
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        store.presenter = self
        store.loadIfNeeded()
        store.restoreIfNeeded()
    }
}
