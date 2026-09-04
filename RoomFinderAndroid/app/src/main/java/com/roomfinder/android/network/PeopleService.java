package com.roomfinder.android.network;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.reflect.TypeToken;
import com.roomfinder.android.models.RoommateProfile;
import com.roomfinder.android.models.SubleaseRequest;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * The people side of the marketplace: roommate profiles and sublease posts.
 *
 * Both come from the same public API the website and the iOS app use, so no
 * credentials are needed:
 *   GET /api/roommate-profiles  -> { success, data: [...] }
 *   GET /api/sublease/search    -> { requests: [...] }
 */
public class PeopleService {
    private static final String TAG = "PeopleService";
    private static final String BASE_URL = "https://www.roomfinderai.com/api/";

    private static PeopleService instance;

    private final OkHttpClient httpClient;
    private final Gson gson;
    private final ExecutorService executor;
    private final Handler main = new Handler(Looper.getMainLooper());

    public interface RoommatesCallback {
        void onSuccess(List<RoommateProfile> profiles);

        void onError(String message);
    }

    public interface SubleasesCallback {
        void onSuccess(List<SubleaseRequest> requests);

        void onError(String message);
    }

    private PeopleService() {
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(20, TimeUnit.SECONDS)
                .build();
        this.gson = new Gson();
        this.executor = Executors.newFixedThreadPool(2);
    }

    public static synchronized PeopleService getInstance() {
        if (instance == null) {
            instance = new PeopleService();
        }
        return instance;
    }

    /**
     * @param kind {@link RoommateProfile#KIND_SEEKING} or KIND_HAS_SPOT
     * @param city optional city filter, may be null or blank
     */
    public void loadRoommates(String kind, String city, RoommatesCallback callback) {
        executor.execute(() -> {
            StringBuilder path = new StringBuilder("roommate-profiles?limit=50");
            if (kind != null && !kind.isEmpty()) {
                path.append("&user_type=").append(kind);
            }
            if (city != null && !city.trim().isEmpty()) {
                path.append("&city=").append(encode(city.trim()));
            }

            String body = get(path.toString());
            if (body == null) {
                main.post(() -> callback.onError("Couldn't reach RoomPal"));
                return;
            }
            try {
                JsonElement data = unwrap(body, "data");
                Type listType = new TypeToken<List<RoommateProfile>>() {}.getType();
                List<RoommateProfile> parsed = gson.fromJson(data, listType);

                List<RoommateProfile> profiles = new ArrayList<>();
                if (parsed != null) {
                    for (RoommateProfile profile : parsed) {
                        // Seed rows are test fixtures; they must never reach a
                        // real person browsing the app.
                        if (profile != null && profile.getId() != null && !profile.isSeed()) {
                            if (kind == null || kind.isEmpty() || kind.equals(profile.getKind())) {
                                profiles.add(profile);
                            }
                        }
                    }
                }
                Log.d(TAG, "Loaded " + profiles.size() + " roommate profiles (" + kind + ")");
                main.post(() -> callback.onSuccess(profiles));
            } catch (Exception e) {
                Log.e(TAG, "Failed to parse roommate profiles", e);
                main.post(() -> callback.onError("Couldn't load RoomPal"));
            }
        });
    }

    public void loadSubleases(String city, SubleasesCallback callback) {
        executor.execute(() -> {
            StringBuilder path = new StringBuilder("sublease/search?limit=50");
            if (city != null && !city.trim().isEmpty()) {
                path.append("&city=").append(encode(city.trim()));
            }

            String body = get(path.toString());
            if (body == null) {
                main.post(() -> callback.onError("Couldn't reach subleases"));
                return;
            }
            try {
                JsonElement data = unwrap(body, "requests");
                Type listType = new TypeToken<List<SubleaseRequest>>() {}.getType();
                List<SubleaseRequest> parsed = gson.fromJson(data, listType);

                List<SubleaseRequest> requests = new ArrayList<>();
                if (parsed != null) {
                    for (SubleaseRequest request : parsed) {
                        if (request != null && request.getId() != null && request.isActive()) {
                            requests.add(request);
                        }
                    }
                }
                Log.d(TAG, "Loaded " + requests.size() + " sublease posts");
                main.post(() -> callback.onSuccess(requests));
            } catch (Exception e) {
                Log.e(TAG, "Failed to parse subleases", e);
                main.post(() -> callback.onError("Couldn't load subleases"));
            }
        });
    }

    private String get(String path) {
        Request request = new Request.Builder()
                .url(BASE_URL + path)
                .addHeader("Accept", "application/json")
                .build();
        try (Response response = httpClient.newCall(request).execute()) {
            if (!response.isSuccessful() || response.body() == null) {
                Log.e(TAG, "GET " + path + " failed: HTTP " + response.code());
                return null;
            }
            return response.body().string();
        } catch (Exception e) {
            Log.e(TAG, "GET " + path + " failed", e);
            return null;
        }
    }

    /** Accepts {key: [...]}, {data: [...]} or a bare array. */
    private JsonElement unwrap(String body, String key) {
        JsonElement root = JsonParser.parseString(body);
        if (root.isJsonObject()) {
            JsonObject object = root.getAsJsonObject();
            if (object.has(key)) {
                return object.get(key);
            }
            if (object.has("data")) {
                return object.get("data");
            }
        }
        return root;
    }

    private static String encode(String value) {
        try {
            return java.net.URLEncoder.encode(value, "UTF-8");
        } catch (Exception e) {
            return value.replace(" ", "%20");
        }
    }
}
