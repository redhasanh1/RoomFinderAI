import Combine
import SwiftUI
import WebKit

/// Owns one long-lived `WKWebView`.
///
/// One store per tab, created once and kept for the life of the app, so
/// switching tabs restores exactly what you left — scroll position, form
/// contents, an open negotiation — instead of reloading. That is the single
/// biggest difference between a web view that feels like an app and one that
/// feels like a browser.
@MainActor
final class WebViewStore: NSObject, ObservableObject {

    @Published private(set) var isLoading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var canGoBack = false
    @Published private(set) var pageTitle = ""
    @Published private(set) var currentURL: URL?
    @Published var loadFailure: LoadFailure?

    /// Flips once and stays true. The splash waits on this so the app never
    /// hands over to a half-painted page.
    @Published private(set) var hasFinishedFirstLoad = false

    struct LoadFailure: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let isOffline: Bool
    }

    let webView: WKWebView
    let homeURL: URL

    /// Set by the hosting view so `window.open`, JS dialogs and Safari
    /// presentation have somewhere to appear from.
    weak var presenter: UIViewController?

    /// Called when the page navigates somewhere another tab owns, so the shell
    /// can switch tabs rather than showing Listings inside the Profile tab.
    var onCrossTabNavigation: ((AppTab, URL) -> Void)?

    private var observations: [NSKeyValueObservation] = []
    private var hasLoadedOnce = false
    private var suspendedURL: URL?

    init(homeURL: URL) {
        self.homeURL = homeURL

        let config = WKWebViewConfiguration()
        // The default (persistent) data store, shared by every tab. This is
        // what keeps one sign-in valid across all five: the site identifies
        // users from localStorage.currentUser, which lives in this store.
        // A non-persistent store here would sign the user out on every launch.
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.suppressesIncrementalRendering = false
        // Appended to the stock user agent, so the backend can tell app
        // traffic from web traffic without us pretending to be Safari.
        config.applicationNameForUserAgent = "RoomFinderAI/1.0 iOS"

        let controller = WKUserContentController()
        WebScripts.userScripts().forEach(controller.addUserScript)
        config.userContentController = controller

        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        controller.add(MessageProxy(self), name: "native")

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        // The native background shows through during the first paint and
        // behind rubber-band scrolling. White matches the site so neither
        // moment flashes a different colour.
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground

        installRefreshControl()
        observe()
    }

    // MARK: - Loading

    /// First load is deferred until the tab is actually shown. Loading all five
    /// tabs at launch would fire five simultaneous page loads and make the app
    /// feel slow at the only moment the user is watching.
    func loadIfNeeded() {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        load(homeURL)
    }

    func load(_ url: URL) {
        loadFailure = nil
        webView.load(URLRequest(url: url))
    }

    func reload() {
        loadFailure = nil
        if webView.url == nil {
            load(homeURL)
        } else {
            webView.reloadFromOrigin()
        }
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
    }

    /// Drops the rendered page but remembers where it was, so a memory warning
    /// costs the user their scroll position rather than costing them the app.
    /// The page comes back on the next `restoreIfNeeded()`.
    func releaseContent() {
        guard hasLoadedOnce, let url = webView.url, url.absoluteString != "about:blank" else { return }
        suspendedURL = url
        webView.loadHTMLString("", baseURL: nil)
    }

    /// Reloads a tab that was emptied by `releaseContent()`. Cheap and safe to
    /// call on every appearance.
    func restoreIfNeeded() {
        guard let url = suspendedURL else { return }
        suspendedURL = nil
        load(url)
    }

    /// Tapping the already-selected tab returns to its root, like Apple's apps.
    func popToRoot() {
        if webView.url?.absoluteString == homeURL.absoluteString, webView.scrollView.contentOffset.y > 0 {
            webView.scrollView.setContentOffset(
                CGPoint(x: 0, y: -webView.scrollView.adjustedContentInset.top),
                animated: true
            )
        } else {
            load(homeURL)
        }
    }

    // MARK: - Wiring

    private func installRefreshControl() {
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
    }

    @objc private func handleRefresh(_ control: UIRefreshControl) {
        Haptics.impact(.light)
        reload()
    }

    private func observe() {
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.progress = view.estimatedProgress }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.isLoading = view.isLoading }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.title, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.pageTitle = Self.displayTitle(view.title) }
            },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.currentURL = view.url }
            }
        ]
    }

    /// Page titles are written for search engines — "RoomFinderAI - Find Your
    /// Perfect Room | AI-Powered Roommate Matching", "RoomFinder AI - Login".
    /// A navigation bar wants the part that says which page this is.
    private static func displayTitle(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }

        // Drop everything after the first pipe: that clause is keyword padding.
        var title = raw.split(separator: "|").first.map(String.init) ?? raw

        // Strip a leading brand name however it is punctuated or spaced. Doing
        // this by regex rather than by literal covers "RoomFinderAI -",
        // "RoomFinder AI –" and "RoomFinderAI:" without listing each one.
        if let range = title.range(of: #"^\s*RoomFinder\s*AI\s*[-–—:|]\s*"#,
                                   options: [.regularExpression, .caseInsensitive]) {
            title.removeSubrange(range)
        }

        title = title.trimmingCharacters(in: .whitespaces)
        // A page titled only with the brand name tells the user nothing the
        // tab bar has not already said.
        if title.range(of: #"^\s*RoomFinder\s*AI\s*$"#,
                       options: [.regularExpression, .caseInsensitive]) != nil {
            return ""
        }
        return title
    }
}

// MARK: - Navigation policy

extension WebViewStore: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""

        // tel:, mailto:, maps: — hand straight to the system. Letting the web
        // view try produces an unsupported-URL error page instead of the
        // dialer.
        if AppConfig.systemSchemes.contains(scheme) {
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
            return
        }

        // Subframes load whatever they load. This method fires for every
        // iframe, ad pixel, embedded map and Turnstile widget on the page, and
        // treating those like link taps threw a Safari sheet over the homepage
        // the instant Google's ad-verification frame loaded. `targetFrame` is
        // nil for `target="_blank"`, which IS a real user intent — that case
        // falls through to the checks below.
        if let frame = navigationAction.targetFrame, !frame.isMainFrame {
            decisionHandler(.allow)
            return
        }

        // Nothing that sells the Pro plan opens in this build. The site links to
        // its pricing page from its own navigation, so blocking here is what
        // actually closes the route — hiding the link only discourages it.
        // Silent on purpose: an alert saying "buy this on our website" is itself
        // the steering that guideline 3.1.1 forbids.
        if AppConfig.blocksPurchasing(url) {
            decisionHandler(.cancel)
            return
        }

        if AppConfig.isInternal(url) {
            decisionHandler(.allow)
            // Only user-initiated navigation reassigns the tab. Redirects and
            // programmatic loads during sign-in would otherwise bounce the
            // user between tabs mid-flow.
            if navigationAction.navigationType == .linkActivated,
               let owner = AppTab.owning(path: url.path),
               owner.url != homeURL {
                onCrossTabNavigation?(owner, url)
            }
            return
        }

        // Checkout and anything else that redirects back to us has to run in
        // this web view, or the return trip lands in a sheet we cannot read.
        if AppConfig.staysInApp(url) {
            decisionHandler(.allow)
            return
        }

        // Anything else off-site opens in Safari's view controller: it shows
        // the real address and padlock, which is both the honest thing to do
        // and what App Review expects.
        decisionHandler(.cancel)
        if let presenter {
            SafariPresenter.present(url, from: presenter)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.scrollView.refreshControl?.endRefreshing()
        loadFailure = nil
        hasFinishedFirstLoad = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        report(error, on: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        report(error, on: webView)
    }

    /// The web content process can be killed under memory pressure. Without
    /// this the tab turns into a permanently blank white rectangle.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reload()
    }

    private func report(_ error: Error, on webView: WKWebView) {
        webView.scrollView.refreshControl?.endRefreshing()

        let ns = error as NSError
        // -999 is "a newer navigation replaced this one" — normal, not a failure.
        guard ns.code != NSURLErrorCancelled else { return }

        let offlineCodes: Set<Int> = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorDataNotAllowed,
            NSURLErrorTimedOut,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost
        ]
        let offline = ns.domain == NSURLErrorDomain && offlineCodes.contains(ns.code)

        loadFailure = LoadFailure(
            message: offline ? "You appear to be offline." : ns.localizedDescription,
            isOffline: offline
        )
        // A failed load still ends the launch: the splash must give way to the
        // error screen rather than sitting there until the timeout.
        hasFinishedFirstLoad = true
    }
}

// MARK: - Popups and JavaScript dialogs

extension WebViewStore: WKUIDelegate {

    /// `target="_blank"` and `window.open` return no web view by default, so
    /// those links do nothing at all. Loading them in place is what a user
    /// expects on a phone, where there are no tabs to open into.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
            // Same rule for target="_blank": a new-window link to checkout is
            // still a route to checkout.
            if AppConfig.blocksPurchasing(url) {
                return nil
            }
            if AppConfig.isInternal(url) || AppConfig.staysInApp(url) {
                webView.load(navigationAction.request)
            } else if let presenter {
                SafariPresenter.present(url, from: presenter)
            }
        }
        return nil
    }

    // WKWebView drops alert/confirm/prompt on the floor unless they are
    // implemented here. The site uses confirm() for destructive actions, so
    // without these the buttons appear dead.
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        guard let presenter else { completionHandler(); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        presenter.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        guard let presenter else { completionHandler(false); return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        presenter.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard let presenter else { completionHandler(nil); return }
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        presenter.present(alert, animated: true)
    }
}

// MARK: - JS bridge

extension WebViewStore {

    /// Held by `WKUserContentController`, which retains its handlers strongly.
    /// Going through a proxy keeps that from becoming a retain cycle that
    /// outlives the tab.
    private final class MessageProxy: NSObject, WKScriptMessageHandler {
        weak var store: WebViewStore?
        init(_ store: WebViewStore) { self.store = store }

        nonisolated func userContentController(_ controller: WKUserContentController,
                                               didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let name = body["name"] as? String else { return }
            Task { @MainActor [weak self] in
                self?.store?.handleBridge(name: name, body: body)
            }
        }
    }

    fileprivate func handleBridge(name: String, body: [String: Any]) {
        switch name {
        case "haptic":
            switch body["style"] as? String {
            case "heavy":   Haptics.impact(.heavy)
            case "medium":  Haptics.impact(.medium)
            case "success": Haptics.notify(.success)
            case "error":   Haptics.notify(.error)
            default:        Haptics.impact(.light)
            }

        case "share":
            guard let raw = body["url"] as? String, let url = URL(string: raw),
                  let presenter else { return }
            ShareService.present(url: url, title: body["title"] as? String, from: presenter)

        case "openExternal":
            guard let raw = body["url"] as? String, let url = URL(string: raw) else { return }
            UIApplication.shared.open(url)

        case "badge":
            PushService.shared.setBadge(body["count"] as? Int ?? 0)

        case "requestPush":
            PushService.shared.requestAuthorization()

        case "googleSignIn":
            startGoogleSignIn()

        case "appleSignIn":
            startAppleSignIn()

        case "user":
            // Can say who is signed in. Cannot say that nobody is.
            //
            // Signing in is native now, so a web view has no session of its own
            // — every page reports "nobody" the moment it loads. This used to
            // be believed and cleared the session, so opening any web-backed
            // screen signed the app out of itself and Messages told a signed-in
            // person to sign in. Signing out goes through AuthService, which
            // clears this properly.
            guard let incoming = (body["email"] as? String)?.nilIfEmpty else { break }
            let changed = CurrentUser.shared.email != incoming
            CurrentUser.shared.update(email: incoming)
            if changed {
                Task { await ModerationService.shared.refreshBlockList(for: incoming) }
            }

        case "page":
            if let raw = body["url"] as? String, let url = URL(string: raw) {
                currentURL = url
            }
            if let title = body["title"] as? String {
                pageTitle = Self.displayTitle(title)
            }

        default:
            break
        }
    }

    /// Runs Google's consent screen natively, then hands the authorization code
    /// back to the page so the site's own exchange-and-store logic runs. The
    /// app never sees a password and never duplicates the login logic.
    private func startGoogleSignIn() {
        Task {
            do {
                let result = try await GoogleAuthService.shared.signIn(
                    presentingFrom: presenter?.view.window
                )
                let code = Self.jsStringLiteral(result.code)
                let redirect = Self.jsStringLiteral(result.redirectURI)
                _ = try? await webView.evaluateJavaScript(
                    "window.RoomFinderNative.completeGoogleSignIn(\(code), \(redirect));"
                )
                Haptics.notify(.success)
            } catch GoogleAuthService.AuthError.cancelled {
                // Backing out of a sign-in is not an error worth a dialog.
                return
            } catch {
                Haptics.notify(.error)
                guard let presenter else { return }
                let alert = UIAlertController(
                    title: "Google Sign-In Failed",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                presenter.present(alert, animated: true)
            }
        }
    }

    /// Shows the system Sign in with Apple sheet, then hands the credential to
    /// the page, which posts it to the same endpoint the website uses.
    private func startAppleSignIn() {
        Task {
            do {
                let credential = try await AppleAuthService.shared.signIn(
                    presentingFrom: presenter?.view.window
                )

                // Shaped exactly like the AppleID JavaScript library's payload
                // so the page's handler does not need to know which one it got.
                var payload: [String: Any] = ["identityToken": credential.identityToken]
                if let code = credential.authorizationCode { payload["authorizationCode"] = code }
                if credential.firstName != nil || credential.lastName != nil {
                    payload["user"] = [
                        "name": [
                            "firstName": credential.firstName ?? "",
                            "lastName": credential.lastName ?? ""
                        ]
                    ]
                }

                guard let data = try? JSONSerialization.data(withJSONObject: payload),
                      let json = String(data: data, encoding: .utf8) else { return }

                _ = try? await webView.evaluateJavaScript("window.completeAppleSignIn(\(json));")
                Haptics.notify(.success)
            } catch AppleAuthService.AuthError.cancelled {
                return
            } catch {
                Haptics.notify(.error)
                guard let presenter else { return }
                let alert = UIAlertController(
                    title: "Sign in with Apple Failed",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                presenter.present(alert, animated: true)
            }
        }
    }

    /// Escapes a value for interpolation into evaluated JavaScript. An
    /// authorization code is opaque and could in principle contain a quote;
    /// building the literal with JSONSerialization means it can never break
    /// out of the string it is meant to be.
    private static func jsStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let array = String(data: data, encoding: .utf8),
              array.count >= 2 else {
            return "\"\""
        }
        return String(array.dropFirst().dropLast())
    }
}
