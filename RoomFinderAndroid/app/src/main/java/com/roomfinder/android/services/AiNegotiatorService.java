package com.roomfinder.android.services;

import android.util.Log;
import com.roomfinder.android.utils.ApiKeys;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.IOException;
import java.util.List;
import java.util.ArrayList;
import java.util.concurrent.TimeUnit;
import okhttp3.*;

public class AiNegotiatorService {
    private static final String TAG = "AiNegotiatorService";
    private static final String OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";
    private static final MediaType JSON = MediaType.parse("application/json; charset=utf-8");
    
    private OkHttpClient client;
    private List<ChatMessage> conversationHistory;
    private int retryCount = 0;
    private static final int MAX_RETRIES = 3;
    private static final long RETRY_DELAY_MS = 2000; // 2 seconds
    
    public AiNegotiatorService() {
        this.client = new OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build();
        this.conversationHistory = new ArrayList<>();
    }
    
    public static class ChatMessage {
        public String role;
        public String content;
        
        public ChatMessage(String role, String content) {
            this.role = role;
            this.content = content;
        }
        
        public JSONObject toJson() throws JSONException {
            JSONObject json = new JSONObject();
            json.put("role", role);
            json.put("content", content);
            return json;
        }
    }
    
    public static class AiResponse {
        public String message;
        public boolean success;
        public String error;
        public PropertyCriteria extractedCriteria;
        
        public AiResponse(String message, boolean success) {
            this.message = message;
            this.success = success;
        }
        
        public AiResponse(String error) {
            this.success = false;
            this.error = error;
        }
    }
    
    public static class PropertyCriteria {
        public String location;
        public Integer maxPrice;
        public Integer minPrice;
        public String propertyType;
        public Integer bedrooms;
        public Integer bathrooms;
        
        public PropertyCriteria() {}
        
        public boolean hasValidCriteria() {
            return location != null || maxPrice != null || minPrice != null || 
                   propertyType != null || bedrooms != null || bathrooms != null;
        }
    }
    
    public interface AiResponseCallback {
        void onSuccess(AiResponse response);
        void onError(String error);
    }
    
    // Process user message and get AI response
    public void processMessage(String userMessage, AiResponseCallback callback) {
        // Reset retry count for new message
        retryCount = 0;
        processMessageWithRetry(userMessage, callback);
    }
    
    private void processMessageWithRetry(String userMessage, AiResponseCallback callback) {
        Log.d(TAG, "Processing message (attempt " + (retryCount + 1) + "): " + userMessage);
        
        // Validate API key
        if (ApiKeys.OPENAI_API_KEY == null || ApiKeys.OPENAI_API_KEY.isEmpty() || 
            "your_openai_api_key_here".equals(ApiKeys.OPENAI_API_KEY)) {
            Log.e(TAG, "OpenAI API key is not configured");
            callback.onError("AI service not configured. Please set your OpenAI API key in the environment variables.");
            return;
        }
        
        // Validate and sanitize user input
        if (userMessage == null || userMessage.trim().isEmpty()) {
            callback.onError("Please enter a message");
            return;
        }
        
        // Limit message length to prevent excessive API costs
        String sanitizedMessage = userMessage.trim();
        if (sanitizedMessage.length() > 1000) {
            sanitizedMessage = sanitizedMessage.substring(0, 1000) + "...";
        }
        
        // Add user message to conversation history only on first attempt
        if (retryCount == 0) {
            conversationHistory.add(new ChatMessage("user", sanitizedMessage));
        }
        
        // Build the system prompt for the AI negotiator
        String systemPrompt = buildSystemPrompt();
        
        try {
            JSONObject requestBody = buildOpenAiRequest(systemPrompt, sanitizedMessage);
            Request request = new Request.Builder()
                    .url(OPENAI_API_URL)
                    .addHeader("Authorization", "Bearer " + ApiKeys.OPENAI_API_KEY)
                    .addHeader("Content-Type", "application/json")
                    .post(RequestBody.create(requestBody.toString(), JSON))
                    .build();
            
            client.newCall(request).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    Log.e(TAG, "OpenAI API call failed", e);
                    String errorMsg = "Network error";
                    if (e instanceof java.net.UnknownHostException) {
                        errorMsg = "Cannot connect to AI service. Check internet connection.";
                    } else if (e instanceof java.net.SocketTimeoutException) {
                        errorMsg = "Request timed out. Please try again.";
                    } else if (e instanceof javax.net.ssl.SSLException) {
                        errorMsg = "Secure connection failed. Please check network settings.";
                    } else if (e.getMessage() != null) {
                        errorMsg = "Network error: " + e.getMessage();
                    }
                    callback.onError(errorMsg);
                }
                
                @Override
                public void onResponse(Call call, Response response) throws IOException {
                    try {
                        if (!response.isSuccessful()) {
                            String errorBody = response.body() != null ? response.body().string() : "Unknown error";
                            Log.e(TAG, "OpenAI API error: " + response.code() + " - " + errorBody);
                            
                            String userErrorMsg;
                            switch (response.code()) {
                                case 401:
                                    userErrorMsg = "Invalid API key. Please check configuration.";
                                    break;
                                case 429:
                                    userErrorMsg = "Rate limit exceeded. Please try again later.";
                                    break;
                                case 500:
                                case 502:
                                case 503:
                                    userErrorMsg = "AI service temporarily unavailable. Please try again.";
                                    break;
                                default:
                                    userErrorMsg = "AI service error (" + response.code() + "). Please try again.";
                            }
                            callback.onError(userErrorMsg);
                            return;
                        }
                        
                        String responseBody = response.body().string();
                        JSONObject jsonResponse = new JSONObject(responseBody);
                        
                        JSONArray choices = jsonResponse.getJSONArray("choices");
                        if (choices.length() > 0) {
                            JSONObject firstChoice = choices.getJSONObject(0);
                            JSONObject message = firstChoice.getJSONObject("message");
                            String aiMessage = message.getString("content");
                            
                            // Add AI response to conversation history
                            conversationHistory.add(new ChatMessage("assistant", aiMessage));
                            
                            // Extract property criteria if this looks like a search query
                            PropertyCriteria criteria = extractPropertyCriteria(userMessage);
                            Log.d(TAG, "Extracted property criteria: " + (criteria.hasValidCriteria() ? "Found criteria" : "No criteria"));
                            
                            AiResponse aiResponse = new AiResponse(aiMessage, true);
                            aiResponse.extractedCriteria = criteria;
                            
                            Log.d(TAG, "AI response successful: " + aiMessage.substring(0, Math.min(50, aiMessage.length())) + "...");
                            callback.onSuccess(aiResponse);
                        } else {
                            callback.onError("No response from AI");
                        }
                        
                    } catch (JSONException e) {
                        Log.e(TAG, "Error parsing OpenAI response", e);
                        callback.onError("Error parsing AI response");
                    }
                }
            });
            
        } catch (JSONException e) {
            Log.e(TAG, "Error building OpenAI request", e);
            callback.onError("Error building request");
        }
    }
    
    private String buildSystemPrompt() {
        return "You are an AI rental negotiation assistant for RoomFinderAI. Your role is to:\n\n" +
               "1. Help users find rental properties by understanding their criteria (location, price, type, etc.)\n" +
               "2. Provide expert negotiation advice for dealing with landlords\n" +
               "3. Generate professional messages and emails for landlord communication\n" +
               "4. Offer market insights and rental strategies\n" +
               "5. Guide users through the rental application process\n\n" +
               "When users provide search criteria, acknowledge what you understand and let them know you'll search the database. " +
               "For negotiation help, provide specific tactics and ready-to-send message templates. " +
               "Be professional, helpful, and focus on getting users the best rental deals possible.\n\n" +
               "Keep responses concise but informative. Always ask clarifying questions when criteria are unclear.";
    }
    
    private JSONObject buildOpenAiRequest(String systemPrompt, String userMessage) throws JSONException {
        JSONObject request = new JSONObject();
        request.put("model", ApiKeys.OPENAI_MODEL);
        request.put("max_tokens", 500);
        request.put("temperature", 0.7);
        
        JSONArray messages = new JSONArray();
        
        // Add system prompt
        JSONObject systemMessage = new JSONObject();
        systemMessage.put("role", "system");
        systemMessage.put("content", systemPrompt);
        messages.put(systemMessage);
        
        // Add conversation history (keep last 10 messages for context)
        int startIndex = Math.max(0, conversationHistory.size() - 10);
        for (int i = startIndex; i < conversationHistory.size(); i++) {
            messages.put(conversationHistory.get(i).toJson());
        }
        
        request.put("messages", messages);
        return request;
    }
    
    // Extract property search criteria from user message using simple parsing
    private PropertyCriteria extractPropertyCriteria(String message) {
        PropertyCriteria criteria = new PropertyCriteria();
        String lowerMessage = message.toLowerCase();
        
        // Extract location
        if (lowerMessage.contains(" in ")) {
            String[] parts = lowerMessage.split(" in ");
            if (parts.length > 1) {
                String locationPart = parts[1].split(" ")[0];
                criteria.location = locationPart.replaceAll("[^a-zA-Z\\s]", "").trim();
            }
        }
        
        // Extract price range
        if (lowerMessage.contains("$")) {
            String[] words = lowerMessage.split("\\s+");
            for (String word : words) {
                if (word.contains("$")) {
                    try {
                        String priceStr = word.replaceAll("[^0-9]", "");
                        if (!priceStr.isEmpty()) {
                            int price = Integer.parseInt(priceStr);
                            if (lowerMessage.contains("under") || lowerMessage.contains("below") || lowerMessage.contains("max")) {
                                criteria.maxPrice = price;
                            } else if (lowerMessage.contains("over") || lowerMessage.contains("above") || lowerMessage.contains("min")) {
                                criteria.minPrice = price;
                            } else {
                                criteria.maxPrice = price; // Default to max price
                            }
                        }
                    } catch (NumberFormatException e) {
                        // Ignore invalid price formats
                    }
                }
            }
        }
        
        // Extract property type
        if (lowerMessage.contains("studio")) {
            criteria.propertyType = "studio";
        } else if (lowerMessage.contains("apartment")) {
            criteria.propertyType = "apartment";
        } else if (lowerMessage.contains("house")) {
            criteria.propertyType = "house";
        } else if (lowerMessage.contains("condo")) {
            criteria.propertyType = "condo";
        }
        
        // Extract bedrooms
        if (lowerMessage.contains("bedroom")) {
            String[] words = lowerMessage.split("\\s+");
            for (int i = 0; i < words.length - 1; i++) {
                if (words[i + 1].contains("bedroom")) {
                    try {
                        criteria.bedrooms = Integer.parseInt(words[i].replaceAll("[^0-9]", ""));
                        break;
                    } catch (NumberFormatException e) {
                        // Try text numbers
                        String numWord = words[i].toLowerCase();
                        if (numWord.contains("one") || numWord.contains("1")) criteria.bedrooms = 1;
                        else if (numWord.contains("two") || numWord.contains("2")) criteria.bedrooms = 2;
                        else if (numWord.contains("three") || numWord.contains("3")) criteria.bedrooms = 3;
                        else if (numWord.contains("four") || numWord.contains("4")) criteria.bedrooms = 4;
                    }
                }
            }
        }
        
        return criteria;
    }
    
    // Clear conversation history
    public void clearConversation() {
        conversationHistory.clear();
    }
    
    // Get conversation history
    public List<ChatMessage> getConversationHistory() {
        return new ArrayList<>(conversationHistory);
    }
    
    // Add message to conversation history without sending to AI
    public void addMessage(String role, String content) {
        conversationHistory.add(new ChatMessage(role, content));
    }
}