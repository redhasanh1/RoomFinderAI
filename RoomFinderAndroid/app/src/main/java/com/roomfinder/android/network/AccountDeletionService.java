package com.roomfinder.android.network;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.json.JSONObject;

import java.util.concurrent.TimeUnit;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

/**
 * Closes a RoomFinderAI account for good.
 *
 * The screen this replaces only cleared SharedPreferences and said "Account
 * deleted successfully". The account, its listings and its messages stayed on
 * the server, which made the confirmation dialog a lie and the Play Store
 * data-safety declaration wrong. This calls the server and reports what really
 * happened, so the app can stop pretending.
 *
 * The password is sent because the endpoint requires it: deletion is
 * irreversible, and every other call identifies the user with a `user-email`
 * header that anybody could set.
 */
public class AccountDeletionService {

    private static final String TAG = "AccountDeletion";
    private static final String ENDPOINT = "https://www.roomfinderai.com/api/account/delete";
    private static final MediaType JSON = MediaType.get("application/json; charset=utf-8");

    /** What the server said. `code` distinguishes the cases worth handling. */
    public interface Callback {
        void onDeleted();

        /**
         * @param code    "bad_password", "no_password", or null for anything else
         * @param message text safe to show the user
         */
        void onFailure(String code, String message);
    }

    private final Handler main = new Handler(Looper.getMainLooper());

    public void deleteAccount(String email, String password, Callback callback) {
        new Thread(() -> {
            OkHttpClient client = new OkHttpClient.Builder()
                    .connectTimeout(20, TimeUnit.SECONDS)
                    // Deleting an account touches a dozen tables and storage,
                    // so it is slower than a normal call.
                    .readTimeout(60, TimeUnit.SECONDS)
                    .build();

            try {
                JSONObject body = new JSONObject();
                body.put("email", email);
                body.put("password", password);

                Request request = new Request.Builder()
                        .url(ENDPOINT)
                        .header("User-Agent", AppUserAgent.VALUE)
                        .post(RequestBody.create(body.toString(), JSON))
                        .build();

                try (Response response = client.newCall(request).execute()) {
                    String payload = response.body() != null ? response.body().string() : "";

                    if (response.isSuccessful()) {
                        Log.d(TAG, "Account deleted: " + payload);
                        main.post(callback::onDeleted);
                        return;
                    }

                    // Read the body before judging the status: the server
                    // explains itself there, and "Incorrect password" is a very
                    // different thing to tell someone than "try again later".
                    String code = null;
                    String message = null;
                    try {
                        JSONObject error = new JSONObject(payload);
                        code = error.optString("code", null);
                        message = error.optString("error", null);
                    } catch (Exception ignored) {
                        // fall through to the generic message below
                    }

                    if (message == null || message.isEmpty()) {
                        message = "Couldn't delete your account (error " + response.code() + "). "
                                + "Please try again, or email support@roomfinderai.com.";
                    }
                    Log.w(TAG, "Delete failed: " + response.code() + " " + payload);
                    final String finalCode = code;
                    final String finalMessage = message;
                    main.post(() -> callback.onFailure(finalCode, finalMessage));
                }
            } catch (Exception e) {
                Log.e(TAG, "Delete request failed", e);
                main.post(() -> callback.onFailure(null,
                        "Couldn't reach the server. Check your connection and try again."));
            }
        }).start();
    }
}
