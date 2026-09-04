package com.roomfinder.android.network;

import com.roomfinder.android.BuildConfig;

/**
 * How this app identifies itself to roomfinderai.com.
 *
 * The backend skips the Cloudflare Turnstile check for requests from the app
 * (see isAppRequest in server.js) because the widget cannot complete inside an
 * app WebView - iOS hit the same wall and was exempted the same way. The
 * exemption is matched on this user agent, so every call to our own API has to
 * carry it or password reset fails with "Bot verification required".
 */
public final class AppUserAgent {

    public static final String VALUE = "RoomFinderAI/" + BuildConfig.VERSION_NAME + " Android";

    private AppUserAgent() {
    }
}
