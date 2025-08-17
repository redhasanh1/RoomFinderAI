package com.roomfinder.android.network;

import android.os.AsyncTask;
import android.util.Log;

import com.roomfinder.android.database.SupabaseClient;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.services.AiNegotiatorService.PropertyCriteria;

import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SupabaseService {
    private static final String TAG = "SupabaseService";
    private static SupabaseService instance;
    private final SupabaseClient supabaseClient;
    private final ExecutorService executorService;
    
    private SupabaseService() {
        this.supabaseClient = SupabaseClient.getInstance();
        this.executorService = Executors.newCachedThreadPool();
    }
    
    public static synchronized SupabaseService getInstance() {
        if (instance == null) {
            instance = new SupabaseService();
        }
        return instance;
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
     * Fetch all listings asynchronously
     */
    public void getAllListings(ListingsCallback callback) {
        executorService.execute(() -> {
            try {
                Log.d(TAG, "Fetching all listings from Supabase...");
                List<Listing> listings = supabaseClient.getAllListings();
                
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
            callback.onError("No valid search criteria provided");
            return;
        }
        
        executorService.execute(() -> {
            try {
                Log.d(TAG, "Searching with AI-extracted criteria:");
                Log.d(TAG, "  Location: " + criteria.location);
                Log.d(TAG, "  Property Type: " + criteria.propertyType);
                Log.d(TAG, "  Price Range: $" + criteria.minPrice + " - $" + criteria.maxPrice);
                Log.d(TAG, "  Bedrooms: " + criteria.bedrooms);
                Log.d(TAG, "  Bathrooms: " + criteria.bathrooms);
                
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
                        Log.d(TAG, "AI criteria search returned " + listings.size() + " results");
                        callback.onSuccess(listings);
                    } else {
                        callback.onError("Search with criteria failed");
                    }
                });
                
            } catch (Exception e) {
                Log.e(TAG, "Error searching with criteria: " + e.getMessage(), e);
                android.os.Handler mainHandler = new android.os.Handler(android.os.Looper.getMainLooper());
                mainHandler.post(() -> callback.onError("Search error: " + e.getMessage()));
            }
        });
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