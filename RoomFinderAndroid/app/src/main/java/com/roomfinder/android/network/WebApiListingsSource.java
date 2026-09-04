package com.roomfinder.android.network;

import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.JsonElement;
import com.google.gson.JsonParser;
import com.google.gson.reflect.TypeToken;
import com.roomfinder.android.models.Listing;

import java.lang.reflect.Type;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * Listings source backed by the public roomfinderai.com API.
 *
 * This is the same endpoint the website uses. It needs no API key, and its JSON
 * matches the {@link Listing} model field for field (location / address /
 * propertyType / imageUrl / imageUrls / createdAt), so it is the reliable path
 * when Supabase credentials are absent or the direct REST call fails.
 */
public class WebApiListingsSource {
    private static final String TAG = "WebApiListings";
    private static final String BASE_URL = "https://www.roomfinderai.com/api/";

    private static WebApiListingsSource instance;

    private final OkHttpClient httpClient;
    private final Gson gson;

    /**
     * The progressive loader asks for "the first 5", then "more from 5", then
     * "more from 20", then refreshes in the background - and this API returns
     * the whole set every time, so a cold start fired four identical full
     * downloads within a few seconds. One short-lived cache collapses that
     * burst into a single request without making the list feel stale.
     */
    private static final long BURST_CACHE_MS = 30_000;
    private List<Listing> cachedListings;
    private long cachedAt;

    private WebApiListingsSource() {
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(20, TimeUnit.SECONDS)
                .writeTimeout(20, TimeUnit.SECONDS)
                .connectionPool(new okhttp3.ConnectionPool(5, 5, TimeUnit.MINUTES))
                .build();
        this.gson = new Gson();
    }

    public static synchronized WebApiListingsSource getInstance() {
        if (instance == null) {
            instance = new WebApiListingsSource();
        }
        return instance;
    }

    public List<Listing> getAllListings() {
        synchronized (this) {
            if (cachedListings != null && elapsedSinceCache() < BURST_CACHE_MS) {
                Log.d(TAG, "Reusing listings fetched " + elapsedSinceCache() + "ms ago");
                return new ArrayList<>(cachedListings);
            }
        }

        List<Listing> listings = parseList(get("listings"));
        if (!listings.isEmpty()) {
            synchronized (this) {
                cachedListings = new ArrayList<>(listings);
                cachedAt = android.os.SystemClock.elapsedRealtime();
            }
        }
        return listings;
    }

    /** Drops the burst cache so a pull-to-refresh really does hit the network. */
    public synchronized void invalidateCache() {
        cachedListings = null;
        cachedAt = 0;
    }

    private long elapsedSinceCache() {
        return android.os.SystemClock.elapsedRealtime() - cachedAt;
    }

    /** The web API returns the full set; slice locally to honour offset/limit. */
    public List<Listing> getListings(int offset, int limit) {
        List<Listing> all = getAllListings();
        if (all.isEmpty() || offset >= all.size()) {
            return new ArrayList<>();
        }
        int end = Math.min(all.size(), offset + Math.max(limit, 0));
        return new ArrayList<>(all.subList(Math.max(offset, 0), end));
    }

    public List<Listing> searchListings(String query) {
        if (query == null || query.trim().isEmpty()) {
            return getAllListings();
        }
        String encoded;
        try {
            encoded = URLEncoder.encode(query.trim(), "UTF-8");
        } catch (Exception e) {
            encoded = query.trim().replace(" ", "%20");
        }
        List<Listing> results = parseList(get("listings/search?q=" + encoded));
        // If the search endpoint yields nothing, fall back to filtering the full set
        // locally so a typo in the backend query never looks like "no listings".
        return results.isEmpty() ? filterLocally(getAllListings(), query.trim()) : results;
    }

    public Listing getListingById(String listingId) {
        if (listingId == null || listingId.isEmpty()) {
            return null;
        }
        String body = get("listings/" + listingId);
        if (body == null) {
            return null;
        }
        try {
            JsonElement data = unwrap(body);
            if (data == null) {
                return null;
            }
            if (data.isJsonArray()) {
                Type listType = new TypeToken<List<Listing>>() {}.getType();
                List<Listing> listings = gson.fromJson(data, listType);
                return (listings == null || listings.isEmpty()) ? null : listings.get(0);
            }
            return gson.fromJson(data, Listing.class);
        } catch (Exception e) {
            Log.e(TAG, "Failed to parse listing " + listingId, e);
            return null;
        }
    }

    private List<Listing> filterLocally(List<Listing> listings, String query) {
        List<Listing> matches = new ArrayList<>();
        String needle = query.toLowerCase();
        for (Listing listing : listings) {
            String haystack = (listing.getTitle() + " " + listing.getDescription() + " "
                    + listing.getCity() + " " + listing.getStreet()).toLowerCase();
            if (haystack.contains(needle)) {
                matches.add(listing);
            }
        }
        return matches;
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

    /** Accepts both the {success, data:[...]} envelope and a bare JSON array. */
    private JsonElement unwrap(String body) {
        if (body == null || body.trim().isEmpty()) {
            return null;
        }
        JsonElement root = JsonParser.parseString(body);
        if (root.isJsonObject() && root.getAsJsonObject().has("data")) {
            return root.getAsJsonObject().get("data");
        }
        return root;
    }

    private List<Listing> parseList(String body) {
        if (body == null) {
            return new ArrayList<>();
        }
        try {
            JsonElement data = unwrap(body);
            if (data == null || !data.isJsonArray()) {
                return new ArrayList<>();
            }
            Type listType = new TypeToken<List<Listing>>() {}.getType();
            List<Listing> listings = gson.fromJson(data, listType);
            if (listings == null) {
                return new ArrayList<>();
            }
            List<Listing> valid = new ArrayList<>();
            for (Listing listing : listings) {
                if (listing != null && listing.getId() != null) {
                    valid.add(listing);
                }
            }
            Log.d(TAG, "Parsed " + valid.size() + " listings from web API");
            return valid;
        } catch (Exception e) {
            Log.e(TAG, "Failed to parse listings payload", e);
            return new ArrayList<>();
        }
    }
}
