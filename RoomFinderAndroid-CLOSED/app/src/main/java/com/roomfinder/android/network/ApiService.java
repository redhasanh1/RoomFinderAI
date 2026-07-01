package com.roomfinder.android.network;

import com.roomfinder.android.models.ApiResponse;
import com.roomfinder.android.models.Listing;
import java.util.List;
import java.util.Map;
import retrofit2.Call;
import retrofit2.http.*;

public interface ApiService {
    
    // Listings
    @GET("api/listings")
    Call<ApiResponse<List<Listing>>> getListings();
    
    @GET("api/listings/{id}")
    Call<ApiResponse<Listing>> getListingDetails(@Path("id") String listingId);
    
    @POST("api/listings")
    Call<ApiResponse<Listing>> createListing(@Body Map<String, Object> listing);
    
    @GET("api/listings/search")
    Call<ApiResponse<List<Listing>>> searchListings(
        @Query("q") String query,
        @Query("min_price") Double minPrice,
        @Query("max_price") Double maxPrice,
        @Query("bedrooms") Integer bedrooms,
        @Query("location") String location
    );
    
    // Auth (Optional)
    @POST("api/auth/login")
    Call<ApiResponse<Map<String, Object>>> login(@Body Map<String, Object> credentials);
    
    @POST("api/auth/register")
    Call<ApiResponse<Map<String, Object>>> register(@Body Map<String, Object> userData);
    
    @POST("api/auth/logout")
    Call<ApiResponse<Void>> logout();
    
    // Chat
    @POST("api/chat/send")
    Call<ApiResponse<Map<String, Object>>> sendMessage(@Body Map<String, Object> message);
    
    @GET("api/chat/conversations")
    Call<ApiResponse<List<Map<String, Object>>>> getConversations();
    
    @GET("api/chat/messages/{conversationId}")
    Call<ApiResponse<List<Map<String, Object>>>> getMessages(@Path("conversationId") String conversationId);
}