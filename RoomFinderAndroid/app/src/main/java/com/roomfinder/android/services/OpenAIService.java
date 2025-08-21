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
                systemMessage.put("content", "You are a professional rental negotiation assistant helping tenants secure fair rental terms. Your goal is to achieve reasonable pricing through respectful communication. " +
                        "APPROACH: 1) Begin by inquiring about rental terms and pricing. 2) If appropriate, make reasonable counter-offers based on market conditions. " +
                        "3) If they indicate flexibility, ask politely about their best available rate. " +
                        "4) Make specific offers only after understanding their position (e.g., 'Based on similar properties in the area, would $X work?'). " +
                        "5) When discussing viewings, suggest coordinating both price discussion and property viewing. " +
                        "6) Only proceed to lease terms after both parties show genuine interest and agreement. " +
                        "Be professional, respectful, and patient. Build rapport while advocating for fair terms. Maximum 3 sentences per response.");
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
            prompt.append("TASK: Write a professional initial inquiry about the rental property.\n");
            prompt.append("APPROACH: 'Hello! I'm very interested in your rental property [location]. Could you please share the rental rate and any key details about the lease terms? ");
            prompt.append("I'm a reliable tenant looking for a place in this area and would appreciate learning more about what you're offering.'\n");
            prompt.append("GUIDELINES: 1) Be polite and professional. 2) Express genuine interest. ");
            prompt.append("3) Ask for information before making any offers. 4) Build rapport first.\n");
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
                int reasonableOffer = (int)(price * 0.90); // Start with reasonable 10% below
                
                prompt.append("CONTEXT: Landlord mentioned a price of $").append(extractedPrice).append(". ");
                prompt.append("RESPONSE: Thank them for the information and ask if they have any flexibility: 'Thank you for sharing that rate. ");
                prompt.append("I'm very interested in the property. Is there any flexibility on the rental rate? ");
                prompt.append("I noticed similar properties in the area are around $").append(reasonableOffer).append(". Would that work for both of us?'\n");
            } else if (lowerMessage.contains("lower") || lowerMessage.contains("reduce") || lowerMessage.contains("negotiable") || 
                       lowerMessage.contains("flexible") || lowerMessage.contains("can do") || lowerMessage.contains("abit") || 
                       lowerMessage.contains("a bit") || lowerMessage.contains("willing to")) {
                prompt.append("RESPONSE: Landlord indicates price flexibility. Respond positively: 'That's great to hear you have some flexibility! ");
                prompt.append("Could you let me know what rate might work best? I'm genuinely interested and looking for a fair arrangement for both of us.'\n");
            } else if (lowerMessage.contains("meet") || lowerMessage.contains("viewing") || lowerMessage.contains("see the") || 
                       lowerMessage.contains("visit") || lowerMessage.contains("show you") || lowerMessage.contains("tour")) {
                prompt.append("RESPONSE: Landlord suggests viewing the property. Respond enthusiastically: 'I'd love to schedule a viewing! ");
                prompt.append("Before we set that up, could you share the rental rate so I know it fits my budget? Happy to coordinate a time that works for both of us.'\n");
            } else if (lowerMessage.contains("sure") || lowerMessage.contains("okay") || lowerMessage.contains("yes") || 
                       lowerMessage.contains("sounds good") || lowerMessage.contains("agreed")) {
                // Try to extract the most recent price mentioned in the conversation
                String specificPrice = "the terms we discussed";
                java.util.regex.Matcher priceInContext = dollarPattern.matcher(conversationContext != null ? conversationContext : "");
                if (priceInContext.find()) {
                    specificPrice = "$" + priceInContext.group(1) + " per month";
                } else if (extractedPrice != null) {
                    specificPrice = "$" + extractedPrice + " per month";
                }
                
                prompt.append("RESPONSE: Landlord seems to agree. Seek clarification: 'Wonderful! Just to confirm, are you agreeing to " + specificPrice + "? ");
                prompt.append("I want to make sure we're both on the same page before moving forward with next steps.'\n");
            } else if (lowerMessage.contains("no") || lowerMessage.contains("can't") || lowerMessage.contains("cannot") || 
                       lowerMessage.contains("firm") || lowerMessage.contains("final")) {
                prompt.append("RESPONSE: Landlord indicates they cannot adjust price. Respect their position: 'I understand and appreciate your transparency. ");
                prompt.append("Let me think about whether the current rate works for my budget. Can I get back to you shortly with my decision?'\n");
            } else if (lowerMessage.contains("hi") || lowerMessage.contains("hello") || lowerMessage.length() < 15) {
                prompt.append("RESPONSE: Return the greeting politely: 'Hello! Thank you for reaching out. I'm interested in learning more about your rental property. ");
                prompt.append("Could you share some details about the rent and lease terms?'\n");
            } else {
                prompt.append("RESPONSE: Acknowledge their message and ask for clarification: 'Thank you for your message. ");
                prompt.append("I'm very interested in the property. Could you provide more details about the rental terms?'\n");
            }
        }
        
        prompt.append("\nWrite a natural, professional response (2-3 sentences max). Be respectful, genuine, and focused on building a positive relationship:");
        
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