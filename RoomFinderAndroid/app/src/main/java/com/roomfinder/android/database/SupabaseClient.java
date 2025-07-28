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
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
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
     * Fetch all listings from Supabase database
     * Equivalent to: supabase.from('listings').select('*').order('created_at', { ascending: false })
     */
    public List<Listing> getAllListings() {
        try {
            String url = baseUrl + "listings?select=*&order=created_at.desc";
            
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
                List<Listing> listings = gson.fromJson(responseBody, listType);
                
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
    public List<Listing> filterListings(Integer minPrice, Integer maxPrice, Integer bedrooms, String propertyType) {
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