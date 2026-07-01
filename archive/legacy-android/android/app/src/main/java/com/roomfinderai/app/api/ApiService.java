package com.roomfinderai.app.api;

import com.google.gson.JsonObject;
import com.roomfinderai.app.models.ApiResponse;
import com.roomfinderai.app.models.ChatRequest;
import com.roomfinderai.app.models.ChatResponse;
import com.roomfinderai.app.models.Listing;
import com.roomfinderai.app.models.PredictRequest;
import com.roomfinderai.app.models.PredictResponse;
import com.roomfinderai.app.models.SearchRequest;
import retrofit2.Call;
import retrofit2.http.Body;
import retrofit2.http.GET;
import retrofit2.http.POST;

public interface ApiService {
    
    @POST("api/predict")
    Call<PredictResponse> predictMarketplaceUrl(@Body PredictRequest request);
    
    @POST("api/chat")
    Call<ChatResponse> sendChatMessage(@Body ChatRequest request);
    
    @GET("api/listings")
    Call<ApiResponse<java.util.List<Listing>>> getListings();
    
    @POST("api/listings/search")
    Call<ApiResponse<java.util.List<Listing>>> searchListings(@Body SearchRequest request);
    
    @POST("api/auth/login")
    Call<JsonObject> login(@Body JsonObject loginRequest);
    
    @POST("api/auth/google-signin")
    Call<JsonObject> googleSignIn(@Body JsonObject googleSignInRequest);
    
    @POST("api/register")
    Call<JsonObject> signUp(@Body JsonObject signUpRequest);
    
    @POST("api/auth/verify-code")
    Call<JsonObject> verifyCode(@Body JsonObject verifyRequest);
}