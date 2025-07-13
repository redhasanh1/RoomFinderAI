package com.roomfinderai.app.services;

import android.util.Log;
import com.roomfinderai.app.config.ApiConfig;
import com.roomfinderai.app.models.*;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Arrays;

public class Repository {
    private static final String TAG = "Repository";
    private final SupabaseApiService supabaseApiService;
    private final OpenAIApiService openaiApiService;
    // NO RAILWAY - Direct APIs only
    
    public Repository() {
        this.supabaseApiService = ApiClient.getSupabaseApiService();
        this.openaiApiService = ApiClient.getOpenAIApiService();
        // NO Railway service initialization
        
        Log.d(TAG, "Repository initialized (Direct APIs only - NO Railway)");
        Log.d(TAG, "Config source: " + ApiConfig.getConfigSource());
        Log.d(TAG, "Config valid: " + ApiConfig.isConfigValid());
        Log.d(TAG, "Google Maps configured: " + ApiConfig.isGoogleMapsConfigured());
    }
    
    // Interface for handling API responses
    public interface ApiCallback<T> {
        void onSuccess(T result);
        void onError(String error);
    }
    
    // NO AUTHENTICATION METHODS - Direct APIs only
    // Note: Authentication would be handled by Supabase Auth directly if needed
    
    // Listings methods using Supabase
    public void getListings(ApiCallback<List<Listing>> callback) {
        if (!ApiConfig.isConfigValid()) {
            Log.e(TAG, "API configuration not valid");
            callback.onError("API configuration missing or invalid.");
            return;
        }
        
        Log.d(TAG, "🔍 Getting listings from Supabase...");
        Log.d(TAG, "Using: " + ApiConfig.getConfigSource());
        
        supabaseApiService.getListings(
            ApiConfig.getSupabaseAuthHeader(),
            ApiConfig.getSupabaseAnonKey()
        ).enqueue(new Callback<List<Listing>>() {
            @Override
            public void onResponse(Call<List<Listing>> call, Response<List<Listing>> response) {
                if (response.isSuccessful() && response.body() != null) {
                    Log.d(TAG, "✅ Supabase listings success: " + response.body().size() + " items");
                    callback.onSuccess(response.body());
                } else {
                    String error = "HTTP " + response.code() + ": " + response.message();
                    Log.e(TAG, "❌ Supabase listings error: " + error);
                    callback.onError(error);
                }
            }
            
            @Override
            public void onFailure(Call<List<Listing>> call, Throwable t) {
                Log.e(TAG, "❌ Supabase listings network error", t);
                callback.onError("Network error: " + t.getMessage());
            }
        });
    }
    
    public void getListings(Map<String, String> filters, ApiCallback<List<Listing>> callback) {
        if (!ApiConfig.isConfigValid()) {
            callback.onError("API configuration missing or invalid.");
            return;
        }
        
        Log.d(TAG, "🔍 Searching listings with filters: " + filters);
        
        // For now, use simple search - in production you'd build proper Supabase queries
        String searchTerm = filters.get("search");
        if (searchTerm != null) {
            // Use Supabase PostgREST syntax: ilike.*searchTerm*
            String searchQuery = "ilike.*" + searchTerm + "*";
            
            supabaseApiService.searchListings(
                ApiConfig.getSupabaseAuthHeader(),
                ApiConfig.getSupabaseAnonKey(),
                searchQuery
            ).enqueue(new Callback<List<Listing>>() {
                @Override
                public void onResponse(Call<List<Listing>> call, Response<List<Listing>> response) {
                    if (response.isSuccessful() && response.body() != null) {
                        Log.d(TAG, "✅ Supabase search success: " + response.body().size() + " results");
                        callback.onSuccess(response.body());
                    } else {
                        String error = "HTTP " + response.code() + ": " + response.message();
                        Log.e(TAG, "❌ Supabase search error: " + error);
                        callback.onError(error);
                    }
                }
                
                @Override
                public void onFailure(Call<List<Listing>> call, Throwable t) {
                    Log.e(TAG, "❌ Supabase search network error", t);
                    callback.onError("Network error: " + t.getMessage());
                }
            });
        } else {
            // No search term, get all listings
            getListings(callback);
        }
    }
    
    public void createListing(Listing listing, ApiCallback<Listing> callback) {
        if (!ApiConfig.isConfigValid()) {
            callback.onError("Supabase configuration missing. Please add your API keys.");
            return;
        }
        
        Log.d(TAG, "📝 Creating listing in Supabase: " + listing.getTitle());
        
        supabaseApiService.createListing(
            ApiConfig.getSupabaseAuthHeader(),
            ApiConfig.getSupabaseAnonKey(),
            "return=representation",
            listing
        ).enqueue(new Callback<Listing>() {
            @Override
            public void onResponse(Call<Listing> call, Response<Listing> response) {
                if (response.isSuccessful() && response.body() != null) {
                    Log.d(TAG, "✅ Supabase create listing success");
                    callback.onSuccess(response.body());
                } else {
                    String error = "HTTP " + response.code() + ": " + response.message();
                    Log.e(TAG, "❌ Supabase create listing error: " + error);
                    callback.onError(error);
                }
            }
            
            @Override
            public void onFailure(Call<Listing> call, Throwable t) {
                Log.e(TAG, "❌ Supabase create listing network error", t);
                callback.onError("Network error: " + t.getMessage());
            }
        });
    }
    
    // AI Chat methods using Direct OpenAI ONLY (NO RAILWAY)
    public void sendMessage(String message, String userId, String sessionId, ApiCallback<ChatMessage> callback) {
        sendMessageDirectOpenAI(message, userId, sessionId, callback);
    }
    
    // AI Chat methods using Direct OpenAI (Fallback)
    public void sendMessageDirectOpenAI(String message, String userId, String sessionId, ApiCallback<ChatMessage> callback) {
        if (!ApiConfig.isConfigValid()) {
            callback.onError("OpenAI configuration missing. Please add your API key.");
            return;
        }
        
        Log.d(TAG, "🤖 Sending message to Direct OpenAI: " + message);
        
        // Create OpenAI chat completion request
        Map<String, Object> request = new HashMap<>();
        request.put("model", "gpt-3.5-turbo");
        request.put("messages", Arrays.asList(
            createMessageMap("system", "You are a helpful AI assistant for a room rental app. Help users find rooms and negotiate with landlords."),
            createMessageMap("user", message)
        ));
        request.put("max_tokens", 150);
        request.put("temperature", 0.7);
        
        openaiApiService.createChatCompletion(
            ApiConfig.getOpenAIAuthHeader(),
            "application/json",
            request
        ).enqueue(new Callback<Map<String, Object>>() {
            @Override
            public void onResponse(Call<Map<String, Object>> call, Response<Map<String, Object>> response) {
                if (response.isSuccessful() && response.body() != null) {
                    try {
                        // Parse OpenAI response
                        Map<String, Object> responseBody = response.body();
                        List<Map<String, Object>> choices = (List<Map<String, Object>>) responseBody.get("choices");
                        if (choices != null && !choices.isEmpty()) {
                            Map<String, Object> firstChoice = choices.get(0);
                            Map<String, Object> messageObj = (Map<String, Object>) firstChoice.get("message");
                            String content = (String) messageObj.get("content");
                            
                            // Create ChatMessage response
                            ChatMessage chatMessage = new ChatMessage(content, false);
                            Log.d(TAG, "✅ OpenAI response: " + content);
                            callback.onSuccess(chatMessage);
                        } else {
                            Log.e(TAG, "❌ OpenAI: No choices in response");
                            callback.onError("No response from AI");
                        }
                    } catch (Exception e) {
                        Log.e(TAG, "❌ OpenAI response parsing error", e);
                        callback.onError("Error parsing AI response: " + e.getMessage());
                    }
                } else {
                    String error = "HTTP " + response.code() + ": " + response.message();
                    Log.e(TAG, "❌ OpenAI API error: " + error);
                    callback.onError(error);
                }
            }
            
            @Override
            public void onFailure(Call<Map<String, Object>> call, Throwable t) {
                Log.e(TAG, "❌ OpenAI network error", t);
                callback.onError("Network error: " + t.getMessage());
            }
        });
    }
    
    private Map<String, Object> createMessageMap(String role, String content) {
        Map<String, Object> message = new HashMap<>();
        message.put("role", role);
        message.put("content", content);
        return message;
    }
    
    // NO getChatHistory - Direct APIs only (chat history would be managed locally if needed)
    
    // Configuration methods
    public void getConfig(ApiCallback<Map<String, String>> callback) {
        Log.d(TAG, "📋 Getting local configuration...");
        
        // Return local configuration instead of calling Railway
        Map<String, String> config = new HashMap<>();
        config.put("SUPABASE_URL", ApiConfig.getSupabaseUrl());
        config.put("SUPABASE_CONFIGURED", String.valueOf(ApiConfig.isConfigValid()));
        config.put("OPENAI_CONFIGURED", String.valueOf(ApiConfig.isConfigValid()));
        config.put("GOOGLE_MAPS_CONFIGURED", String.valueOf(ApiConfig.isGoogleMapsConfigured()));
        config.put("SOURCE", ApiConfig.getConfigSource());
        
        Log.d(TAG, "✅ Local config loaded");
        callback.onSuccess(config);
    }
    
    // Generic response handler
    private <T> void handleResponse(Response<ApiResponse<T>> response, ApiCallback<T> callback) {
        try {
            if (response.isSuccessful() && response.body() != null) {
                ApiResponse<T> apiResponse = response.body();
                if (apiResponse.isSuccess()) {
                    callback.onSuccess(apiResponse.getData());
                } else {
                    String error = apiResponse.getError() != null ? apiResponse.getError() : "Unknown error";
                    callback.onError(error);
                }
            } else {
                String error = "HTTP " + response.code() + ": " + response.message();
                Log.e(TAG, "API call failed: " + error);
                callback.onError(error);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error handling response", e);
            callback.onError("Error processing response: " + e.getMessage());
        }
    }
}