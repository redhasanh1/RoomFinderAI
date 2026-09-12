/*
 * Android-only "get the app" bar.
 *
 * iOS already gets Apple's native smart banner from the apple-itunes-app
 * meta tag, so this deliberately does NOT run there - two banners stacked on
 * one screen is worse than none.
 *
 * Deliberately a small dismissible bar rather than a full-screen interstitial:
 * an interstitial covering the content someone just arrived to read is the
 * pattern search engines penalise and users resent, and every visitor we have
 * arrived from an outreach email that promised them something specific.
 *
 * Dismissal is remembered, so nobody is asked twice.
 */
(function () {
  var KEY = 'rfai_app_banner_dismissed';
  var PLAY = 'https://play.google.com/store/apps/details?id=com.roomfinderai.android&referrer=utm_source%3Dsite%26utm_medium%3Dmobile-banner';

  function dismissed() {
    try { return localStorage.getItem(KEY) === '1'; } catch (e) { return false; }
  }
  function remember() {
    try { localStorage.setItem(KEY, '1'); } catch (e) { /* private mode */ }
  }

  var ua = navigator.userAgent || '';
  var isAndroid = /Android/i.test(ua);
  // Never inside the Play Store webview or our own app's webview.
  var inApp = /wv\)|RoomFinderAI/i.test(ua);
  if (!isAndroid || inApp || dismissed()) return;

  function build() {
    if (document.getElementById('rfai-app-banner')) return;
    var bar = document.createElement('div');
    bar.id = 'rfai-app-banner';
    bar.setAttribute('role', 'complementary');
    bar.setAttribute('aria-label', 'Get the RoomFinderAI Android app');
    bar.style.cssText = [
      'position:fixed', 'left:0', 'right:0', 'bottom:0', 'z-index:2147483000',
      'display:flex', 'align-items:center', 'gap:12px',
      'padding:10px 12px', 'background:#ffffff',
      'border-top:1px solid rgba(0,0,0,.12)',
      'box-shadow:0 -2px 12px rgba(0,0,0,.10)',
      'font:14px/1.3 system-ui,-apple-system,Segoe UI,Roboto,sans-serif',
      'color:#1f2937'
    ].join(';');
    bar.innerHTML =
      '<img src="/favicon-32x32.png" alt="" width="32" height="32" style="border-radius:7px;flex:0 0 auto">' +
      '<div style="flex:1 1 auto;min-width:0">' +
        '<div style="font-weight:600">RoomFinderAI</div>' +
        '<div style="color:#6b7280">Post a room from one photo</div>' +
      '</div>' +
      '<a id="rfai-app-banner-get" href="' + PLAY + '" ' +
        'style="flex:0 0 auto;background:#6366f1;color:#fff;text-decoration:none;' +
        'padding:8px 14px;border-radius:8px;font-weight:600">Get</a>' +
      '<button id="rfai-app-banner-x" aria-label="Dismiss" ' +
        'style="flex:0 0 auto;background:none;border:0;font-size:20px;line-height:1;' +
        'color:#9ca3af;padding:4px 6px;cursor:pointer">&times;</button>';
    document.body.appendChild(bar);
    document.getElementById('rfai-app-banner-x').addEventListener('click', function () {
      remember();
      bar.remove();
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', build);
  } else {
    build();
  }
})();
