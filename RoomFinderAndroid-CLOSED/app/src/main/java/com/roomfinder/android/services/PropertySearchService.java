package com.roomfinder.android.services;

import android.util.Log;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.utils.NetworkUtils;
import com.roomfinder.android.services.AiNegotiatorService.PropertyCriteria;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.List;
import java.net.URLEncoder;
import java.io.UnsupportedEncodingException;

public class PropertySearchService {
    private static final String TAG = "PropertySearchService";
    
    public interface PropertySearchCallback {
        void onSuccess(List<Listing> listings);
        void onError(String error);
    }
    
    // Search properties based on AI-extracted criteria
    public static void searchProperties(PropertyCriteria criteria, PropertySearchCallback callback) {
        if (criteria == null || !criteria.hasValidCriteria()) {
            callback.onError("Please provide search criteria (location, price, property type, etc.)");
            return;
        }
        
        try {
            String query = buildSupabaseQuery(criteria);
            Log.d(TAG, "Searching properties with query: " + query);
            
            NetworkUtils.makeSupabaseRequest(query, "GET", null, new NetworkUtils.NetworkCallback<String>() {
                @Override
                public void onSuccess(String response) {
                    try {
                        List<Listing> listings = parseListingsFromResponse(response);
                        Log.d(TAG, "Found " + listings.size() + " matching properties");
                        callback.onSuccess(listings);
                    } catch (JSONException e) {
                        Log.e(TAG, "Error parsing listings response", e);
                        callback.onError("Error parsing search results");
                    }
                }
                
                @Override
                public void onError(String error) {
                    Log.e(TAG, "Property search failed: " + error);
                    callback.onError("Failed to search properties: " + error);
                }
            });
            
        } catch (Exception e) {
            Log.e(TAG, "Error building search query", e);
            callback.onError("Error building search query");
        }
    }
    
    // Build Supabase query string based on criteria
    private static String buildSupabaseQuery(PropertyCriteria criteria) throws UnsupportedEncodingException {
        StringBuilder query = new StringBuilder("listings?select=*");
        List<String> filters = new ArrayList<>();
        
        // Location filter - search in city, street, and title
        if (criteria.location != null && !criteria.location.trim().isEmpty()) {
            String location = criteria.location.toLowerCase().trim();
            String locationFilter = String.format(
                "or=(city.ilike.%%%s%%,street.ilike.%%%s%%,title.ilike.%%%s%%)",
                URLEncoder.encode(location, "UTF-8"),
                URLEncoder.encode(location, "UTF-8"),
                URLEncoder.encode(location, "UTF-8")
            );
            filters.add(locationFilter);
        }
        
        // Price filters
        if (criteria.maxPrice != null) {
            filters.add("price.lte." + criteria.maxPrice);
        }
        if (criteria.minPrice != null) {
            filters.add("price.gte." + criteria.minPrice);
        }
        
        // Property type filter
        if (criteria.propertyType != null && !criteria.propertyType.trim().isEmpty()) {
            String propertyType = criteria.propertyType.toLowerCase().trim();
            filters.add("house_type.ilike.%" + URLEncoder.encode(propertyType, "UTF-8") + "%");
        }
        
        // Bedroom filter
        if (criteria.bedrooms != null) {
            filters.add("bedrooms.eq." + criteria.bedrooms);
        }
        
        // Bathroom filter
        if (criteria.bathrooms != null) {
            filters.add("bathrooms.eq." + criteria.bathrooms);
        }
        
        // Add filters to query
        if (!filters.isEmpty()) {
            query.append("&");
            query.append(String.join("&", filters));
        }
        
        // Order by updated_at descending and limit results
        query.append("&order=updated_at.desc&limit=20");
        
        return query.toString();
    }
    
    // Parse JSON response into Listing objects
    private static List<Listing> parseListingsFromResponse(String response) throws JSONException {
        List<Listing> listings = new ArrayList<>();
        JSONArray jsonArray = new JSONArray(response);
        
        for (int i = 0; i < jsonArray.length(); i++) {
            JSONObject listingJson = jsonArray.getJSONObject(i);
            Listing listing = parseListingFromJson(listingJson);
            if (listing != null) {
                listings.add(listing);
            }
        }
        
        return listings;
    }
    
    // Parse individual listing from JSON
    private static Listing parseListingFromJson(JSONObject json) {
        try {
            Listing listing = new Listing();
            
            // Required fields
            listing.setId(String.valueOf(json.optInt("id", 0)));
            listing.setTitle(json.optString("title", ""));
            listing.setPrice(json.optDouble("price", 0.0));
            
            // Location fields
            listing.setCity(json.optString("city", ""));
            listing.setStreet(json.optString("street", ""));
            
            // Property details
            listing.setBedrooms(json.optInt("bedrooms", 0));
            listing.setBathrooms(json.optInt("bathrooms", 0));
            listing.setHouseType(json.optString("house_type", ""));
            listing.setDescription(json.optString("description", ""));
            
            // Contact info
            listing.setUserEmail(json.optString("user_email", ""));
            
            // Handle media/images - convert to MediaFile objects
            String imagesStr = json.optString("images", "");
            if (!imagesStr.isEmpty()) {
                try {
                    List<Listing.MediaFile> mediaFiles = new ArrayList<>();
                    JSONArray imagesArray = new JSONArray(imagesStr);
                    for (int i = 0; i < imagesArray.length(); i++) {
                        String imageUrl = imagesArray.getString(i);
                        Listing.MediaFile media = new Listing.MediaFile(imageUrl, "image/jpeg", "image_" + i);
                        mediaFiles.add(media);
                    }
                    listing.setMedia(mediaFiles);
                } catch (JSONException e) {
                    // If images is not a JSON array, treat as single image URL
                    List<Listing.MediaFile> mediaFiles = new ArrayList<>();
                    Listing.MediaFile media = new Listing.MediaFile(imagesStr, "image/jpeg", "image_0");
                    mediaFiles.add(media);
                    listing.setMedia(mediaFiles);
                }
            }
            
            // Timestamps
            listing.setCreatedAt(json.optString("created_at", ""));
            
            return listing;
            
        } catch (Exception e) {
            Log.e(TAG, "Error parsing listing JSON", e);
            return null;
        }
    }
    
    // Get all properties (for debugging/testing)
    public static void getAllProperties(PropertySearchCallback callback) {
        String query = "listings?select=*&order=updated_at.desc&limit=50";
        
        NetworkUtils.makeSupabaseRequest(query, "GET", null, new NetworkUtils.NetworkCallback<String>() {
            @Override
            public void onSuccess(String response) {
                try {
                    List<Listing> listings = parseListingsFromResponse(response);
                    Log.d(TAG, "Retrieved " + listings.size() + " total properties");
                    callback.onSuccess(listings);
                } catch (JSONException e) {
                    Log.e(TAG, "Error parsing all properties response", e);
                    callback.onError("Error parsing properties");
                }
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Failed to get all properties: " + error);
                callback.onError("Failed to retrieve properties: " + error);
            }
        });
    }
    
    // Search properties by text query (fallback method)
    public static void searchPropertiesByText(String searchText, PropertySearchCallback callback) {
        if (searchText == null || searchText.trim().isEmpty()) {
            callback.onError("Please enter search criteria");
            return;
        }
        
        try {
            String encodedText = URLEncoder.encode(searchText.toLowerCase(), "UTF-8");
            String query = String.format(
                "listings?select=*&or=(title.ilike.%%%s%%,city.ilike.%%%s%%,street.ilike.%%%s%%)&order=updated_at.desc&limit=20",
                encodedText, encodedText, encodedText
            );
            
            Log.d(TAG, "Text search query: " + query);
            
            NetworkUtils.makeSupabaseRequest(query, "GET", null, new NetworkUtils.NetworkCallback<String>() {
                @Override
                public void onSuccess(String response) {
                    try {
                        List<Listing> listings = parseListingsFromResponse(response);
                        Log.d(TAG, "Text search found " + listings.size() + " properties");
                        callback.onSuccess(listings);
                    } catch (JSONException e) {
                        Log.e(TAG, "Error parsing text search response", e);
                        callback.onError("Error parsing search results");
                    }
                }
                
                @Override
                public void onError(String error) {
                    Log.e(TAG, "Text search failed: " + error);
                    callback.onError("Search failed: " + error);
                }
            });
            
        } catch (UnsupportedEncodingException e) {
            Log.e(TAG, "Error encoding search text", e);
            callback.onError("Error processing search text");
        }
    }
}