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
            // Retry logic - try up to 3 times
            for (int attempt = 1; attempt <= 3; attempt++) {
                Log.d(TAG, "🤖 [OPENAI] Attempt " + attempt + "/3");
                
                boolean success = tryGenerateResponse(landlordMessage, conversationContext, 
                                                    listingDetails, userPreferences, callback, attempt);
                if (success) {
                    return; // Success, exit retry loop
                }
                
                // If this wasn't the last attempt, wait before retrying
                if (attempt < 3) {
                    try {
                        Thread.sleep(1000 * attempt); // Exponential backoff: 1s, 2s
                        Log.d(TAG, "🤖 [OPENAI] Retrying after " + (1000 * attempt) + "ms delay...");
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        break;
                    }
                }
            }
            
            // All attempts failed
            Log.e(TAG, "🤖 [OPENAI] All 3 attempts failed");
            if (callback != null) {
                callback.onError("OpenAI failed after 3 attempts");
            }
        });
    }
    
    /**
     * Single attempt to generate response
     */
    private boolean tryGenerateResponse(String landlordMessage, String conversationContext, 
                                      String listingDetails, String userPreferences, 
                                      OpenAICallback callback, int attempt) {
        try {
            String prompt = buildNegotiationPrompt(landlordMessage, conversationContext, 
                                                 listingDetails, userPreferences);
                
                JSONObject requestBody = new JSONObject();
                // Enhanced API request configuration
                String model = ApiKeys.OPENAI_MODEL != null ? ApiKeys.OPENAI_MODEL : "gpt-3.5-turbo";
                Log.d(TAG, "🤖 [OPENAI] Using model: " + model);
                
                requestBody.put("model", model);
                requestBody.put("max_tokens", 400); // Increased for more detailed responses
                requestBody.put("temperature", 0.8); // Slightly more creative
                
                JSONArray messages = new JSONArray();
                JSONObject systemMessage = new JSONObject();
                systemMessage.put("role", "system");
                systemMessage.put("content", "You are an expert rental negotiation AI helping a tenant. Be natural, enthusiastic, and specific. " +
                        "Respond directly to what the landlord said. If they mention price, address that price specifically. " +
                        "If they seem positive, suggest next steps like viewing. If they're open to negotiation, engage actively. " +
                        "Keep responses conversational and under 3 sentences. Never use generic templates.");
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
                
                // Debug API key
                String apiKey = ApiKeys.OPENAI_API_KEY;
                if (apiKey == null || apiKey.trim().isEmpty()) {
                    Log.e(TAG, "🤖 [OPENAI] ❌ API KEY IS NULL OR EMPTY!");
                    if (callback != null) {
                        callback.onError("OpenAI API key not configured");
                    }
                    return false;
                }
                Log.d(TAG, "🤖 [OPENAI] API key length: " + apiKey.length() + " characters");
                
                Request request = new Request.Builder()
                        .url(OPENAI_API_URL)
                        .post(body)
                        .addHeader("Authorization", "Bearer " + apiKey)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                Log.d(TAG, "🤖 [OPENAI] Sending request to: " + OPENAI_API_URL);
                Log.d(TAG, "🤖 [OPENAI] Request body: " + requestBody.toString());
                
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
                        response.close();
                        return true; // Success
                    } else {
                        String error = "No response from OpenAI";
                        Log.e(TAG, "🤖 [OPENAI] " + error);
                        if (callback != null) {
                            callback.onError(error);
                        }
                        response.close();
                        return false; // Failed - no response
                    }
                } else {
                    String errorBody = "";
                    try {
                        if (response.body() != null) {
                            errorBody = response.body().string();
                        }
                    } catch (Exception e) {
                        Log.e(TAG, "🤖 [OPENAI] Could not read error response body", e);
                    }
                    
                    String error = "OpenAI API request failed: " + response.code() + " " + response.message();
                    Log.e(TAG, "🤖 [OPENAI] " + error);
                    Log.e(TAG, "🤖 [OPENAI] Error response body: " + errorBody);
                    
                    if (callback != null) {
                        callback.onError(error + (errorBody.isEmpty() ? "" : ": " + errorBody));
                    }
                    response.close();
                    return false; // Failed - API error
                }
                
        } catch (Exception e) {
            String error = "OpenAI API error: " + e.getMessage();
            Log.e(TAG, "🤖 [OPENAI] Attempt " + attempt + " failed: " + error, e);
            // Don't call callback here - let the retry logic handle it
            return false; // Failed - exception
        }
    }
    
    /**
     * Build intelligent prompt for OpenAI with full context
     */
    private String buildNegotiationPrompt(String landlordMessage, String conversationContext,
                                        String listingDetails, String userPreferences) {
        StringBuilder prompt = new StringBuilder();
        
        // Start with specific context
        prompt.append("RENTAL NEGOTIATION CONTEXT:\n");
        if (listingDetails != null && !listingDetails.isEmpty()) {
            prompt.append("Property: ").append(listingDetails).append("\n");
        }
        
        if (userPreferences != null && !userPreferences.isEmpty()) {
            prompt.append("My budget/preferences: ").append(userPreferences).append("\n");
        }
        
        // Add conversation history for context
        if (conversationContext != null && !conversationContext.isEmpty() && !conversationContext.equals("This is the beginning of our conversation.")) {
            prompt.append("\nPrevious conversation:\n").append(conversationContext).append("\n");
        }
        
        // The landlord's specific message
        prompt.append("\nLandlord just replied: \"").append(landlordMessage).append("\"\n\n");
        
        // Specific instructions based on landlord message content
        String lowerMessage = landlordMessage.toLowerCase().trim();
        
        if (lowerMessage.contains("1500") || lowerMessage.matches(".*\\b(\\d{3,4})\\b.*")) {
            prompt.append("TASK: The landlord mentioned a specific price. Respond enthusiastically if it works for you, or negotiate if it's too high. Be specific about the amount they mentioned.\n");
        } else if (lowerMessage.contains("lower") || lowerMessage.contains("reduce") || lowerMessage.contains("can do")) {
            prompt.append("TASK: The landlord is open to lowering the price. Show appreciation and either suggest a specific amount or ask what they can offer.\n");
        } else if (lowerMessage.contains("sure") || lowerMessage.contains("okay") || lowerMessage.contains("yes") || lowerMessage.contains("sounds good")) {
            prompt.append("TASK: The landlord agreed to something. Be excited and suggest concrete next steps like scheduling a viewing.\n");
        } else if (lowerMessage.contains("hi") || lowerMessage.contains("hello") || lowerMessage.length() < 10) {
            prompt.append("TASK: This seems like a brief/casual response. Respond warmly and move the conversation toward specifics about the rental.\n");
        } else {
            prompt.append("TASK: Respond naturally to what they said, show enthusiasm, and move toward next steps (viewing, lease terms, etc.).\n");
        }
        
        prompt.append("\nWrite a natural, enthusiastic response (2-3 sentences max). Be specific and avoid generic phrases:");
        
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