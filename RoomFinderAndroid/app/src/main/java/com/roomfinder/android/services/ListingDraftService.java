package com.roomfinder.android.services;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.Callback;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.ResponseBody;

/**
 * Fills in a listing for the host instead of making them write one.
 *
 * Two routes, the same ones the website and the iOS app use:
 *   - a photo goes to /api/analyze-property-photo, where a vision model reads
 *     the room itself and comes back with a title, a description, the property
 *     type, a bedroom count, a suggested rent and what it noticed
 *   - with no photo, /api/listings/draft writes from the facts already typed
 *
 * Writing the description is where people abandon posting a room, so this is
 * the difference between a listing existing and not.
 */
public class ListingDraftService {
    private static final String TAG = "ListingDraftService";
    private static final String BASE_URL = "https://www.roomfinderai.com/api/";
    private static final MediaType JSON = MediaType.get("application/json; charset=utf-8");

    /** Vision models are slow; this is the one place a long wait is expected. */
    private static final int ANALYSIS_TIMEOUT_SECONDS = 120;

    /**
     * A photo is downscaled before sending. Full-resolution phone photos add
     * megabytes to the request without making the model any more accurate.
     */
    private static final int MAX_DIMENSION = 900;

    private final OkHttpClient client;
    private final Handler main = new Handler(Looper.getMainLooper());

    public static class Draft {
        public String title;
        public String description;
        public String houseType;
        public Integer bedrooms;
        public Integer price;
        public String street;
        public String city;
        public String postalCode;
        /** True when the address came from an IP lookup rather than GPS. */
        public boolean locationIsApproximate;
        /** Notable things the model saw, for the "what it saw" summary. */
        public final List<String> features = new ArrayList<>();

        public boolean hasLocation() {
            return (city != null && !city.isEmpty()) || (street != null && !street.isEmpty());
        }
    }

    public interface DraftCallback {
        void onDraft(Draft draft);

        void onError(String message);
    }

    public ListingDraftService() {
        this.client = new OkHttpClient.Builder()
                .connectTimeout(20, TimeUnit.SECONDS)
                .readTimeout(ANALYSIS_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .writeTimeout(ANALYSIS_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .build();
    }

    /** Reads the room from a photo. */
    public void draftFromPhoto(Context context, Uri photoUri, DraftCallback callback) {
        String encoded = encodePhoto(context, photoUri);
        if (encoded == null) {
            callback.onError("That photo could not be read.");
            return;
        }

        try {
            JSONObject payload = new JSONObject();
            payload.put("imageBase64", encoded);

            Request request = new Request.Builder()
                    .url(BASE_URL + "analyze-property-photo")
                    .addHeader("Content-Type", "application/json")
                    .post(RequestBody.create(payload.toString(), JSON))
                    .build();

            client.newCall(request).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    Log.e(TAG, "Photo analysis failed", e);
                    post(() -> callback.onError("The photo analysis service could not be reached."));
                }

                @Override
                public void onResponse(Call call, Response response) {
                    try (ResponseBody body = response.body()) {
                        String raw = body == null ? "" : body.string();

                        // A rejected photo comes back 422 with a specific,
                        // useful reason ("this is a styled interior rendering,
                        // not a photograph of a real rental property"). Judging
                        // on the status code alone threw that away and reported
                        // a connection problem instead.
                        if (!response.isSuccessful()) {
                            String message = errorFrom(raw);
                            post(() -> callback.onError(message != null
                                    ? message
                                    : "The photo could not be analysed."));
                            return;
                        }

                        JSONObject json = new JSONObject(raw);
                        if (!json.optBoolean("success", false) || json.isNull("analysis")) {
                            String message = json.optString("error", "");
                            post(() -> callback.onError(message.isEmpty()
                                    ? "The photo could not be analysed."
                                    : message));
                            return;
                        }

                        Draft draft = parseAnalysis(json.getJSONObject("analysis"));
                        post(() -> callback.onDraft(draft));
                    } catch (Exception e) {
                        Log.e(TAG, "Failed to read analysis", e);
                        post(() -> callback.onError("Couldn't read the photo analysis."));
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Failed to build analysis request", e);
            callback.onError("Couldn't analyse that photo.");
        }
    }

    /** Writes from the details already entered, when there is no photo yet. */
    public void draftFromDetails(String city, String street, String houseType, int bedrooms,
                                 String price, boolean utilitiesIncluded, String notes,
                                 DraftCallback callback) {
        if (city == null || city.trim().isEmpty()) {
            callback.onError("Add a photo, or fill in the city and property type first.");
            return;
        }

        try {
            JSONObject payload = new JSONObject();
            payload.put("city", city.trim());
            payload.put("street", street == null ? "" : street.trim());
            payload.put("houseType", houseType == null ? "Apartment" : houseType);
            payload.put("bedrooms", bedrooms);
            payload.put("price", price == null ? "" : price.trim());
            payload.put("utilitiesIncluded", utilitiesIncluded);
            payload.put("notes", notes == null ? "" : notes.trim());

            Request request = new Request.Builder()
                    .url(BASE_URL + "listings/draft")
                    .addHeader("Content-Type", "application/json")
                    .post(RequestBody.create(payload.toString(), JSON))
                    .build();

            client.newCall(request).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    Log.e(TAG, "Draft request failed", e);
                    post(() -> callback.onError("Couldn't reach the writer. Check your connection."));
                }

                @Override
                public void onResponse(Call call, Response response) {
                    try (ResponseBody body = response.body()) {
                        String raw = body == null ? "" : body.string();
                        JSONObject json = new JSONObject(raw);
                        if (!response.isSuccessful() || !json.optBoolean("success", false)) {
                            String message = json.optString("error", "");
                            post(() -> callback.onError(message.isEmpty()
                                    ? "Couldn't write the listing."
                                    : message));
                            return;
                        }

                        Draft draft = new Draft();
                        draft.title = optString(json, "title");
                        draft.description = optString(json, "description");
                        post(() -> callback.onDraft(draft));
                    } catch (Exception e) {
                        Log.e(TAG, "Failed to read draft", e);
                        post(() -> callback.onError("Couldn't read the written listing."));
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Failed to build draft request", e);
            callback.onError("Couldn't write the listing.");
        }
    }

    private Draft parseAnalysis(JSONObject analysis) {
        Draft draft = new Draft();
        draft.title = optString(analysis, "title");
        draft.description = optString(analysis, "description");
        draft.houseType = optString(analysis, "house_type");

        if (analysis.has("bedrooms") && !analysis.isNull("bedrooms")) {
            draft.bedrooms = analysis.optInt("bedrooms");
        }
        // The worker already computed a rent from the property type, the
        // features it spotted and the postcode. Throwing it away left the host
        // guessing the one number that decides whether anyone enquires.
        if (analysis.has("suggestedPrice") && !analysis.isNull("suggestedPrice")) {
            draft.price = (int) Math.round(analysis.optDouble("suggestedPrice"));
        }

        JSONArray features = analysis.optJSONArray("features");
        if (features != null) {
            for (int i = 0; i < features.length(); i++) {
                String feature = features.optString(i, "").trim();
                if (!feature.isEmpty()) {
                    draft.features.add(feature);
                }
            }
        }

        JSONObject location = analysis.optJSONObject("location");
        if (location != null) {
            draft.street = optString(location, "street");
            draft.city = optString(location, "city");
            draft.postalCode = optString(location, "zip");
            // The vision worker rewrites "source" to "gps" for anything handed
            // to it, so an IP-derived area arrives claiming to be GPS. The
            // "approximate" flag is set by our own server and survives that.
            draft.locationIsApproximate = location.optBoolean("approximate", false)
                    || "ip".equalsIgnoreCase(optString(location, "source"));
        }
        return draft;
    }

    private String encodePhoto(Context context, Uri photoUri) {
        try (InputStream input = context.getContentResolver().openInputStream(photoUri)) {
            if (input == null) {
                return null;
            }
            Bitmap original = BitmapFactory.decodeStream(input);
            if (original == null) {
                return null;
            }
            Bitmap scaled = downscale(original);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            scaled.compress(Bitmap.CompressFormat.JPEG, 80, out);
            if (scaled != original) {
                scaled.recycle();
            }
            // Base64, not a JSON array of boxed bytes: the array form is about
            // four times the size for no extra accuracy.
            return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP);
        } catch (Exception e) {
            Log.e(TAG, "Couldn't encode photo", e);
            return null;
        }
    }

    private Bitmap downscale(Bitmap source) {
        int width = source.getWidth();
        int height = source.getHeight();
        int longest = Math.max(width, height);
        if (longest <= MAX_DIMENSION) {
            return source;
        }
        float ratio = (float) MAX_DIMENSION / longest;
        return Bitmap.createScaledBitmap(source,
                Math.round(width * ratio), Math.round(height * ratio), true);
    }

    private String errorFrom(String raw) {
        try {
            JSONObject json = new JSONObject(raw);
            String message = json.optString("error", "");
            return message.isEmpty() ? null : message;
        } catch (Exception e) {
            return null;
        }
    }

    private static String optString(JSONObject json, String key) {
        if (json == null || !json.has(key) || json.isNull(key)) {
            return null;
        }
        String value = json.optString(key, "").trim();
        return value.isEmpty() ? null : value;
    }

    private void post(Runnable action) {
        main.post(action);
    }
}
