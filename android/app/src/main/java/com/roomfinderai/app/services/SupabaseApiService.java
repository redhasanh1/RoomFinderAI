package com.roomfinderai.app.services;

import com.roomfinderai.app.models.Listing;
import java.util.List;
import retrofit2.Call;
import retrofit2.http.*;

public interface SupabaseApiService {
    
    // Listings endpoints (using Supabase REST API)
    @GET("listings")
    Call<List<Listing>> getListings(@Header("Authorization") String auth,
                                   @Header("apikey") String apikey);
    
    @GET("listings")
    Call<List<Listing>> getListings(@Header("Authorization") String auth,
                                   @Header("apikey") String apikey,
                                   @Query("title") String titleFilter);
    
    @GET("listings")
    Call<List<Listing>> searchListings(@Header("Authorization") String auth,
                                     @Header("apikey") String apikey,
                                     @Query("title") String searchQuery);
    
    @POST("listings")
    Call<Listing> createListing(@Header("Authorization") String auth,
                               @Header("apikey") String apikey,
                               @Header("Prefer") String prefer,
                               @Body Listing.SupabaseCreateDto listing);
    
    @PATCH("listings")
    Call<Listing> updateListing(@Header("Authorization") String auth,
                               @Header("apikey") String apikey,
                               @Header("Prefer") String prefer,
                               @Query("id") String id,
                               @Body Listing listing);
    
    @DELETE("listings")
    Call<Void> deleteListing(@Header("Authorization") String auth,
                            @Header("apikey") String apikey,
                            @Query("id") String id);
}