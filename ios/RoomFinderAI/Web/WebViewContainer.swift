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

    func makeUIViewController(context: Context) -> WebHostController {
        WebHostController(store: store)
    }

    func updateUIViewController(_ controller: WebHostController, context: Context) {}
}

final class WebHostController: UIViewController {

    private let store: WebViewStore

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

        // Pinned to the safe area at the bottom only. The top is deliberately
        // pinned to the raw view edge so page content scrolls up under the
        // translucent navigation bar the way it does in Safari, instead of
        // stopping at a hard line.
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        store.presenter = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        store.presenter = self
        store.loadIfNeeded()
        store.restoreIfNeeded()
    }
}
