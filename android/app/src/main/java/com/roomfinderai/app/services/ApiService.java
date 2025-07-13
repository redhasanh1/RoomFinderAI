package com.roomfinderai.app.services;

import com.roomfinderai.app.models.*;
import java.util.List;
import retrofit2.Call;
import retrofit2.http.*;

public interface ApiService {
    
    // Authentication endpoints
    @POST("api/register")
    Call<ApiResponse<User>> register(@Body AuthRequest request);
    
    @POST("api/login")
    Call<ApiResponse<User>> login(@Body AuthRequest request);
    
    @POST("api/send-verification")
    Call<ApiResponse<String>> sendVerification(@Body AuthRequest request);
    
    @POST("api/verify-email")
    Call<ApiResponse<String>> verifyEmail(@Body AuthRequest request);
    
    @POST("api/send-reset-code")
    Call<ApiResponse<String>> sendResetCode(@Body AuthRequest request);
    
    @POST("api/verify-reset-code")
    Call<ApiResponse<String>> verifyResetCode(@Body AuthRequest request);
    
    @POST("api/reset-password")
    Call<ApiResponse<String>> resetPassword(@Body AuthRequest request);
    
    // Listings endpoints
    @GET("api/listings")
    Call<ApiResponse<List<Listing>>> getListings();
    
    @GET("api/listings")
    Call<ApiResponse<List<Listing>>> getListings(@QueryMap java.util.Map<String, String> filters);
    
    @GET("api/listings/{id}")
    Call<ApiResponse<Listing>> getListing(@Path("id") String id);
    
    @POST("api/listings")
    Call<ApiResponse<Listing>> createListing(@Body Listing listing);
    
    @PUT("api/listings/{id}")
    Call<ApiResponse<Listing>> updateListing(@Path("id") String id, @Body Listing listing);
    
    @DELETE("api/listings/{id}")
    Call<ApiResponse<String>> deleteListing(@Path("id") String id);
    
    // AI/Chat endpoints
    @POST("api/ai-negotiate")
    Call<ApiResponse<ChatMessage>> sendMessage(@Body AIRequest request);
    
    @POST("api/ai-negotiator")
    Call<ApiResponse<ChatMessage>> aiNegotiator(@Body AIRequest request);
    
    @GET("api/chat/{sessionId}")
    Call<ApiResponse<List<ChatMessage>>> getChatHistory(@Path("sessionId") String sessionId);
    
    @POST("api/save-chat-data")
    Call<ApiResponse<String>> saveChatData(@Body ChatMessage message);
    
    // Configuration endpoint
    @GET("api/config")
    Call<ApiResponse<java.util.Map<String, String>>> getConfig();
    
    // User profile endpoints
    @GET("api/profile/{userId}")
    Call<ApiResponse<User>> getUserProfile(@Path("userId") String userId);
    
    @PUT("api/profile/{userId}")
    Call<ApiResponse<User>> updateUserProfile(@Path("userId") String userId, @Body User user);
    
    // Payment endpoints
    @POST("api/create-payment-intent")
    Call<ApiResponse<String>> createPaymentIntent(@Body java.util.Map<String, Object> request);
}