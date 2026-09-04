package com.roomfinder.android.auth;

import android.app.Activity;
import android.app.Dialog;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;

import org.json.JSONObject;

import java.util.concurrent.TimeUnit;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * Gets a Cloudflare Turnstile token, the way the website does.
 *
 * The auth endpoints (`/api/send-reset-code` and friends) reject anything
 * without one: the app used to fail every password reset with
 * `400 Bot verification required`.
 *
 * The widget is loaded from the site's own page rather than from HTML built
 * here. A page injected with loadDataWithBaseURL has an opaque origin no matter
 * what base URL it is given, and Turnstile refuses it with error 600010
 * ("invalid domain"). Pointing the WebView at roomfinderai.com/forgot-password
 * gives the challenge the hostname its site key actually allows.
 *
 * Once solved, Turnstile writes the token into a hidden
 * `cf-turnstile-response` input inside the widget, which is read back out.
 */
public class TurnstileVerifier {
    private static final String TAG = "TurnstileVerifier";
    private static final String BASE_URL = "https://www.roomfinderai.com";
    private static final String KEY_URL = BASE_URL + "/api/turnstile-key";

    /** Cloudflare's own timeout is generous; do not wait longer than this. */
    private static final long TIMEOUT_MS = 90_000;

    public interface TokenCallback {
        void onToken(String token);

        void onError(String message);
    }

    private final Activity activity;
    private final Handler main = new Handler(Looper.getMainLooper());
    private Dialog dialog;
    private boolean settled = false;
    private TokenCallback pendingCallback;

    public TurnstileVerifier(Activity activity) {
        this.activity = activity;
    }

    public void requestToken(TokenCallback callback) {
        new Thread(() -> {
            String siteKey = fetchSiteKey();
            if (siteKey == null) {
                finish(callback, null, "Couldn't reach the verification service");
                return;
            }
            main.post(() -> showChallenge(siteKey, callback));
        }).start();
    }

    private String fetchSiteKey() {
        OkHttpClient client = new OkHttpClient.Builder()
                .connectTimeout(15, TimeUnit.SECONDS)
                .readTimeout(15, TimeUnit.SECONDS)
                .build();
        Request request = new Request.Builder().url(KEY_URL).build();
        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful() || response.body() == null) {
                Log.e(TAG, "Site key request failed: HTTP " + response.code());
                return null;
            }
            JSONObject json = new JSONObject(response.body().string());
            String key = json.optString("siteKey", "");
            return key.isEmpty() ? null : key;
        } catch (Exception e) {
            Log.e(TAG, "Could not fetch the Turnstile site key", e);
            return null;
        }
    }

    @SuppressWarnings("SetJavaScriptEnabled")
    private void showChallenge(String siteKey, TokenCallback callback) {
        if (activity.isFinishing()) {
            return;
        }
        pendingCallback = callback;

        WebView web = new WebView(activity);
        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        // Cloudflare inspects the user agent; the stock WebView string ends in
        // "; wv)" and gets a harder challenge than a normal browser.
        settings.setUserAgentString(settings.getUserAgentString().replace("; wv", ""));
        web.setBackgroundColor(0x00000000);

        // The challenge sets cookies on challenges.cloudflare.com, which counts
        // as third party inside a WebView and is blocked by default - so the
        // widget spun on "Verifying" forever and timed out.
        android.webkit.CookieManager cookies = android.webkit.CookieManager.getInstance();
        cookies.setAcceptCookie(true);
        cookies.setAcceptThirdPartyCookies(web, true);

        web.addJavascriptInterface(new Object() {
            @JavascriptInterface
            public void onToken(String token) {
                main.post(() -> {
                    dismiss();
                    finish(callback, token, null);
                });
            }

            @JavascriptInterface
            public void onFailure(String reason) {
                Log.e(TAG, "Turnstile failed: " + reason);
                main.post(() -> {
                    dismiss();
                    finish(callback, null, "Verification failed. Try again.");
                });
            }
        }, "AndroidTurnstile");

        // Most challenges pass invisibly; the dialog only matters when
        // Cloudflare decides to ask the person something.
        dialog = new Dialog(activity, android.R.style.Theme_Translucent_NoTitleBar);
        dialog.setContentView(web, new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        dialog.setCancelable(true);
        dialog.setOnCancelListener(d -> finish(callback, null, "Verification cancelled"));

        web.setWebViewClient(new android.webkit.WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                pollForToken(view);
            }
        });

        web.loadUrl(BASE_URL + "/forgot-password");
        dialog.show();

        main.postDelayed(() -> {
            if (!settled) {
                dismiss();
                finish(callback, null, "Verification timed out. Try again.");
            }
        }, TIMEOUT_MS);
    }

    /**
     * Turnstile has no callback we can register from outside the page, so the
     * hidden response field it fills in is polled instead.
     */
    private void pollForToken(WebView view) {
        if (settled) {
            return;
        }
        view.evaluateJavascript(
                "(function(){var i=document.querySelector('[name=\"cf-turnstile-response\"]');"
                + "return i?i.value:'';})();",
                value -> {
                    if (settled) {
                        return;
                    }
                    String token = value == null ? "" : value.replace("\"", "").trim();
                    if (!token.isEmpty() && !"null".equals(token)) {
                        dismiss();
                        finishWith(token);
                        return;
                    }
                    main.postDelayed(() -> pollForToken(view), 600);
                });
    }

    private void finishWith(String token) {
        if (pendingCallback != null) {
            finish(pendingCallback, token, null);
        }
    }

    private void dismiss() {
        if (dialog != null && dialog.isShowing() && !activity.isFinishing()) {
            dialog.dismiss();
        }
        dialog = null;
    }

    private void finish(TokenCallback callback, String token, String error) {
        if (settled) {
            return;
        }
        settled = true;
        main.post(() -> {
            if (token != null) {
                callback.onToken(token);
            } else {
                callback.onError(error);
            }
        });
    }
}
