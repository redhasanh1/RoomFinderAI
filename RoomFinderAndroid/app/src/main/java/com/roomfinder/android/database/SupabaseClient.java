package com.roomfinder.android.database;

import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.utils.ApiKeys;

import java.io.IOException;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

public class SupabaseClient {
    private static final String TAG = "SupabaseClient";
    private static SupabaseClient instance;
    private final OkHttpClient httpClient;
    private final Gson gson;
    private final String baseUrl;
    
    private SupabaseClient() {
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(10, TimeUnit.SECONDS) // Faster timeout
                .readTimeout(15, TimeUnit.SECONDS)    // Faster timeout
                .writeTimeout(15, TimeUnit.SECONDS)   // Faster timeout
                .build();
        this.gson = new Gson();
        this.baseUrl = ApiKeys.SUPABASE_URL + "rest/v1/";
    }
    
    public static synchronized SupabaseClient getInstance() {
        if (instance == null) {
            instance = new SupabaseClient();
        }
        return instance;
    }
    
    /**
     * Fetch all listings from Supabase database with pagination
     * Equivalent to: supabase.from('listings').select('*').order('created_at', { ascending: false }).limit(50)
     */
    public List<Listing> getAllListings() {
        try {
            // Limit to first 50 listings for faster initial load
            String url = baseUrl + "listings?select=*&order=created_at.desc&limit=50";
            
            Request request = new Request.Builder()
                    .url(url)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .addHeader("Prefer", "return=representation")
                    .build();
            
            Log.d(TAG, "Fetching listings from: " + url);
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    Log.e(TAG, "HTTP error: " + response.code() + " - " + response.message());
                    if (response.body() != null) {
                        Log.e(TAG, "Error body: " + response.body().string());
                    }
                    return new ArrayList<>();
                }
                
                String responseBody = response.body().string();
                Log.d(TAG, "Response body: " + responseBody);
                
                Type listType = new TypeToken<List<Listing>>(){}.getType();
                List<Listing> listings;
                
                try {
                    // Add debug logging for JSON parsing
                    Log.d(TAG, "📊 JSON Response sample: " + (responseBody.length() > 200 ? responseBody.substring(0, 200) + "..." : responseBody));
                    listings = gson.fromJson(responseBody, listType);
                    Log.d(TAG, "✅ JSON parsing successful, parsed " + (listings != null ? listings.size() : 0) + " listings");
                } catch (com.google.gson.JsonSyntaxException e) {
                    Log.e(TAG, "❌ JSON syntax error - likely data type mismatch: " + e.getMessage(), e);
                    Log.e(TAG, "📄 Problematic JSON: " + responseBody);
                    return new ArrayList<>();
                } catch (Exception e) {
                    Log.e(TAG, "❌ JSON parsing error: " + e.getMessage(), e);
                    Log.e(TAG, "📄 Problematic JSON: " + responseBody);
                    return new ArrayList<>();
                }
                
                if (listings == null) {
                    listings = new ArrayList<>();
                }
                
                Log.d(TAG, "Successfully fetched " + listings.size() + " listings");
                return listings;
            }
            
        } catch (IOException e) {
            Log.e(TAG, "Network error fetching listings: " + e.getMessage(), e);
            return new ArrayList<>();
        } catch (Exception e) {
            Log.e(TAG, "Error parsing listings: " + e.getMessage(), e);
            return new ArrayList<>();
        }
    }
    
    /**
     * Search listings by query string
     * Equivalent to filtering listings by title, description, or location
     */
    public List<Listing> searchListings(String query) {
        try {
            // Use ilike for case-insensitive pattern matching
            String encodedQuery = java.net.URLEncoder.encode("%" + query + "%", "UTF-8");
            String url = baseUrl + "listings?select=*&or=(title.ilike." + encodedQuery + 
                        ",description.ilike." + encodedQuery + 
                        ",city.ilike." + encodedQuery + 
                        ",street.ilike." + encodedQuery + ")&order=created_at.desc";
            
            Request request = new Request.Builder()
                    .url(url)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .build();
            
            Log.d(TAG, "Searching listings with query: " + query);
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    Log.e(TAG, "Search error: " + response.code() + " - " + response.message());
                    return new ArrayList<>();
                }
                
                String responseBody = response.body().string();
                Type listType = new TypeToken<List<Listing>>(){}.getType();
                List<Listing> listings = gson.fromJson(responseBody, listType);
                
                if (listings == null) {
                    listings = new ArrayList<>();
                }
                
                Log.d(TAG, "Search returned " + listings.size() + " listings");
                return listings;
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error searching listings: " + e.getMessage(), e);
            return new ArrayList<>();
        }
    }
    
    /**
     * Filter listings by criteria
     */
    public List<Listing> filterListings(Integer minPrice, Integer maxPrice, Integer bedrooms, String propertyType, String location) {
        try {
            StringBuilder urlBuilder = new StringBuilder(baseUrl + "listings?select=*");
            
            // Add filters
            List<String> filters = new ArrayList<>();
            
            if (minPrice != null) {
                filters.add("price.gte." + minPrice);
            }
            if (maxPrice != null) {
                filters.add("price.lte." + maxPrice);
            }
            if (bedrooms != null) {
                filters.add("bedrooms.eq." + bedrooms);
            }
            if (propertyType != null && !propertyType.isEmpty()) {
                filters.add("house_type.ilike." + java.net.URLEncoder.encode("%" + propertyType + "%", "UTF-8"));
            }
            if (location != null && !location.trim().isEmpty()) {
                String encodedLocation = java.net.URLEncoder.encode("%" + location.toLowerCase() + "%", "UTF-8");
                filters.add("or=(city.ilike." + encodedLocation + ",street.ilike." + encodedLocation + ")");
            }
            
            if (!filters.isEmpty()) {
                urlBuilder.append("&").append(String.join("&", filters));
            }
            
            urlBuilder.append("&order=created_at.desc");
            
            Request request = new Request.Builder()
                    .url(urlBuilder.toString())
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .build();
            
            Log.d(TAG, "Filtering listings with URL: " + urlBuilder.toString());
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    Log.e(TAG, "Filter error: " + response.code() + " - " + response.message());
                    return new ArrayList<>();
                }
                
                String responseBody = response.body().string();
                Type listType = new TypeToken<List<Listing>>(){}.getType();
                List<Listing> listings = gson.fromJson(responseBody, listType);
                
                if (listings == null) {
                    listings = new ArrayList<>();
                }
                
                Log.d(TAG, "Filter returned " + listings.size() + " listings");
                return listings;
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error filtering listings: " + e.getMessage(), e);
            return new ArrayList<>();
        }
    }
    
    /**
     * Enhanced filter listings by criteria including bathrooms
     */
    public List<Listing> filterListingsEnhanced(Integer minPrice, Integer maxPrice, Integer bedrooms, 
                                               Integer bathrooms, String propertyType, String location) {
        try {
            StringBuilder urlBuilder = new StringBuilder(baseUrl + "listings?select=*");
            
            // Build separate filter groups for proper query construction
            List<String> standardFilters = new ArrayList<>();
            String locationFilter = null;
            
            // Add standard equality and comparison filters
            if (minPrice != null) {
                standardFilters.add("price.gte." + minPrice);
            }
            if (maxPrice != null) {
                standardFilters.add("price.lte." + maxPrice);
            }
            if (bedrooms != null) {
                standardFilters.add("bedrooms.eq." + bedrooms);
            }
            if (bathrooms != null) {
                standardFilters.add("bathrooms.eq." + bathrooms);
            }
            if (propertyType != null && !propertyType.isEmpty()) {
                standardFilters.add("house_type.ilike." + java.net.URLEncoder.encode("%" + propertyType + "%", "UTF-8"));
            }
            
            // Handle location filter separately to avoid query syntax conflicts
            if (location != null && !location.trim().isEmpty()) {
                String encodedLocation = java.net.URLEncoder.encode("%" + location.toLowerCase() + "%", "UTF-8");
                locationFilter = "or=(city.ilike." + encodedLocation + ",street.ilike." + encodedLocation + ")";
            }
            
            // DEBUG: Log what filters we have before constructing query
            Log.d(TAG, "📋 Filter Debug:");
            Log.d(TAG, "  - Standard filters count: " + standardFilters.size());
            for (String filter : standardFilters) {
                Log.d(TAG, "    • " + filter);
            }
            Log.d(TAG, "  - Location filter: " + (locationFilter != null ? locationFilter : "none"));
            
            // Construct query based on what filters we have
            // IMPORTANT: Supabase PostgREST doesn't use "and=()" syntax, just combine filters with &
            if (!standardFilters.isEmpty() || locationFilter != null) {
                // Add all standard filters first
                if (!standardFilters.isEmpty()) {
                    urlBuilder.append("&").append(String.join("&", standardFilters));
                    Log.d(TAG, "🔍 Added standard filters");
                }
                
                // Add location filter if present
                if (locationFilter != null) {
                    urlBuilder.append("&").append(locationFilter);
                    Log.d(TAG, "🔍 Added location filter");
                }
            } else {
                Log.w(TAG, "⚠️ No valid filters provided - this will return ALL listings!");
                // Return empty list instead of all listings when no criteria provided
                Log.d(TAG, "Returning empty list instead of all listings due to no valid criteria");
                return new ArrayList<>();
            }
            
            urlBuilder.append("&order=created_at.desc");
            
            String finalUrl = urlBuilder.toString();
            Log.d(TAG, "🌐 Enhanced filtering listings with URL: " + finalUrl);
            
            // Validate URL construction
            if (finalUrl.contains("&and=") && finalUrl.contains("&or=")) {
                Log.e(TAG, "❌ Invalid query: mixing AND and OR at top level");
                return new ArrayList<>();
            }
            
            Request request = new Request.Builder()
                    .url(finalUrl)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .build();
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    String errorBody = response.body() != null ? response.body().string() : "Unknown error";
                    Log.e(TAG, "❌ Enhanced filter error: " + response.code() + " - " + response.message());
                    Log.e(TAG, "❌ Error response: " + errorBody);
                    Log.e(TAG, "❌ Failed URL: " + finalUrl);
                    return new ArrayList<>();
                }
                
                String responseBody = response.body().string();
                Log.d(TAG, "✅ Filter response received, length: " + responseBody.length());
                
                Type listType = new TypeToken<List<Listing>>(){}.getType();
                List<Listing> listings = gson.fromJson(responseBody, listType);
                
                if (listings == null) {
                    listings = new ArrayList<>();
                }
                
                Log.d(TAG, "✅ Enhanced filter returned " + listings.size() + " listings (filtered results)");
                
                // Additional validation - log first few results for debugging
                if (!listings.isEmpty()) {
                    Log.d(TAG, "📋 Sample results:");
                    for (int i = 0; i < Math.min(3, listings.size()); i++) {
                        Listing listing = listings.get(i);
                        Log.d(TAG, "  " + (i + 1) + ". " + listing.getTitle() + " - $" + listing.getPrice() + " - " + listing.getLocation());
                    }
                }
                
                return listings;
            }
            
        } catch (Exception e) {
            Log.e(TAG, "❌ Error in enhanced filtering listings: " + e.getMessage(), e);
            return new ArrayList<>();
        }
    }
    
    /**
     * Get single listing by ID
     */
    public Listing getListingById(String listingId) {
        try {
            String url = baseUrl + "listings?select=*&id=eq." + listingId + "&limit=1";
            
            Request request = new Request.Builder()
                    .url(url)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .build();
            
            Log.d(TAG, "Fetching listing by ID: " + listingId);
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    Log.e(TAG, "Error fetching listing: " + response.code() + " - " + response.message());
                    return null;
                }
                
                String responseBody = response.body().string();
                Type listType = new TypeToken<List<Listing>>(){}.getType();
                List<Listing> listings = gson.fromJson(responseBody, listType);
                
                if (listings != null && !listings.isEmpty()) {
                    Log.d(TAG, "Successfully fetched listing: " + listings.get(0).getTitle());
                    return listings.get(0);
                }
                
                Log.d(TAG, "No listing found with ID: " + listingId);
                return null;
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error fetching listing by ID: " + e.getMessage(), e);
            return null;
        }
    }
}