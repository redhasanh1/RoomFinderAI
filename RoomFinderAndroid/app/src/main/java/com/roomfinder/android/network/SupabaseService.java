package com.roomfinder.android.network;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.roomfinder.android.database.SupabaseClient;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.services.AiNegotiatorService.PropertyCriteria;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SupabaseService {
    private static final String TAG = "SupabaseService";
    private static final String CACHE_PREFS = "listings_cache";
    private static final String CACHE_KEY_LISTINGS = "cached_listings";
    private static final String CACHE_KEY_TIMESTAMP = "cache_timestamp";
    private static final long CACHE_EXPIRY_MS = 5 * 60 * 1000; // 5 minutes
    
    private static SupabaseService instance;
    private final SupabaseClient supabaseClient;
    private final ExecutorService executorService;
    private final Gson gson;
    private Context context;
    
    private SupabaseService() {
        this.supabaseClient = SupabaseClient.getInstance();
        this.executorService = Executors.newCachedThreadPool();
        this.gson = new Gson();
    }
    
    public static synchronized SupabaseService getInstance() {
        if (instance == null) {
            instance = new SupabaseService();
        }
        return instance;
    }
    
    /**
     * Initialize with context for caching
     */
    public void init(Context context) {
        this.context = context.getApplicationContext();
    }
    
    // Callback interfaces
    public interface ListingsCallback {
        void onSuccess(List<Listing> listings);
        void onError(String error);
    }
    
    public interface ListingCallback {
        void onSuccess(Listing listing);
        void onError(String error);
    }
    
    /**
     * Cache helper methods
     */
    private SharedPreferences getCachePrefs() {
        if (context == null) return null;
        return context.getSharedPreferences(CACHE_PREFS, Context.MODE_PRIVATE);
    }
    
    private void cacheListings(List<Listing> listings) {
        SharedPreferences prefs = getCachePrefs();
        if (prefs != null) {
            String json = gson.toJson(listings);
            long timestamp = System.currentTimeMillis();
            prefs.edit()
                    .putString(CACHE_KEY_LISTINGS, json)
                    .putLong(CACHE_KEY_TIMESTAMP, timestamp)
                    .apply();
            Log.d(TAG, "💾 Cached " + listings.size() + " listings");
        }
    }
    
    private List<Listing> getCachedListings() {
        SharedPreferences prefs = getCachePrefs();
        if (prefs == null) return null;
        
        long timestamp = prefs.getLong(CACHE_KEY_TIMESTAMP, 0);
        long age = System.currentTimeMillis() - timestamp;
        
        if (age > CACHE_EXPIRY_MS) {
            Log.d(TAG, "🕒 Cache expired (age: " + (age / 1000) + "s)");
            return null;
        }
        
        String json = prefs.getString(CACHE_KEY_LISTINGS, null);
        if (json != null) {
            try {
                Type listType = new TypeToken<List<Listing>>(){}.getType();
                List<Listing> listings = gson.fromJson(json, listType);
                Log.d(TAG, "⚡ Loaded " + (listings != null ? listings.size() : 0) + " listings from cache");
                return listings;
            } catch (Exception e) {
                Log.e(TAG, "❌ Error parsing cached listings: " + e.getMessage());
            }
        }
        return null;
    }
    
    /**
     * Fetch all listings asynchronously with caching
     */
    public void getAllListings(ListingsCallback callback) {
        // First, try to load from cache immediately
        List<Listing> cachedListings = getCachedListings();
        if (cachedListings != null && !cachedListings.isEmpty()) {
            Log.d(TAG, "⚡ Returning cached listings immediately");
            callback.onSuccess(cachedListings);
            
            // Continue to refresh in background
            refreshListingsInBackground();
            return;
        }
        
        // No cache available, fetch from network
        Log.d(TAG, "🌐 No cache available, fetching from network...");
        fetchListingsFromNetwork(callback);
    }
    
    /**
     * Force refresh listings (bypasses cache)
     */
    public void refreshListings(ListingsCallback callback) {
        Log.d(TAG, "🔄 Force refreshing listings...");
        fetchListingsFromNetwork(callback);
    }
    
    private void fetchListingsFromNetwork(ListingsCallback callback) {
        executorService.execute(() -> {
            try {
                Log.d(TAG, "Fetching all listings from Supabase...");
                List<Listing> listings = supabaseClient.getAllListings();
                
                // Cache the results
                if (listings != null && !listings.isEmpty()) {
                    cacheListings(listings);
                }
                
                // Post result back to main thread
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> {
                    if (listings != null) {
                        Log.d(TAG, "Successfully fetched " + listings.size() + " listings");
                        callback.onSuccess(listings);
                    } else {
                        Log.e(TAG, "Received null listings from Supabase");
                        callback.onError("Failed to fetch listings");
                    }
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Error fetching listings: " + e.getMessage(), e);
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> callback.onError("Network error: " + e.getMessage()));
            }
        });
    }
    
    private void refreshListingsInBackground() {
        executorService.execute(() -> {
            try {
                Log.d(TAG, "🔄 Background refresh starting...");
                List<Listing> listings = supabaseClient.getAllListings();
                if (listings != null && !listings.isEmpty()) {
                    cacheListings(listings);
                    Log.d(TAG, "🔄 Background refresh completed");
                }
            } catch (Exception e) {
                Log.e(TAG, "Background refresh failed: " + e.getMessage());
            }
        });
    }
    
    /**
     * Search listings asynchronously
     */
    public void searchListings(String query, ListingsCallback callback) {
        executorService.execute(() -> {
            try {
                Log.d(TAG, "Searching listings with query: " + query);
                List<Listing> listings = supabaseClient.searchListings(query);
                
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> {
                    if (listings != null) {
                        Log.d(TAG, "Search returned " + listings.size() + " results");
                        callback.onSuccess(listings);
                    } else {
                        callback.onError("Search failed");
                    }
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Error searching listings: " + e.getMessage(), e);
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> callback.onError("Search error: " + e.getMessage()));
            }
        });
    }
    
    /**
     * Filter listings asynchronously
     */
    public void filterListings(Integer minPrice, Integer maxPrice, Integer bedrooms, 
                             String propertyType, String location, ListingsCallback callback) {
        executorService.execute(() -> {
            try {
                Log.d(TAG, "Filtering listings with criteria - Price: " + minPrice + "-" + maxPrice + 
                          ", Bedrooms: " + bedrooms + ", Type: " + propertyType + ", Location: " + location);
                          
                List<Listing> listings = supabaseClient.filterListings(minPrice, maxPrice, bedrooms, propertyType, location);
                
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> {
                    if (listings != null) {
                        Log.d(TAG, "Filter returned " + listings.size() + " results");
                        callback.onSuccess(listings);
                    } else {
                        callback.onError("Filter failed");
                    }
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Error filtering listings: " + e.getMessage(), e);
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> callback.onError("Filter error: " + e.getMessage()));
            }
        });
    }
    
    /**
     * Search listings with enhanced criteria from AI extraction
     */
    public void searchWithCriteria(PropertyCriteria criteria, ListingsCallback callback) {
        if (criteria == null || !criteria.hasValidCriteria()) {
            Log.w(TAG, "❌ No valid search criteria provided");
            callback.onError("No valid search criteria provided");
            return;
        }
        
        executorService.execute(() -> {
            try {
                Log.d(TAG, "🔍 Searching with AI-extracted criteria:");
                Log.d(TAG, "  📍 Location: " + (criteria.location != null ? criteria.location : "Any"));
                Log.d(TAG, "  🏠 Property Type: " + (criteria.propertyType != null ? criteria.propertyType : "Any"));
                Log.d(TAG, "  💰 Price Range: $" + criteria.minPrice + " - $" + criteria.maxPrice);
                Log.d(TAG, "  🛏️ Bedrooms: " + (criteria.bedrooms != null ? criteria.bedrooms : "Any"));
                Log.d(TAG, "  🚿 Bathrooms: " + (criteria.bathrooms != null ? criteria.bathrooms : "Any"));
                
                // Validate criteria before sending to database
                if (!isValidCriteria(criteria)) {
                    android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                    mainHandler.post(() -> callback.onError("Invalid search criteria values"));
                    return;
                }
                
                // Use the enhanced filter method that includes bathrooms
                List<Listing> listings = supabaseClient.filterListingsEnhanced(
                    criteria.minPrice, 
                    criteria.maxPrice, 
                    criteria.bedrooms, 
                    criteria.bathrooms,
                    criteria.propertyType, 
                    criteria.location
                );
                
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> {
                    if (listings != null) {
                        Log.d(TAG, "✅ AI criteria search returned " + listings.size() + " filtered results");
                        
                        // Additional validation - ensure we're not returning ALL listings unexpectedly
                        if (listings.size() > 50) {
                            Log.w(TAG, "⚠️ Suspiciously large result set (" + listings.size() + " properties). This might indicate filter failure.");
                        }
                        
                        callback.onSuccess(listings);
                    } else {
                        Log.e(TAG, "❌ Search with criteria returned null");
                        callback.onError("Search with criteria failed");
                    }
                });
                
            } catch (Exception e) {
                Log.e(TAG, "❌ Error searching with criteria: " + e.getMessage(), e);
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> callback.onError("Search error: " + e.getMessage()));
            }
        });
    }
    
    /**
     * Validate search criteria to prevent invalid database queries
     */
    private boolean isValidCriteria(PropertyCriteria criteria) {
        // Validate price ranges
        if (criteria.minPrice != null && criteria.minPrice < 0) {
            Log.w(TAG, "❌ Invalid min price: " + criteria.minPrice);
            return false;
        }
        if (criteria.maxPrice != null && criteria.maxPrice < 0) {
            Log.w(TAG, "❌ Invalid max price: " + criteria.maxPrice);
            return false;
        }
        if (criteria.minPrice != null && criteria.maxPrice != null && criteria.minPrice > criteria.maxPrice) {
            Log.w(TAG, "❌ Min price (" + criteria.minPrice + ") greater than max price (" + criteria.maxPrice + ")");
            return false;
        }
        
        // Validate bedroom/bathroom counts
        if (criteria.bedrooms != null && (criteria.bedrooms < 0 || criteria.bedrooms > 10)) {
            Log.w(TAG, "❌ Invalid bedrooms count: " + criteria.bedrooms);
            return false;
        }
        if (criteria.bathrooms != null && (criteria.bathrooms < 0 || criteria.bathrooms > 10)) {
            Log.w(TAG, "❌ Invalid bathrooms count: " + criteria.bathrooms);
            return false;
        }
        
        // Validate location string
        if (criteria.location != null && criteria.location.trim().length() > 100) {
            Log.w(TAG, "❌ Location string too long: " + criteria.location.length() + " chars");
            return false;
        }
        
        Log.d(TAG, "✅ Criteria validation passed");
        return true;
    }
    
    /**
     * Get single listing by ID asynchronously
     */
    public void getListingById(String listingId, ListingCallback callback) {
        executorService.execute(() -> {
            try {
                Log.d(TAG, "Fetching listing by ID: " + listingId);
                Listing listing = supabaseClient.getListingById(listingId);
                
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> {
                    if (listing != null) {
                        Log.d(TAG, "Successfully fetched listing: " + listing.getTitle());
                        callback.onSuccess(listing);
                    } else {
                        Log.w(TAG, "No listing found with ID: " + listingId);
                        callback.onError("Listing not found");
                    }
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Error fetching listing by ID: " + e.getMessage(), e);
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> callback.onError("Error fetching listing: " + e.getMessage()));
            }
        });
    }
    
    /**
     * Shutdown the executor service (call this when the app is closing)
     */
    public void shutdown() {
        if (executorService != null && !executorService.isShutdown()) {
            executorService.shutdown();
        }
    }
}