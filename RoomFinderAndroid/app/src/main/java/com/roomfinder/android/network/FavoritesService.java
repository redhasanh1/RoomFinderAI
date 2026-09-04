package com.roomfinder.android.network;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.roomfinder.android.models.Listing;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.TimeUnit;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

/**
 * Saved rooms, stored on the server rather than pretended at.
 *
 * The heart button used to do this:
 *
 *     listing.setFavorite(!listing.isFavorite());
 *     adapter.notifyItemChanged(position);
 *     // TODO: Save to local storage
 *
 * and the detail screen showed a "Added to favorites" toast next to the same
 * TODO. Meanwhile FavoritesFragment read a SharedPreferences key called
 * "favorite_listings" that nothing anywhere ever wrote. So every heart tap
 * animated, claimed success, and left Saved rooms empty forever - the loop
 * could not close even in principle.
 *
 * The backend has had /api/favorites the whole time. This calls it.
 *
 * Favourites belong to an account, not a device, which is also why they are
 * not kept in SharedPreferences: the website reads the same list, and someone
 * who saves a room on their phone expects to find it when they open the site.
 */
public class FavoritesService {

    private static final String TAG = "FavoritesService";
    private static final String BASE_URL = "https://www.roomfinderai.com/api/";
    private static final MediaType JSON = MediaType.get("application/json; charset=utf-8");

    public interface ListCallback {
        void onLoaded(List<Listing> favorites);

        void onError(String message);
    }

    public interface ChangeCallback {
        void onDone(boolean isFavoriteNow);

        void onError(String message);
    }

    private static FavoritesService instance;

    private final OkHttpClient client;
    private final Handler main = new Handler(Looper.getMainLooper());

    /**
     * Ids the user has saved. Held so a list of cards can be drawn with the
     * right heart state without asking the server per row.
     */
    private final Set<String> favoriteIds = new HashSet<>();
    private boolean idsLoaded = false;

    private FavoritesService() {
        client = new OkHttpClient.Builder()
                .connectTimeout(20, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .build();
    }

    public static synchronized FavoritesService get() {
        if (instance == null) {
            instance = new FavoritesService();
        }
        return instance;
    }

    /** True if we already know this room is saved. */
    public boolean isFavorite(String listingId) {
        return listingId != null && favoriteIds.contains(listingId);
    }

    public boolean hasLoadedIds() {
        return idsLoaded;
    }

    /** Forget the cached ids - call on sign out, so the next account starts clean. */
    public void clear() {
        favoriteIds.clear();
        idsLoaded = false;
    }

    /**
     * Adds or removes, and reports the state it ended in.
     *
     * The caller should not flip its own UI first and assume: the point of the
     * rewrite is that the heart reflects what the server actually stored.
     */
    public void toggle(String userEmail, Listing listing, ChangeCallback callback) {
        if (listing == null || listing.getId() == null) {
            callback.onError("That room is missing an id");
            return;
        }
        final String id = listing.getId();
        final boolean wasFavorite = favoriteIds.contains(id);

        new Thread(() -> {
            try {
                Request request;
                if (wasFavorite) {
                    request = new Request.Builder()
                            .url(BASE_URL + "favorites/" + id + "?userEmail=" + encode(userEmail))
                            .header("User-Agent", AppUserAgent.VALUE)
                            .delete()
                            .build();
                } else {
                    JSONObject body = new JSONObject();
                    body.put("listingId", id);
                    body.put("userEmail", userEmail);
                    request = new Request.Builder()
                            .url(BASE_URL + "favorites")
                            .header("User-Agent", AppUserAgent.VALUE)
                            .post(RequestBody.create(body.toString(), JSON))
                            .build();
                }

                try (Response response = client.newCall(request).execute()) {
                    String payload = response.body() != null ? response.body().string() : "";
                    // Removing something already gone, or adding something
                    // already there, both leave the user where they wanted to
                    // be. Treat them as success rather than showing an error
                    // for a state they already have.
                    boolean ok = response.isSuccessful()
                            || (wasFavorite && response.code() == 404)
                            || payload.contains("alreadyFavorited");

                    if (ok) {
                        final boolean nowFavorite = !wasFavorite;
                        if (nowFavorite) {
                            favoriteIds.add(id);
                        } else {
                            favoriteIds.remove(id);
                        }
                        main.post(() -> callback.onDone(nowFavorite));
                    } else {
                        Log.w(TAG, "Toggle failed: " + response.code() + " " + payload);
                        main.post(() -> callback.onError("Couldn't save that room. Try again."));
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "Toggle request failed", e);
                main.post(() -> callback.onError("Couldn't reach the server. Check your connection."));
            }
        }).start();
    }

    /** The user's saved rooms, newest first, as the server has them. */
    public void loadFavorites(String userEmail, ListCallback callback) {
        new Thread(() -> {
            try {
                Request request = new Request.Builder()
                        .url(BASE_URL + "favorites?userEmail=" + encode(userEmail))
                        .header("User-Agent", AppUserAgent.VALUE)
                        .get()
                        .build();

                try (Response response = client.newCall(request).execute()) {
                    String payload = response.body() != null ? response.body().string() : "";
                    if (!response.isSuccessful()) {
                        Log.w(TAG, "Load failed: " + response.code() + " " + payload);
                        main.post(() -> callback.onError("Couldn't load your saved rooms"));
                        return;
                    }

                    JSONArray array = new JSONArray(payload);
                    List<Listing> favorites = new ArrayList<>();
                    favoriteIds.clear();
                    for (int i = 0; i < array.length(); i++) {
                        Listing listing = fromRow(array.getJSONObject(i));
                        if (listing != null && listing.getId() != null) {
                            listing.setFavorite(true);
                            favorites.add(listing);
                            favoriteIds.add(listing.getId());
                        }
                    }
                    idsLoaded = true;
                    main.post(() -> callback.onLoaded(favorites));
                }
            } catch (Exception e) {
                Log.e(TAG, "Load request failed", e);
                main.post(() -> callback.onError("Couldn't reach the server. Check your connection."));
            }
        }).start();
    }

    /**
     * Builds a Listing from a raw listings row.
     *
     * /api/listings hands back rows already shaped for this app, but
     * /api/favorites returns the database columns untouched - `city` rather
     * than `location`, `house_type` rather than `propertyType`, and the photo
     * inside a `media` array. Gson would silently leave every one of those
     * null and the saved rooms would render as blank cards, so the same
     * mapping the server applies is done here by hand.
     */
    private Listing fromRow(JSONObject row) {
        try {
            Listing listing = new Listing();
            listing.setId(row.optString("id", null));
            listing.setTitle(row.optString("title", null));
            listing.setDescription(row.optString("description", null));
            listing.setPrice(row.optDouble("price", 0));
            listing.setBedrooms(row.optInt("bedrooms", 0));
            listing.setBathrooms(row.optInt("bathrooms", 1));
            listing.setCity(row.optString("city", row.optString("location", null)));
            listing.setHouseType(row.optString("house_type", row.optString("propertyType", null)));
            listing.setCreatedAt(row.optString("created_at", row.optString("createdAt", null)));
            listing.setUserEmail(row.optString("user_email", null));

            String street = row.optString("street", "");
            String city = row.optString("city", "");
            String postal = row.optString("postal_code", "");
            String address = (street + ", " + city + " " + postal).trim();
            listing.setStreet(address.equals(",") ? null : address);

            // media is [{url: ...}] or ["https://..."] depending on how the
            // row was written; both shapes exist in the table.
            JSONArray media = row.optJSONArray("media");
            if (media != null && media.length() > 0) {
                List<String> urls = new ArrayList<>();
                for (int i = 0; i < media.length(); i++) {
                    Object item = media.opt(i);
                    if (item instanceof String) {
                        urls.add((String) item);
                    } else if (item instanceof JSONObject) {
                        JSONObject obj = (JSONObject) item;
                        String url = obj.optString("url", obj.optString("data", null));
                        if (url != null && !url.isEmpty()) {
                            urls.add(url);
                        }
                    }
                }
                if (!urls.isEmpty()) {
                    listing.setImageUrl(urls.get(0));
                    listing.setImageUrls(urls);
                }
            }
            if (listing.getImageUrl() == null) {
                String direct = row.optString("imageUrl", null);
                if (direct != null && !direct.isEmpty() && !"null".equals(direct)) {
                    listing.setImageUrl(direct);
                }
            }
            return listing;
        } catch (Exception e) {
            Log.w(TAG, "Skipping unparseable favourite row", e);
            return null;
        }
    }

    private String encode(String value) {
        try {
            return java.net.URLEncoder.encode(value == null ? "" : value, "UTF-8");
        } catch (Exception e) {
            return "";
        }
    }
}
