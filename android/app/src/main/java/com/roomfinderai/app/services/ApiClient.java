package com.roomfinderai.app.services;

import com.roomfinderai.app.config.ApiConfig;
import okhttp3.OkHttpClient;
import okhttp3.logging.HttpLoggingInterceptor;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;
import java.util.concurrent.TimeUnit;

public class ApiClient {
    // NO RAILWAY - Direct APIs only
    
    // Direct API retrofit instances
    private static Retrofit supabaseRetrofit = null;
    private static Retrofit openaiRetrofit = null;
    
    // Direct API service instances
    private static SupabaseApiService supabaseApiService = null;
    private static OpenAIApiService openaiApiService = null;
    
    // Create HTTP client with logging
    private static OkHttpClient createHttpClient() {
        HttpLoggingInterceptor loggingInterceptor = new HttpLoggingInterceptor();
        loggingInterceptor.setLevel(HttpLoggingInterceptor.Level.BODY);
        
        return new OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .addInterceptor(loggingInterceptor)
                .build();
    }
    
    // Get Supabase client
    public static Retrofit getSupabaseClient() {
        if (supabaseRetrofit == null) {
            supabaseRetrofit = new Retrofit.Builder()
                    .baseUrl(ApiConfig.getSupabaseRestUrl() + "/")
                    .addConverterFactory(GsonConverterFactory.create())
                    .client(createHttpClient())
                    .build();
        }
        return supabaseRetrofit;
    }
    
    // Get OpenAI client
    public static Retrofit getOpenAIClient() {
        if (openaiRetrofit == null) {
            openaiRetrofit = new Retrofit.Builder()
                    .baseUrl(ApiConfig.getOpenAIBaseUrl() + "/")
                    .addConverterFactory(GsonConverterFactory.create())
                    .client(createHttpClient())
                    .build();
        }
        return openaiRetrofit;
    }
    
    // Get direct API service instances only
    public static SupabaseApiService getSupabaseApiService() {
        if (supabaseApiService == null) {
            supabaseApiService = getSupabaseClient().create(SupabaseApiService.class);
        }
        return supabaseApiService;
    }
    
    public static OpenAIApiService getOpenAIApiService() {
        if (openaiApiService == null) {
            openaiApiService = getOpenAIClient().create(OpenAIApiService.class);
        }
        return openaiApiService;
    }
    
    // Helper methods
    public static boolean isLocalConfigured() {
        return ApiConfig.isConfigValid();
    }
    
    public static boolean isProduction() {
        return !ApiConfig.getConfigSource().equals("Local Development");
    }
    
    // Reset direct API clients (for testing)
    public static void resetClients() {
        supabaseRetrofit = null;
        openaiRetrofit = null;
        supabaseApiService = null;
        openaiApiService = null;
    }
}