package com.roomfinder.android.auth;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.util.Base64;
import android.util.Log;

import androidx.browser.customtabs.CustomTabsIntent;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.roomfinder.android.models.User;
import com.roomfinder.android.utils.ApiKeys;

import java.nio.charset.StandardCharsets;

/**
 * Google / Apple sign-in through Supabase OAuth, i.e. the same flow the website
 * runs via supabase.auth.signInWithOAuth({ provider }).
 *
 * The provider consent screen opens in a Chrome Custom Tab and Supabase sends
 * the result back to the app through the {@code roomfinderai://auth-callback}
 * deep link, carrying the session in the URL fragment.
 *
 * Nothing here needs an API key baked into the APK, so Apple sign-in works even
 * when no native client ID is configured.
 */
public class SupabaseOAuthManager {
    private static final String TAG = "SupabaseOAuth";

    public static final String PROVIDER_GOOGLE = "google";
    public static final String PROVIDER_APPLE = "apple";

    /** Must also be listed under Authentication -> URL Configuration in Supabase. */
    public static final String REDIRECT_URI = "roomfinderai://auth-callback";

    private SupabaseOAuthManager() {
    }

    public static void launch(Activity activity, String provider) {
        String base = ApiKeys.SUPABASE_URL;
        if (base == null || base.isEmpty()) {
            Log.e(TAG, "SUPABASE_URL is not configured; cannot start " + provider + " sign-in");
            return;
        }
        if (!base.endsWith("/")) {
            base = base + "/";
        }

        Uri authorizeUrl = Uri.parse(base + "auth/v1/authorize")
                .buildUpon()
                .appendQueryParameter("provider", provider)
                .appendQueryParameter("redirect_to", REDIRECT_URI)
                .build();

        Log.d(TAG, "Launching " + provider + " sign-in: " + authorizeUrl);

        try {
            CustomTabsIntent tab = new CustomTabsIntent.Builder()
                    .setShowTitle(true)
                    .build();
            tab.intent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY);
            tab.launchUrl(activity, authorizeUrl);
        } catch (Exception e) {
            // No Custom Tabs provider (bare emulator images, for example)
            Log.w(TAG, "Custom Tabs unavailable, falling back to a browser intent", e);
            activity.startActivity(new Intent(Intent.ACTION_VIEW, authorizeUrl));
        }
    }

    public static boolean isCallback(Uri uri) {
        return uri != null && "roomfinderai".equals(uri.getScheme());
    }

    /** Error message carried back by Supabase, or null when the redirect is clean. */
    public static String errorFrom(Uri uri) {
        if (uri == null) {
            return null;
        }
        String error = param(uri, "error_description");
        if (error == null) {
            error = param(uri, "error");
        }
        return error;
    }

    /**
     * Builds a User from the tokens on the callback URL.
     *
     * The identity is read straight out of the access token's JWT payload, so
     * this works without an anon key for the /auth/v1/user round-trip.
     */
    public static User userFrom(Uri uri) {
        if (uri == null) {
            return null;
        }
        String accessToken = param(uri, "access_token");
        if (accessToken == null || accessToken.isEmpty()) {
            return null;
        }

        User user = new User();
        user.setAccessToken(accessToken);
        String refreshToken = param(uri, "refresh_token");
        if (refreshToken != null) {
            user.setRefreshToken(refreshToken);
        }

        JsonObject claims = decodeJwtPayload(accessToken);
        if (claims != null) {
            if (claims.has("sub")) {
                user.setId(claims.get("sub").getAsString());
            }
            if (claims.has("email")) {
                user.setEmail(claims.get("email").getAsString());
            }
            JsonObject meta = claims.getAsJsonObject("user_metadata");
            String fullName = null;
            if (meta != null) {
                if (meta.has("full_name")) {
                    fullName = meta.get("full_name").getAsString();
                } else if (meta.has("name")) {
                    fullName = meta.get("name").getAsString();
                }
                if (meta.has("avatar_url")) {
                    user.setProfileImage(meta.get("avatar_url").getAsString());
                }
            }
            applyName(user, fullName);
            user.setEmailVerified(true);
        }

        if (user.getEmail() == null) {
            Log.e(TAG, "Callback had a token but no email claim");
            return null;
        }
        return user;
    }

    private static void applyName(User user, String fullName) {
        if (fullName != null && !fullName.trim().isEmpty()) {
            String trimmed = fullName.trim();
            int space = trimmed.indexOf(' ');
            user.setFirstName(space > 0 ? trimmed.substring(0, space) : trimmed);
            user.setLastName(space > 0 ? trimmed.substring(space + 1).trim() : "");
            return;
        }
        // Apple hides the name on repeat sign-ins; fall back to the email handle.
        String email = user.getEmail();
        if (email != null && email.contains("@")) {
            user.setFirstName(email.substring(0, email.indexOf('@')));
            user.setLastName("");
        }
    }

    /** Supabase returns tokens in the fragment; errors can arrive as query params. */
    private static String param(Uri uri, String key) {
        String fragment = uri.getFragment();
        if (fragment != null && !fragment.isEmpty()) {
            for (String pair : fragment.split("&")) {
                int eq = pair.indexOf('=');
                if (eq > 0 && pair.substring(0, eq).equals(key)) {
                    return Uri.decode(pair.substring(eq + 1));
                }
            }
        }
        try {
            return uri.getQueryParameter(key);
        } catch (Exception e) {
            return null;
        }
    }

    private static JsonObject decodeJwtPayload(String jwt) {
        try {
            int firstDot = jwt.indexOf('.');
            int secondDot = firstDot < 0 ? -1 : jwt.indexOf('.', firstDot + 1);
            if (firstDot < 0 || secondDot < 0) {
                return null;
            }
            String payload = jwt.substring(firstDot + 1, secondDot);
            byte[] decoded = Base64.decode(payload, Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
            return JsonParser.parseString(new String(decoded, StandardCharsets.UTF_8)).getAsJsonObject();
        } catch (Exception e) {
            Log.e(TAG, "Could not decode access token payload", e);
            return null;
        }
    }
}
