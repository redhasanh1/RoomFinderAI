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
    
    // Extract property search criteria from user message using enhanced parsing
    private PropertyCriteria extractPropertyCriteria(String message) {
        PropertyCriteria criteria = new PropertyCriteria();
        String lowerMessage = message.toLowerCase();
        
        Log.d(TAG, "🔍 Extracting criteria from: \"" + message + "\"");
        
        // Enhanced location extraction
        criteria.location = extractLocation(lowerMessage);
        Log.d(TAG, "📍 Location extracted: " + criteria.location);
        
        criteria.maxPrice = extractMaxPrice(lowerMessage);
        Log.d(TAG, "💰 Max price extracted: " + criteria.maxPrice);
        
        criteria.minPrice = extractMinPrice(lowerMessage);
        Log.d(TAG, "💰 Min price extracted: " + criteria.minPrice);
        
        criteria.propertyType = extractPropertyType(lowerMessage);
        Log.d(TAG, "🏠 Property type extracted: " + criteria.propertyType);
        
        criteria.bedrooms = extractBedrooms(lowerMessage);
        Log.d(TAG, "🛏️ Bedrooms extracted: " + criteria.bedrooms);
        
        criteria.bathrooms = extractBathrooms(lowerMessage);
        Log.d(TAG, "🚿 Bathrooms extracted: " + criteria.bathrooms);
        
        Log.d(TAG, "✅ Criteria extraction complete. Has valid criteria: " + criteria.hasValidCriteria());
        
        return criteria;
    }
    
    private String extractLocation(String message) {
        Log.d(TAG, "🔎 Extracting location from: " + message);
        
        // Pattern 1: "in [location]" - most common
        if (message.contains(" in ")) {
            String[] parts = message.split(" in ");
            if (parts.length > 1) {
                String locationPart = parts[1];
                Log.d(TAG, "📍 Found 'in' pattern, location part: " + locationPart);
                
                // Take everything until next major keyword or end
                String[] stopWords = {" with ", " under ", " over ", " for ", " that ", " where ", " near ", " around ", " at ", " priced ", " costing ", " around ", " about "};
                for (String stopWord : stopWords) {
                    if (locationPart.contains(stopWord)) {
                        locationPart = locationPart.split(stopWord)[0];
                        Log.d(TAG, "📍 Trimmed at stop word '" + stopWord + "': " + locationPart);
                        break;
                    }
                }
                
                String cleanLocation = locationPart.trim().replaceAll("[^a-zA-Z\\s]", "").trim();
                if (!cleanLocation.isEmpty()) {
                    Log.d(TAG, "📍 Final location: " + cleanLocation);
                    return cleanLocation;
                }
            }
        }
        
        // Pattern 2: "near [location]", "around [location]"
        String[] locationPatterns = {" near ", " around ", " at "};
        for (String pattern : locationPatterns) {
            if (message.contains(pattern)) {
                String[] parts = message.split(pattern);
                if (parts.length > 1) {
                    String locationPart = parts[1];
                    // Take first word or phrase before stop words
                    String[] stopWords = {" with ", " under ", " over ", " for ", " that ", " priced "};
                    for (String stopWord : stopWords) {
                        if (locationPart.contains(stopWord)) {
                            locationPart = locationPart.split(stopWord)[0];
                            break;
                        }
                    }
                    
                    String cleanLocation = locationPart.trim().replaceAll("[^a-zA-Z\\s]", "").trim();
                    if (!cleanLocation.isEmpty()) {
                        Log.d(TAG, "📍 Found '" + pattern + "' pattern, location: " + cleanLocation);
                        return cleanLocation;
                    }
                }
            }
        }
        
        // Pattern 3: Common location names as fallback
        String[] commonLocations = {"downtown", "midtown", "uptown", "city center", "city centre", "suburbs", "waterfront"};
        for (String location : commonLocations) {
            if (message.contains(location)) {
                Log.d(TAG, "📍 Found common location: " + location);
                return location;
            }
        }
        
        Log.d(TAG, "📍 No location found");
        return null;
    }
    
    private Integer extractMaxPrice(String message) {
        Log.d(TAG, "💰 Extracting max price from: " + message);
        
        // Pattern 1: "under $X", "below $X", "max $X"
        String[] maxKeywords = {"under", "below", "max", "maximum", "up to", "no more than"};
        for (String keyword : maxKeywords) {
            if (message.contains(keyword)) {
                Log.d(TAG, "💰 Found max keyword: " + keyword);
                
                // Look for price after keyword
                String[] words = message.split("\\s+");
                for (int i = 0; i < words.length; i++) {
                    if (words[i].toLowerCase().contains(keyword.replace(" ", ""))) {
                        // Check next few words for price
                        for (int j = i + 1; j < Math.min(i + 4, words.length); j++) {
                            Integer price = parsePrice(words[j]);
                            if (price != null) {
                                Log.d(TAG, "💰 Max price found: " + price);
                                return price;
                            }
                        }
                    }
                }
            }
        }
        
        // Pattern 2: "$X or less", "$X maximum", "$X max"
        if (message.contains("$")) {
            String[] words = message.split("\\s+");
            for (int i = 0; i < words.length; i++) {
                if (words[i].contains("$")) {
                    Integer price = parsePrice(words[i]);
                    if (price != null) {
                        // Check if followed by max indicators
                        if (i + 1 < words.length) {
                            String nextWord = words[i + 1].toLowerCase();
                            if (nextWord.contains("or") || nextWord.contains("max") || nextWord.contains("less")) {
                                Log.d(TAG, "💰 Max price found (with suffix): " + price);
                                return price;
                            }
                        }
                        
                        // If no min keywords present, assume it's max
                        if (!message.contains("over") && !message.contains("above") && !message.contains("minimum") && !message.contains("more than")) {
                            Log.d(TAG, "💰 Max price found (default): " + price);
                            return price;
                        }
                    }
                }
            }
        }
        
        Log.d(TAG, "💰 No max price found");
        return null;
    }
    
    private Integer extractMinPrice(String message) {
        Log.d(TAG, "💰 Extracting min price from: " + message);
        
        // Pattern 1: "over $X", "above $X", "min $X", "minimum $X"
        String[] minKeywords = {"over", "above", "min", "minimum", "more than", "at least"};
        for (String keyword : minKeywords) {
            if (message.contains(keyword)) {
                Log.d(TAG, "💰 Found min keyword: " + keyword);
                
                String[] words = message.split("\\s+");
                for (int i = 0; i < words.length; i++) {
                    if (words[i].toLowerCase().contains(keyword.replace(" ", ""))) {
                        // Check next few words for price
                        for (int j = i + 1; j < Math.min(i + 4, words.length); j++) {
                            Integer price = parsePrice(words[j]);
                            if (price != null) {
                                Log.d(TAG, "💰 Min price found: " + price);
                                return price;
                            }
                        }
                    }
                }
            }
        }
        
        // Pattern 2: "$X or more", "$X minimum"
        if (message.contains("$")) {
            String[] words = message.split("\\s+");
            for (int i = 0; i < words.length; i++) {
                if (words[i].contains("$")) {
                    Integer price = parsePrice(words[i]);
                    if (price != null) {
                        // Check if followed by min indicators
                        if (i + 1 < words.length) {
                            String nextWords = String.join(" ", java.util.Arrays.copyOfRange(words, i + 1, Math.min(i + 3, words.length)));
                            if (nextWords.contains("or more") || nextWords.contains("minimum") || nextWords.contains("plus")) {
                                Log.d(TAG, "💰 Min price found (with suffix): " + price);
                                return price;
                            }
                        }
                    }
                }
            }
        }
        
        Log.d(TAG, "💰 No min price found");
        return null;
    }
    
    private String extractPropertyType(String message) {
        // Check for property types with priority (most specific first)
        if (message.contains("studio") || message.contains("bachelor")) {
            return "studio";
        } else if (message.contains("townhouse") || message.contains("town house")) {
            return "townhouse";
        } else if (message.contains("condo") || message.contains("condominium")) {
            return "condo";
        } else if (message.contains("apartment") || message.contains("apt")) {
            return "apartment";
        } else if (message.contains("house") || message.contains("home")) {
            return "house";
        } else if (message.contains("room") || message.contains("shared")) {
            return "room";
        }
        
        return null;
    }
    
    private Integer extractBedrooms(String message) {
        // Pattern 1: "X bedroom", "X bed"
        String[] patterns = {"bedroom", "bed"};
        for (String pattern : patterns) {
            if (message.contains(pattern)) {
                String[] words = message.split("\\s+");
                for (int i = 0; i < words.length - 1; i++) {
                    if (words[i + 1].contains(pattern)) {
                        try {
                            String numStr = words[i].replaceAll("[^0-9]", "");
                            if (!numStr.isEmpty()) {
                                return Integer.parseInt(numStr);
                            }
                        } catch (NumberFormatException e) {
                            // Try text numbers
                            String numWord = words[i].toLowerCase();
                            Integer num = parseTextNumber(numWord);
                            if (num != null) {
                                return num;
                            }
                        }
                    }
                }
            }
        }
        
        // Pattern 2: "X-bedroom", "X-bed"
        if (message.contains("-bedroom") || message.contains("-bed")) {
            String[] words = message.split("\\s+");
            for (String word : words) {
                if (word.contains("-bedroom") || word.contains("-bed")) {
                    try {
                        String numStr = word.split("-")[0].replaceAll("[^0-9]", "");
                        if (!numStr.isEmpty()) {
                            return Integer.parseInt(numStr);
                        }
                    } catch (Exception e) {
                        // Continue searching
                    }
                }
            }
        }
        
        return null;
    }
    
    private Integer extractBathrooms(String message) {
        // Pattern 1: "X bathroom", "X bath"
        String[] patterns = {"bathroom", "bath"};
        for (String pattern : patterns) {
            if (message.contains(pattern)) {
                String[] words = message.split("\\s+");
                for (int i = 0; i < words.length - 1; i++) {
                    if (words[i + 1].contains(pattern)) {
                        try {
                            String numStr = words[i].replaceAll("[^0-9]", "");
                            if (!numStr.isEmpty()) {
                                return Integer.parseInt(numStr);
                            }
                        } catch (NumberFormatException e) {
                            // Try text numbers
                            String numWord = words[i].toLowerCase();
                            Integer num = parseTextNumber(numWord);
                            if (num != null) {
                                return num;
                            }
                        }
                    }
                }
            }
        }
        
        // Pattern 2: "X-bathroom", "X-bath"
        if (message.contains("-bathroom") || message.contains("-bath")) {
            String[] words = message.split("\\s+");
            for (String word : words) {
                if (word.contains("-bathroom") || word.contains("-bath")) {
                    try {
                        String numStr = word.split("-")[0].replaceAll("[^0-9]", "");
                        if (!numStr.isEmpty()) {
                            return Integer.parseInt(numStr);
                        }
                    } catch (Exception e) {
                        // Continue searching
                    }
                }
            }
        }
        
        return null;
    }
    
    private Integer parsePrice(String word) {
        try {
            // Remove all non-digit characters except commas
            String priceStr = word.replaceAll("[^0-9,]", "");
            if (!priceStr.isEmpty()) {
                // Remove commas and parse
                return Integer.parseInt(priceStr.replace(",", ""));
            }
        } catch (NumberFormatException e) {
            // Try text numbers for prices
            String lowerWord = word.toLowerCase();
            if (lowerWord.contains("thousand")) {
                String numPart = lowerWord.replace("thousand", "").replaceAll("[^0-9]", "");
                if (!numPart.isEmpty()) {
                    try {
                        return Integer.parseInt(numPart) * 1000;
                    } catch (NumberFormatException ex) {
                        return null;
                    }
                }
            }
        }
        return null;
    }
    
    private Integer parseTextNumber(String word) {
        switch (word.toLowerCase()) {
            case "one": case "1": return 1;
            case "two": case "2": return 2;
            case "three": case "3": return 3;
            case "four": case "4": return 4;
            case "five": case "5": return 5;
            case "six": case "6": return 6;
            default: return null;
        }
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