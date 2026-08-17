import WebKit

/// CSS and JS injected into every page.
///
/// The app replaces the website's chrome with native chrome: a real tab bar
/// instead of the fixed header, a real navigation bar instead of the page's
/// own title block. So the web header and footer are hidden and the padding
/// that reserved space for them is zeroed out. Nothing else about the page is
/// touched — the content is the product and it stays exactly as shipped.
enum WebScripts {

    /// Marks the document so page CSS can opt into app-specific tweaks later
    /// without user-agent sniffing, then removes the duplicated chrome.
    static let chromeCSS = """
    :root { color-scheme: light; }

    html { -webkit-text-size-adjust: 100%; }

    /* The native tab bar already provides this navigation. */
    #header,
    .site-fixed-header,
    .premium-header,
    header.premium-header,
    .mobile-menu,
    .mobile-menu-overlay,
    .mobile-menu-btn { display: none !important; }

    /* Both of these reserve room for the fixed header that no longer exists.
       Left in place they open a blank 72px–5.5rem gap at the top of every
       page. */
    body.site-has-header,
    body.site-has-header:not(.hero-page) { padding-top: 0 !important; }

    /* Footer links live in the native More menu instead. */
    footer, .site-footer, .footer { display: none !important; }

    /* iOS momentum scrolling inside any pane the site scrolls itself. */
    body { -webkit-overflow-scrolling: touch; }

    /* Kill the blue tap flash; the app supplies haptics instead. */
    * { -webkit-tap-highlight-color: rgba(0,0,0,0); }

    /* Keep the last of the content clear of the home indicator. */
    body { padding-bottom: env(safe-area-inset-bottom) !important; }

    /* Text inputs below 16px make iOS zoom the whole page on focus, which then
       never zooms back out. This is the standard fix. */
    input, select, textarea { font-size: max(16px, 1em); }
    """

    /// The native bridge. Kept deliberately small: the website does not know
    /// about it yet, so everything here degrades to nothing on the web.
    static let bridgeJS = """
    (function () {
      'use strict';
      if (window.RoomFinderNative) return;

      function post(name, body) {
        try {
          window.webkit.messageHandlers.native.postMessage(
            Object.assign({ name: name }, body || {})
          );
        } catch (e) { /* running in a plain browser */ }
      }

      window.RoomFinderNative = {
        platform: 'ios',
        // Feature flag the site can branch on: `if (window.RoomFinderNative)`.
        share: function (url, title) { post('share', { url: url || location.href, title: title || document.title }); },
        haptic: function (style) { post('haptic', { style: style || 'light' }); },
        openExternal: function (url) { post('openExternal', { url: url }); },
        setBadge: function (count) { post('badge', { count: count | 0 }); },
        requestPushPermission: function () { post('requestPush', {}); }
      };

      // Tell the shell when the document identity changes so the native title
      // and the selected tab stay truthful. The site is multi-page, but a few
      // flows (the negotiator, the listing modals) use pushState.
      var report = function () { post('page', { url: location.href, title: document.title }); };
      ['pushState', 'replaceState'].forEach(function (fn) {
        var original = history[fn];
        history[fn] = function () { var r = original.apply(this, arguments); report(); return r; };
      });
      window.addEventListener('popstate', report);
      document.addEventListener('DOMContentLoaded', report);

      // A light tap on every button press, the way native controls feel.
      document.addEventListener('click', function (e) {
        var el = e.target && e.target.closest && e.target.closest('button, .btn, a.nav-item, [role="button"]');
        if (el) post('haptic', { style: 'light' });
      }, true);
    })();
    """

    static func userScripts() -> [WKUserScript] {
        let css = chromeCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")

        // Injected at documentStart and re-applied on DOMContentLoaded: the
        // site adds `site-has-header` from JS after the nav renders, so a
        // stylesheet appended once at start can lose the race against markup
        // that has not been created yet. A style element wins either way
        // because it stays in the document, but the header is also injected
        // late — hence the re-assert.
        let injectCSS = """
        (function () {
          function apply() {
            if (document.getElementById('rf-native-chrome')) return;
            var s = document.createElement('style');
            s.id = 'rf-native-chrome';
            s.textContent = `\(css)`;
            (document.head || document.documentElement).appendChild(s);
          }
          apply();
          document.addEventListener('DOMContentLoaded', apply);
        })();
        """

        return [
            WKUserScript(source: injectCSS, injectionTime: .atDocumentStart, forMainFrameOnly: true),
            WKUserScript(source: bridgeJS,  injectionTime: .atDocumentStart, forMainFrameOnly: true)
        ]
    }
}
