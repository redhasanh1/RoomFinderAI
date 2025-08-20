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
                systemMessage.put("content", "You are an aggressive rental price negotiator. Your ONLY goal is to get the lowest price possible. " +
                        "RULES: 1) ALWAYS ask for exact price in first message. 2) ALWAYS counter with 15-20% below their price. " +
                        "3) If they say 'can lower' or 'negotiable', immediately ask 'What's your absolute best price?' " +
                        "4) If they mention a number, counter with specific amount (e.g., they say $2000, you say 'Would you accept $1600?'). " +
                        "5) Deflect meetings: 'Let's finalize the price first via text, then we can meet.' " +
                        "6) After 3 exchanges, close with 'My final offer is $X. I can sign today with deposit ready.' " +
                        "Be direct, confident, numbers-focused. Maximum 2 sentences per response.");
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
        
        // Handle initial contact vs follow-up responses
        if (landlordMessage.equals("INITIAL_CONTACT")) {
            prompt.append("TASK: Write an AGGRESSIVE initial price inquiry. MANDATORY format:\n");
            prompt.append("'Hi, I'm interested in your [property location]. What's your absolute best price? ");
            prompt.append("I'm looking to pay around $[offer 25% below listing] and can move in immediately with deposit ready.'\n");
            prompt.append("RULES: 1) First sentence asks for best price. 2) Second sentence makes lowball offer. ");
            prompt.append("3) Mention immediate availability. 4) NO pleasantries, NO long introductions.\n");
        } else {
            // Specific instructions based on landlord message content
            String lowerMessage = landlordMessage.toLowerCase().trim();
            
            // Enhanced price detection with multiple patterns
            java.util.regex.Pattern dollarPattern = java.util.regex.Pattern.compile("\\$\\s?(\\d{3,5})(?:\\.\\d{2})?");
            java.util.regex.Pattern plainPattern = java.util.regex.Pattern.compile("\\b(\\d{3,5})\\b(?!\\s*(?:pm|am|hours?|minutes?|days?|weeks?|months?|years?))");
            
            String extractedPrice = null;
            java.util.regex.Matcher dollarMatcher = dollarPattern.matcher(lowerMessage);
            if (dollarMatcher.find()) {
                extractedPrice = dollarMatcher.group(1);
            } else {
                java.util.regex.Matcher plainMatcher = plainPattern.matcher(lowerMessage);
                if (plainMatcher.find()) {
                    String potentialPrice = plainMatcher.group(1);
                    int value = Integer.parseInt(potentialPrice);
                    if (value >= 500 && value <= 10000) { // Reasonable rent range
                        extractedPrice = potentialPrice;
                    }
                }
            }
            
            if (extractedPrice != null) {
                int price = Integer.parseInt(extractedPrice);
                int counterOffer = (int)(price * 0.80); // Start with 20% below
                int finalOffer = (int)(price * 0.85); // Final offer at 15% below
                
                prompt.append("CRITICAL: Landlord stated price of $").append(extractedPrice).append(". ");
                prompt.append("COUNTER IMMEDIATELY with $").append(counterOffer).append(" (say exactly: 'Would you accept $").append(counterOffer).append("?'). ");
                prompt.append("If they reject, your final offer is $").append(finalOffer).append(". ");
                prompt.append("Never go above $").append(finalOffer).append(".\n");
            } else if (lowerMessage.contains("lower") || lowerMessage.contains("reduce") || lowerMessage.contains("negotiable") || 
                       lowerMessage.contains("flexible") || lowerMessage.contains("can do") || lowerMessage.contains("abit") || 
                       lowerMessage.contains("a bit") || lowerMessage.contains("willing to")) {
                prompt.append("TASK: Landlord is flexible on price! IMMEDIATELY ask: 'Great! What's your absolute best price?' ");
                prompt.append("If they already stated a price, counter 20% below. Don't waste this opportunity.\n");
            } else if (lowerMessage.contains("meet") || lowerMessage.contains("viewing") || lowerMessage.contains("see the") || 
                       lowerMessage.contains("visit") || lowerMessage.contains("show you") || lowerMessage.contains("tour")) {
                prompt.append("TASK: DEFLECT meeting request. Say: 'I'd love to see it! Let's finalize the price first - what's your best rate? ");
                prompt.append("Once we agree on price, I can view it immediately.' Keep focus on PRICE.\n");
            } else if (lowerMessage.contains("sure") || lowerMessage.contains("okay") || lowerMessage.contains("yes") || 
                       lowerMessage.contains("sounds good") || lowerMessage.contains("agreed")) {
                prompt.append("TASK: They agreed! Lock it in: 'Excellent! So we're confirmed at $[price]? I can sign the lease today with deposit ready.'\n");
            } else if (lowerMessage.contains("no") || lowerMessage.contains("can't") || lowerMessage.contains("cannot") || 
                       lowerMessage.contains("firm") || lowerMessage.contains("final")) {
                prompt.append("TASK: They're being firm. Make ONE final offer: 'I understand. My absolute best is $[5% below their price]. ");
                prompt.append("I'm a great tenant with excellent references and ready to move immediately. Can we make this work?'\n");
            } else if (lowerMessage.contains("hi") || lowerMessage.contains("hello") || lowerMessage.length() < 15) {
                prompt.append("TASK: Skip pleasantries. Immediately ask: 'Hi! What's your best price on the rental?'\n");
            } else {
                prompt.append("TASK: Unknown response. Default to asking about price: 'Thanks for your response. What's the best price you can offer?'\n");
            }
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