package com.roomfinder.android.services;

import android.util.Log;
import com.roomfinder.android.utils.ApiKeys;
import org.json.JSONArray;
import org.json.JSONObject;
import okhttp3.*;
import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * OpenAI API service for intelligent negotiation responses
 */
public class OpenAIService {
    private static final String TAG = "OpenAIService";
    private static final String OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";
    
    private final OkHttpClient httpClient;
    private final ExecutorService executorService;
    
    public interface OpenAICallback {
        void onSuccess(String response);
        void onError(String error);
    }
    
    public OpenAIService() {
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .readTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
                .build();
        this.executorService = Executors.newCachedThreadPool();
    }
    
    /**
     * Generate intelligent negotiation response using OpenAI
     */
    public void generateNegotiationResponse(String landlordMessage, String conversationContext, 
                                          String listingDetails, String userPreferences, 
                                          OpenAICallback callback) {
        Log.d(TAG, "🤖 [OPENAI] Generating intelligent response for: " + landlordMessage);
        
        executorService.execute(() -> {
            try {
                String prompt = buildNegotiationPrompt(landlordMessage, conversationContext, 
                                                     listingDetails, userPreferences);
                
                JSONObject requestBody = new JSONObject();
                requestBody.put("model", ApiKeys.OPENAI_MODEL);
                requestBody.put("max_tokens", 200);
                requestBody.put("temperature", 0.7);
                
                JSONArray messages = new JSONArray();
                JSONObject systemMessage = new JSONObject();
                systemMessage.put("role", "system");
                systemMessage.put("content", "You are a helpful AI assistant helping a tenant negotiate with landlords. Respond professionally, enthusiastically, and concisely. Always aim to move the conversation toward viewing/signing.");
                messages.put(systemMessage);
                
                JSONObject userMessage = new JSONObject();
                userMessage.put("role", "user");
                userMessage.put("content", prompt);
                messages.put(userMessage);
                
                requestBody.put("messages", messages);
                
                RequestBody body = RequestBody.create(
                    requestBody.toString(),
                    MediaType.parse("application/json")
                );
                
                Request request = new Request.Builder()
                        .url(OPENAI_API_URL)
                        .post(body)
                        .addHeader("Authorization", "Bearer " + ApiKeys.OPENAI_API_KEY)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                Response response = httpClient.newCall(request).execute();
                
                if (response.isSuccessful() && response.body() != null) {
                    String responseBody = response.body().string();
                    Log.d(TAG, "🤖 [OPENAI] Raw response: " + responseBody);
                    
                    JSONObject jsonResponse = new JSONObject(responseBody);
                    JSONArray choices = jsonResponse.getJSONArray("choices");
                    
                    if (choices.length() > 0) {
                        JSONObject choice = choices.getJSONObject(0);
                        JSONObject message = choice.getJSONObject("message");
                        String aiResponse = message.getString("content").trim();
                        
                        Log.d(TAG, "🤖 [OPENAI] Generated response: " + aiResponse);
                        
                        if (callback != null) {
                            callback.onSuccess(aiResponse);
                        }
                    } else {
                        String error = "No response from OpenAI";
                        Log.e(TAG, "🤖 [OPENAI] " + error);
                        if (callback != null) {
                            callback.onError(error);
                        }
                    }
                } else {
                    String error = "OpenAI API request failed: " + response.code();
                    Log.e(TAG, "🤖 [OPENAI] " + error);
                    if (callback != null) {
                        callback.onError(error);
                    }
                }
                
                response.close();
                
            } catch (Exception e) {
                String error = "OpenAI API error: " + e.getMessage();
                Log.e(TAG, "🤖 [OPENAI] " + error, e);
                if (callback != null) {
                    callback.onError(error);
                }
            }
        });
    }
    
    /**
     * Build intelligent prompt for OpenAI with full context
     */
    private String buildNegotiationPrompt(String landlordMessage, String conversationContext,
                                        String listingDetails, String userPreferences) {
        StringBuilder prompt = new StringBuilder();
        
        prompt.append("I'm negotiating to rent this property:\n");
        if (listingDetails != null) {
            prompt.append("Property: ").append(listingDetails).append("\n");
        }
        
        if (userPreferences != null) {
            prompt.append("My preferences: ").append(userPreferences).append("\n");
        }
        
        prompt.append("\nConversation so far:\n");
        if (conversationContext != null) {
            prompt.append(conversationContext).append("\n");
        }
        
        prompt.append("\nLandlord just said: \"").append(landlordMessage).append("\"\n\n");
        
        prompt.append("Generate a professional, enthusiastic response that:\n");
        prompt.append("1. Acknowledges what they said appropriately\n");
        prompt.append("2. Shows genuine interest and enthusiasm\n");
        prompt.append("3. Moves toward scheduling a viewing or finalizing terms\n");
        prompt.append("4. Is concise (2-3 sentences max)\n");
        prompt.append("5. Sounds natural and friendly\n\n");
        
        // Add specific context based on landlord message
        String lowerMessage = landlordMessage.toLowerCase();
        if (lowerMessage.contains("1500") || lowerMessage.matches(".*\\b\\d{3,4}\\b.*")) {
            prompt.append("The landlord mentioned a specific price. If it's reasonable, accept it enthusiastically and suggest next steps.\n");
        } else if (lowerMessage.contains("lower") || lowerMessage.contains("reduce")) {
            prompt.append("The landlord is open to lowering the price. Respond positively and suggest a specific amount or ask what they can do.\n");
        } else if (lowerMessage.contains("sure") || lowerMessage.contains("okay") || lowerMessage.contains("yes")) {
            prompt.append("The landlord agreed to something. Respond enthusiastically and move toward viewing/signing.\n");
        }
        
        prompt.append("\nResponse:");
        
        return prompt.toString();
    }
    
    /**
     * Clean up resources
     */
    public void shutdown() {
        if (executorService != null && !executorService.isShutdown()) {
            executorService.shutdown();
        }
    }
}