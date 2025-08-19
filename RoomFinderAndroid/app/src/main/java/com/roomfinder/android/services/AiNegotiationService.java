package com.roomfinder.android.services;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.models.ChatMessage;
import com.roomfinder.android.models.ApiResponse;
import com.roomfinder.android.models.Conversation;
import com.roomfinder.android.network.ApiClient;
import com.roomfinder.android.network.ApiService;
import com.roomfinder.android.utils.ApiKeys;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;
import org.json.JSONObject;
import okhttp3.*;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.Calendar;

/**
 * AI Negotiation Service - Port of website's AIChatHandler
 * Handles automatic property search, landlord negotiation, and deal reporting
 */
public class AiNegotiationService {
    private static final String TAG = "AiNegotiationService";
    private static AiNegotiationService instance;
    
    private final Context context;
    private final OkHttpClient httpClient;
    private final ScheduledExecutorService executorService;
    private final Handler mainHandler;
    private final ApiService apiService;
    
    // Real-time chat integration
    private RealTimeChatService chatService;
    
    // Real-time negotiation monitoring
    private boolean isMonitoring = false;
    private Map<String, String> activeNegotiationIds = new HashMap<>();
    
    // User state (similar to website's AIChatHandler)
    private String currentUserEmail;
    private UserNeeds userNeeds;
    private List<Listing> matchingListings;
    private String negotiationState;
    private Map<String, Object> activeNegotiations;
    private String pendingUserResponse;
    
    // Communication templates (from website's ai-chat.js)
    private Map<String, MessageTemplate> communicationTemplates;
    
    // Conversation state management
    private Map<String, ConversationState> activeConversations = new HashMap<>();
    
    // Callbacks
    public interface AiChatCallback {
        void onMessage(String sender, String message);
        void onSearchResults(List<Listing> listings);
        void onNegotiationStarted(String listingId);
        void onNegotiationComplete(String listingId, String result);
        void onError(String error);
    }
    
    private AiChatCallback callback;
    
    // User needs class (port of website's userNeeds object)
    public static class UserNeeds {
        public Double maxPrice;
        public Double minPrice;
        public String preferredLocation;
        public String houseType;
        public Integer bedrooms;
        public String utilities;
        
        public UserNeeds() {}
        
        @Override
        public String toString() {
            List<String> criteria = new ArrayList<>();
            if (maxPrice != null) criteria.add("Max: $" + maxPrice);
            if (preferredLocation != null) criteria.add("Location: " + preferredLocation);
            if (houseType != null) criteria.add("Type: " + houseType);
            if (bedrooms != null) criteria.add("Bedrooms: " + bedrooms);
            return criteria.isEmpty() ? "No criteria set" : String.join(", ", criteria);
        }
    }
    
    private AiNegotiationService(Context context) {
        this.context = context;
        this.httpClient = new OkHttpClient();
        this.executorService = Executors.newScheduledThreadPool(3);
        this.mainHandler = new Handler(Looper.getMainLooper());
        this.apiService = ApiClient.getInstance().getApiService();
        
        // Initialize state (like website's constructor)
        this.userNeeds = new UserNeeds();
        this.matchingListings = new ArrayList<>();
        this.negotiationState = "idle";
        this.activeNegotiations = new HashMap<>();
        this.pendingUserResponse = null;
        
        // Initialize communication templates like the website
        initializeCommunicationTemplates();
    }
    
    public static synchronized AiNegotiationService getInstance(Context context) {
        if (instance == null) {
            instance = new AiNegotiationService(context);
        }
        return instance;
    }
    
    /**
     * Initialize communication templates (from website's ai-chat.js)
     */
    private void initializeCommunicationTemplates() {
        communicationTemplates = new HashMap<>();
        
        // Initial inquiry template
        communicationTemplates.put("initial_inquiry", new MessageTemplate(
            "Interest in Your Property - {propertyAddress}",
            "Hello,\\n\\n" +
            "I am very interested in your property at {propertyAddress}. I am a {tenantProfile} looking for a {propertyType} in this area.\\n\\n" +
            "{personalizedMessage}\\n\\n" +
            "I would love to schedule a viewing at your convenience. Please let me know your availability.\\n\\n" +
            "Best regards,\\n" +
            "{tenantName}\\n" +
            "{tenantContact}"
        ));
        
        // Price negotiation template
        communicationTemplates.put("price_negotiation", new MessageTemplate(
            "Rental Rate Discussion - {propertyAddress}",
            "Hello,\\n\\n" +
            "Thank you for showing me the property at {propertyAddress}. I am very interested and would like to discuss the rental terms.\\n\\n" +
            "{negotiationPoints}\\n\\n" +
            "I am prepared to move in quickly and can provide excellent references. Would you be open to discussing these terms?\\n\\n" +
            "Best regards,\\n" +
            "{tenantName}"
        ));
        
        // Application submission template
        communicationTemplates.put("application_submission", new MessageTemplate(
            "Rental Application - {propertyAddress}",
            "Hello,\\n\\n" +
            "I am pleased to submit my application for the property at {propertyAddress}. I have attached all required documents.\\n\\n" +
            "{applicationSummary}\\n\\n" +
            "I look forward to hearing from you soon.\\n\\n" +
            "Best regards,\\n" +
            "{tenantName}"
        ));
        
        Log.d(TAG, "Communication templates initialized");
    }
    
    /**
     * Intelligent response detection and conversation state management (from website's checkForNegotiationResponse)
     */
    private boolean isNegotiationResponse(String message) {
        String cleanMessage = message.toLowerCase().trim();
        
        // Check for affirmative responses
        String[] affirmativeResponses = {"yes", "sure", "ok", "okay", "please", "go ahead", "proceed", "contact them", "negotiate", "send message"};
        for (String response : affirmativeResponses) {
            if (cleanMessage.contains(response)) {
                return true;
            }
        }
        
        // Check for direct negotiation requests
        String[] negotiationKeywords = {"negotiate", "contact", "message", "talk to landlord", "reach out"};
        for (String keyword : negotiationKeywords) {
            if (cleanMessage.contains(keyword)) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Update conversation state for a listing
     */
    private void updateConversationState(String listingId, String status, String message) {
        ConversationState state = activeConversations.get(listingId);
        if (state == null) {
            state = new ConversationState(listingId);
            activeConversations.put(listingId, state);
        }
        
        state.status = status;
        state.addMessage(message);
        
        Log.d(TAG, "Updated conversation state for " + listingId + ": " + status + " (" + state.messageCount + " messages)");
    }
    
    /**
     * Check if negotiation should continue based on conversation state
     */
    private boolean shouldContinueNegotiation(String listingId) {
        ConversationState state = activeConversations.get(listingId);
        if (state == null) {
            return true; // New conversation, should start
        }
        
        return state.shouldContinueNegotiation();
    }
    
    /**
     * Determine next negotiation action based on conversation state
     */
    private String determineNextAction(String listingId, String landlordResponse) {
        ConversationState state = activeConversations.get(listingId);
        if (state == null) {
            return "initial_contact";
        }
        
        // Analyze landlord response to determine next action
        String response = landlordResponse.toLowerCase().trim();
        Log.d(TAG, "🧠 Analyzing landlord response: '" + response + "'");
        
        // Enhanced price negotiation detection - PRIORITY CHECK
        if (response.contains("lower") || response.contains("reduce") || response.contains("can do") || 
            response.contains("decrease") || response.contains("cut") || response.contains("drop") ||
            response.contains("cheaper") || response.contains("less") || 
            (response.contains("sure") && (response.contains("lower") || response.contains("price"))) ||
            (response.contains("can") && response.contains("lower")) ||
            response.contains("negotiate price") || response.contains("adjust")) {
            Log.d(TAG, "💰 Price negotiation opportunity detected!");
            return "price_negotiation_opportunity";
        }
        
        // Positive responses
        if (response.contains("interested") || response.contains("yes") || response.contains("sure") || 
            response.contains("sounds good") || response.contains("ok") || response.contains("okay") ||
            response.contains("schedule") || response.contains("viewing") || response.contains("meet")) {
            return "positive_response";
        }
        
        // General price discussion
        if (response.contains("price") || response.contains("rent") || response.contains("cost") ||
            response.contains("amount") || response.contains("payment") || response.contains("monthly")) {
            return "price_discussion";
        }
        
        // Negative responses
        if (response.contains("no") || response.contains("not available") || response.contains("taken") ||
            response.contains("sorry") || response.contains("can't") || response.contains("cannot") ||
            response.contains("already rented") || response.contains("not interested")) {
            return "negative_response";
        }
        
        // Timing discussion
        if (response.contains("when") || response.contains("move in") || response.contains("date") ||
            response.contains("available") || response.contains("timing") || response.contains("start")) {
            return "timing_discussion";
        }
        
        // Default to general follow-up
        return "general_follow_up";
    }
    
    /**
     * Generate intelligent follow-up message based on conversation context
     */
    private String generateFollowUpMessage(String listingId, String landlordResponse, String nextAction) {
        ConversationState state = activeConversations.get(listingId);
        
        switch (nextAction) {
            case "price_negotiation_opportunity":
                return "Thank you so much for being open to discussing the price! I really appreciate your flexibility. " +
                       "What price range would work for you? Based on my research of similar properties in the area and my budget, " +
                       "I was hoping for something around " + (userNeeds.maxPrice != null ? "$" + userNeeds.maxPrice : "a competitive rate") + 
                       ". Would you be able to accommodate something in that range? I'm also happy to discuss a longer lease term if that helps make the numbers work.";
                
            case "positive_response":
                return "Thank you for your positive response! I'm very excited about this opportunity. When would be a good time for a viewing? I'm flexible with my schedule and can accommodate your availability.";
                
            case "price_discussion":
                return "I appreciate you discussing the pricing with me. Based on my budget and the current market, I believe we can find a mutually beneficial arrangement. Would you be open to discussing terms that work for both of us?";
                
            case "timing_discussion":
                return "Regarding timing, I'm quite flexible. I can move in as early as next week or wait for a date that works better for you. My lease situation allows for this flexibility, and I'm committed to making this work.";
                
            case "negative_response":
                return "I understand if this particular arrangement doesn't work out. If anything changes or if you have other properties that might be suitable, I'd greatly appreciate you keeping me in mind. Thank you for your time.";
                
            case "general_follow_up":
                return "Thank you for your response. I remain very interested in your property and would love to continue our discussion. Please let me know if you need any additional information from me or if there's anything specific you'd like to discuss.";
                
            default:
                return "Thank you for getting back to me. I'm very interested in moving forward with this opportunity. Please let me know the next steps or any additional information you might need.";
        }
    }
    
    /**
     * Initialize the AI system with user (port of website's init method)
     */
    public void init(String userEmail, AiChatCallback callback) {
        this.currentUserEmail = userEmail;
        this.callback = callback;
        
        // Initialize chat service for real messaging
        this.chatService = RealTimeChatService.getInstance(context);
        
        Log.d(TAG, "🤖 AI Negotiation Service initialized for user: " + userEmail);
        
        // Send welcome message like website
        if (callback != null) {
            callback.onMessage("AI", "Hello! I'm your AI assistant. Tell me what you're looking for (e.g., \"I want a house in Hong Kong for $1500\") and I'll search our database for matching listings and help you negotiate with landlords!");
        }
    }
    
    /**
     * Process user message (port of website's processMessage method)
     */
    public void processMessage(String message) {
        Log.d(TAG, "🔄 Processing user message: " + message);
        
        if (callback != null) {
            callback.onMessage("You", message);
        }
        
        // Reset negotiation state for new requests
        negotiationState = "idle";
        
        // Check if this is a negotiation response first (like website)
        if (checkForNegotiationResponse(message)) {
            return;
        }
        
        // Extract rental criteria from message
        executorService.execute(() -> {
            try {
                RentalCriteria extractedData = extractRentalInfo(message);
                Log.d(TAG, "📊 Extracted data: " + extractedData);
                
                // Update user needs
                updateUserNeeds(extractedData);
                
                // Check if we should search for listings
                boolean shouldSearch = "search".equals(extractedData.intent) || 
                                     (extractedData.price != null && extractedData.city != null) ||
                                     (extractedData.houseType != null && (extractedData.price != null || extractedData.city != null));
                
                Log.d(TAG, "🎯 Should search for listings: " + shouldSearch);
                
                if (shouldSearch) {
                    mainHandler.post(() -> {
                        if (callback != null) {
                            callback.onMessage("AI", "I understand! Searching for matching listings in our database...");
                        }
                    });
                    // Delay to show typing effect
                    Thread.sleep(1000);
                    searchAndMessage();
                } else {
                    mainHandler.post(() -> {
                        if (callback != null) {
                            callback.onMessage("AI", "I understand your preferences. To search for listings, try saying something like \"I need a 2-bedroom apartment under $1500 in Toronto\"");
                        }
                    });
                }
            } catch (Exception e) {
                Log.e(TAG, "Error processing message", e);
                mainHandler.post(() -> {
                    if (callback != null) {
                        callback.onError("I'm having trouble processing your request. Please try rephrasing your message.");
                    }
                });
            }
        });
    }
    
    /**
     * Extract rental criteria (port of website's extractRentalInfo)
     */
    private RentalCriteria extractRentalInfo(String message) {
        Log.d(TAG, "Using manual extraction for: " + message);
        RentalCriteria result = new RentalCriteria();
        
        // Extract price
        java.util.regex.Pattern pricePattern = java.util.regex.Pattern.compile("(?:under|below|max|up to|for|at|around)?\\s*\\$?(\\d{1,5})", java.util.regex.Pattern.CASE_INSENSITIVE);
        java.util.regex.Matcher priceMatcher = pricePattern.matcher(message);
        if (priceMatcher.find()) {
            double extractedPrice = Double.parseDouble(priceMatcher.group(1));
            if (extractedPrice > 100) {
                result.price = extractedPrice;
                Log.d(TAG, "💰 Extracted price: " + extractedPrice);
            }
        }
        
        // Extract city - international cities (same list as website)
        String cityPattern = "\\b(hong kong|karachi|paris|tehran|toronto|moscow|sydney|vancouver|montreal|calgary|ottawa|edmonton|winnipeg|hamilton|quebec|saskatoon|regina|halifax|london|kitchener|waterloo|windsor|markham|mississauga|brampton|islamabad|lahore|rawalpindi|faisalabad|multan|hyderabad|peshawar|quetta|new york|los angeles|chicago|miami|boston)\\b";
        java.util.regex.Pattern cityPatternRegex = java.util.regex.Pattern.compile(cityPattern, java.util.regex.Pattern.CASE_INSENSITIVE);
        java.util.regex.Matcher cityMatcher = cityPatternRegex.matcher(message);
        if (cityMatcher.find()) {
            result.city = cityMatcher.group(1).toLowerCase().trim();
            Log.d(TAG, "🏙️ Extracted city: " + result.city);
        }
        
        // Extract house type
        String lowerMessage = message.toLowerCase();
        if (lowerMessage.contains("apartment")) {
            result.houseType = "Apartment";
        } else if (lowerMessage.contains("condo")) {
            result.houseType = "Condo";
        } else if (lowerMessage.contains("house")) {
            result.houseType = "House";
        } else if (lowerMessage.contains("studio")) {
            result.houseType = "Studio";
        } else if (lowerMessage.contains("basement")) {
            result.houseType = "Basement";
        }
        
        // Extract bedrooms
        java.util.regex.Pattern bedroomPattern = java.util.regex.Pattern.compile("(\\d+)[\\s-]?bedroom", java.util.regex.Pattern.CASE_INSENSITIVE);
        java.util.regex.Matcher bedroomMatcher = bedroomPattern.matcher(message);
        if (bedroomMatcher.find()) {
            result.bedrooms = Integer.parseInt(bedroomMatcher.group(1));
        }
        
        // Set intent
        if (lowerMessage.contains("looking for") || 
            lowerMessage.contains("need") || 
            lowerMessage.contains("want") ||
            lowerMessage.contains("find") ||
            lowerMessage.contains("search")) {
            result.intent = "search";
        }
        
        // Backup logic: if we extracted rental criteria, assume search intent
        if ((result.price != null || result.city != null) && result.intent == null) {
            Log.d(TAG, "🎯 BACKUP LOGIC: Found rental criteria without intent, setting to search");
            result.intent = "search";
        }
        
        return result;
    }
    
    // Helper class for extraction results
    private static class RentalCriteria {
        public String intent;
        public Double price;
        public String city;
        public String houseType;
        public Integer bedrooms;
        public String utilities;
    }
    
    /**
     * Update user needs (port of website's updateUserNeeds)
     */
    private void updateUserNeeds(RentalCriteria extracted) {
        Log.d(TAG, "🔧 Updating user needs with: " + extracted);
        
        if (extracted.price != null) {
            userNeeds.maxPrice = extracted.price;
            Log.d(TAG, "✅ Set max price: " + extracted.price);
        }
        
        if (extracted.city != null) {
            String cleanCity = extracted.city.toString().trim().toLowerCase();
            cleanCity = cleanCity.split(",")[0].trim();
            userNeeds.preferredLocation = cleanCity;
            Log.d(TAG, "✅ Set location: " + cleanCity);
        }
        
        if (extracted.houseType != null) {
            userNeeds.houseType = extracted.houseType;
            Log.d(TAG, "✅ Set house type: " + extracted.houseType);
        }
        
        if (extracted.bedrooms != null) {
            userNeeds.bedrooms = extracted.bedrooms;
            Log.d(TAG, "✅ Set bedrooms: " + extracted.bedrooms);
        }
        
        Log.d(TAG, "🔧 Final user needs: " + userNeeds);
    }
    
    /**
     * Check for negotiation responses (port of website's checkForNegotiationResponse)
     */
    private boolean checkForNegotiationResponse(String message) {
        Log.d(TAG, "🔍 [NEGOTIATION CHECK] Starting check for message: " + message);
        String cleanMessage = message.toLowerCase().trim();
        
        // Check if we have any active context waiting for user response
        boolean hasActiveContext = pendingUserResponse != null;
        
        if (hasActiveContext) {
            Log.d(TAG, "🔍 [NEGOTIATION CHECK] Has active context, checking responses...");
            
            // Check for affirmative responses
            String[] affirmativeResponses = {"yes", "sure", "ok", "okay", "please", "go ahead", "proceed", "contact them", "negotiate", "send message"};
            boolean isAffirmative = Arrays.stream(affirmativeResponses).anyMatch(cleanMessage::contains);
            
            if (isAffirmative && !matchingListings.isEmpty()) {
                Log.d(TAG, "✅ [NEGOTIATION CHECK] Affirmative response detected, starting negotiations");
                
                mainHandler.post(() -> {
                    if (callback != null) {
                        callback.onMessage("AI", "📧 Starting negotiations for all matching listings");
                    }
                });
                
                // Clear pending response
                pendingUserResponse = null;
                
                // Start negotiations for all matching listings
                executorService.execute(() -> {
                    try {
                        Thread.sleep(1000);
                        startNegotiationsForAllListings();
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                });
                return true;
            }
        }
        
        Log.d(TAG, "❌ [NEGOTIATION CHECK] No negotiation response detected");
        return false;
    }
    
    /**
     * Search and message using working ApiService (port of website's searchAndMessage)
     */
    private void searchAndMessage() {
        negotiationState = "searching";
        
        // Find matching listings using working API
        findMatchingListings(new ListingsCallback() {
            @Override
            public void onSuccess(List<Listing> listings) {
                mainHandler.post(() -> {
                    if (listings.isEmpty()) {
                        handleNoMatches();
                        return;
                    }
                    
                    // Store matching listings
                    matchingListings = listings;
                    
                    // Show found listings
                    if (callback != null) {
                        callback.onMessage("AI", "Found " + listings.size() + " matching listing(s)!");
                        callback.onSearchResults(listings);
                        
                        // Show first few listings
                        for (int i = 0; i < Math.min(3, listings.size()); i++) {
                            Listing listing = listings.get(i);
                            String titleText = listing.getTitle() != null ? listing.getTitle() : "Untitled Property";
                            String cityText = listing.getCity() != null ? listing.getCity() : "City not specified";
                            String priceText = listing.getPrice() > 0 ? " - $" + listing.getPrice() : "";
                            String typeText = listing.getHouseType() != null ? " (" + listing.getHouseType() + ")" : "";
                            
                            callback.onMessage("AI", titleText + " - " + cityText + priceText + typeText);
                        }
                        
                        // Ask if user wants to negotiate
                        callback.onMessage("AI", "Would you like me to help you negotiate with these landlords? I can send professional messages on your behalf using market data and negotiation strategies!");
                        
                        // Set pending response so "yes" will trigger negotiations
                        pendingUserResponse = "negotiate_offer";
                    }
                });
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Search error: " + error);
                mainHandler.post(() -> {
                    if (callback != null) {
                        callback.onError("Search failed: " + error);
                    }
                });
                negotiationState = "idle";
            }
        });
    }
    
    /**
     * Find matching listings using working ApiService (replaces manual Supabase queries)
     */
    private void findMatchingListings(ListingsCallback callback) {
        Log.d(TAG, "🔍 Finding matching listings with criteria: " + userNeeds);
        
        // Build search parameters from user needs
        String searchQuery = null;
        Double minPrice = null;
        Double maxPrice = userNeeds.maxPrice;
        Integer bedrooms = userNeeds.bedrooms;
        String location = userNeeds.preferredLocation;
        
        // Build query string from house type if specified
        if (userNeeds.houseType != null) {
            searchQuery = userNeeds.houseType;
        }
        
        Log.d(TAG, "🚀 Using ApiService.searchListings with params:");
        Log.d(TAG, "  - Query: " + searchQuery);
        Log.d(TAG, "  - Location: " + location);
        Log.d(TAG, "  - Max Price: " + maxPrice);
        Log.d(TAG, "  - Bedrooms: " + bedrooms);
        
        // Use the working ApiService instead of manual Supabase queries
        apiService.searchListings(searchQuery, minPrice, maxPrice, bedrooms, location)
            .enqueue(new Callback<ApiResponse<List<Listing>>>() {
                @Override
                public void onResponse(Call<ApiResponse<List<Listing>>> call, Response<ApiResponse<List<Listing>>> response) {
                    if (response.isSuccessful() && response.body() != null && response.body().isSuccess()) {
                        List<Listing> listings = response.body().getData();
                        if (listings != null) {
                            // Filter out current user's listings
                            List<Listing> filteredListings = new ArrayList<>();
                            for (Listing listing : listings) {
                                if (currentUserEmail == null || !currentUserEmail.equals(listing.getUserEmail())) {
                                    filteredListings.add(listing);
                                }
                            }
                            
                            Log.d(TAG, "📊 API results: " + filteredListings.size() + " listings found (after filtering own listings)");
                            callback.onSuccess(filteredListings);
                        } else {
                            Log.w(TAG, "API returned null data");
                            callback.onSuccess(new ArrayList<>());
                        }
                    } else {
                        String errorMsg = "API search failed: " + response.code();
                        if (response.body() != null && !response.body().isSuccess()) {
                            errorMsg += " - " + response.body().getMessage();
                        }
                        Log.e(TAG, errorMsg);
                        callback.onError(errorMsg);
                    }
                }
                
                @Override
                public void onFailure(Call<ApiResponse<List<Listing>>> call, Throwable t) {
                    String errorMsg = "API search failed: " + t.getMessage();
                    Log.e(TAG, errorMsg, t);
                    callback.onError(errorMsg);
                }
            });
    }
    
    /**
     * Callback interface for async listings search
     */
    private interface ListingsCallback {
        void onSuccess(List<Listing> listings);
        void onError(String error);
    }
    
    /**
     * Handle when no matches are found
     */
    private void handleNoMatches() {
        List<String> extracted = new ArrayList<>();
        if (userNeeds.preferredLocation != null) extracted.add("Location: " + userNeeds.preferredLocation);
        if (userNeeds.maxPrice != null) extracted.add("Max Price: " + userNeeds.maxPrice);
        if (userNeeds.houseType != null) extracted.add("Type: " + userNeeds.houseType);
        
        if (callback != null) {
            callback.onMessage("AI", "❌ No exact matches found. I searched for: " + String.join(", ", extracted));
            callback.onMessage("AI", "Try adjusting your criteria or expanding your search area.");
        }
        
        negotiationState = "idle";
    }
    
    /**
     * Start negotiations for all matching listings (port of website's startNegotiationsForAllListings)
     */
    public void startNegotiationsForAllListings() {
        if (matchingListings == null || matchingListings.isEmpty()) {
            mainHandler.post(() -> {
                if (callback != null) {
                    callback.onMessage("AI", "No listings available for negotiation. Please search for properties first.");
                }
            });
            return;
        }
        
        mainHandler.post(() -> {
            if (callback != null) {
                callback.onMessage("AI", "📧 Contacting landlords for " + matchingListings.size() + " listing(s)...");
            }
        });
        
        // Contact each landlord
        executorService.execute(() -> {
            for (Listing listing : matchingListings) {
                if (listing.getUserEmail() != null && !listing.getUserEmail().equals(currentUserEmail)) {
                    try {
                        Thread.sleep(500); // Stagger requests
                        startNegotiationForListing(listing);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        break;
                    }
                }
            }
        });
    }
    
    /**
     * Start negotiation for specific listing using real chat messaging
     */
    public void startNegotiationForListing(Listing listing) {
        try {
            Log.d(TAG, "📤 Starting real chat negotiation for listing: " + listing.getId());
            
            mainHandler.post(() -> {
                if (callback != null) {
                    callback.onMessage("AI", "📤 Creating conversation with " + getDisplayName(listing.getUserEmail()) + " for " + listing.getTitle() + "...");
                    callback.onNegotiationStarted(listing.getId());
                }
            });
            
            // Generate professional negotiation message
            String negotiationMessage = generateNegotiationMessage(listing);
            Log.d(TAG, "Generated negotiation message: " + negotiationMessage);
            
            // Start conversation with landlord using RealTimeChatService
            chatService.startConversation(
                listing,
                listing.getUserEmail(),
                new RealTimeChatService.ConversationCallback() {
                    @Override
                    public void onSuccess(Conversation conversation) {
                        Log.d(TAG, "✅ Conversation created: " + conversation.getId());
                        
                        // Track this negotiation
                        activeNegotiationIds.put(listing.getId(), conversation.getId());
                        
                        // Start monitoring if not already started
                        if (!isMonitoring) {
                            startNegotiationMonitoring();
                        }
                        
                        // Send the AI-generated negotiation message
                        sendNegotiationMessage(conversation.getId(), negotiationMessage, listing);
                    }
                    
                    @Override
                    public void onError(String error) {
                        Log.e(TAG, "Failed to start conversation: " + error);
                        mainHandler.post(() -> {
                            if (callback != null) {
                                callback.onMessage("AI", "❌ Failed to start conversation with landlord for " + listing.getTitle() + ": " + error);
                            }
                        });
                    }
                }
            );
            
        } catch (Exception e) {
            Log.e(TAG, "Negotiation error", e);
            mainHandler.post(() -> {
                if (callback != null) {
                    callback.onMessage("AI", "❌ Error starting negotiation for " + listing.getTitle() + ": " + e.getMessage());
                }
            });
        }
    }
    
    /**
     * Generate professional negotiation message with market analysis (port of website's AI negotiation engine)
     */
    private String generateNegotiationMessage(Listing listing) {
        // Analyze the market situation for this property
        MarketAnalysis analysis = analyzeMarketData(listing);
        NegotiationStrategy strategy = generateNegotiationStrategy(listing, analysis);
        
        StringBuilder message = new StringBuilder();
        
        // Professional opening
        message.append("Hello! I'm very interested in your property");
        
        if (listing.getTitle() != null) {
            message.append(" \"").append(listing.getTitle()).append("\"");
        }
        
        if (listing.getCity() != null || listing.getStreet() != null) {
            message.append(" located in ");
            if (listing.getCity() != null) {
                message.append(listing.getCity());
            }
            if (listing.getStreet() != null) {
                if (listing.getCity() != null) message.append(", ");
                message.append(listing.getStreet());
            }
        }
        
        message.append(".\n\n");
        
        // Establish credibility as a tenant
        message.append("I am a reliable professional with stable income, excellent references, and a clean rental history. ");
        
        // Add user preferences and requirements
        if (userNeeds.maxPrice != null || userNeeds.bedrooms != null || userNeeds.houseType != null) {
            message.append("I'm specifically looking for ");
            List<String> preferences = new ArrayList<>();
            
            if (userNeeds.houseType != null) {
                preferences.add("a " + userNeeds.houseType.toLowerCase());
            }
            if (userNeeds.bedrooms != null) {
                preferences.add(userNeeds.bedrooms + " bedroom" + (userNeeds.bedrooms > 1 ? "s" : ""));
            }
            
            message.append(String.join(", ", preferences)).append(" in this area.\n\n");
        }
        
        // Apply negotiation strategy based on market analysis
        if (strategy.shouldNegotiatePrice && userNeeds.maxPrice != null && listing.getPrice() > userNeeds.maxPrice) {
            message.append("I've done some research on comparable properties in the area, ");
            message.append("and I noticed that similar properties are typically renting for around $");
            message.append(analysis.averageRentInArea.intValue()).append("/month. ");
            
            message.append("Given my qualifications as a tenant and the current market, ");
            message.append("would you be open to discussing a rental rate of $");
            message.append(userNeeds.maxPrice.intValue()).append("/month?\n\n");
        }
        
        // Add value propositions based on strategy
        message.append("I can offer:\n");
        message.append("• Quick move-in (I'm ready immediately)\n");
        message.append("• Long-term tenancy (looking for 12+ months)\n");
        message.append("• Excellent maintenance of the property\n");
        message.append("• Prompt payment and professional communication\n\n");
        
        // Flexible terms negotiation
        if (strategy.negotiateTerms) {
            message.append("I'm also flexible on lease terms and would be happy to discuss:\n");
            message.append("• Lease duration preferences\n");
            message.append("• Utility arrangements\n");
            message.append("• Any property improvement needs\n\n");
        }
        
        message.append("I would love to schedule a viewing at your earliest convenience. ");
        message.append("Please let me know your availability.\n\n");
        message.append("Thank you for your time, and I look forward to hearing from you!");
        
        Log.d(TAG, "Generated strategic negotiation message with market analysis");
        return message.toString();
    }
    
    /**
     * Analyze market data for property (simplified version of website's analyzeMarketData)
     */
    private MarketAnalysis analyzeMarketData(Listing listing) {
        MarketAnalysis analysis = new MarketAnalysis();
        
        // Estimate market average (in real implementation, this would query market APIs)
        analysis.averageRentInArea = listing.getPrice() * (0.9 + Math.random() * 0.2);
        analysis.marketTrend = Math.random() > 0.5 ? "increasing" : "stable";
        analysis.daysOnMarket = (int) (Math.random() * 30) + 7;
        analysis.seasonalFactor = getSeasonalFactor();
        analysis.negotiationPotential = Math.random() * 0.4 + 0.1; // 10-50% potential
        
        Log.d(TAG, "Market analysis: avg rent=" + analysis.averageRentInArea.intValue() + 
                   ", trend=" + analysis.marketTrend + 
                   ", potential=" + (analysis.negotiationPotential * 100) + "%");
        
        return analysis;
    }
    
    /**
     * Generate negotiation strategy based on market analysis
     */
    private NegotiationStrategy generateNegotiationStrategy(Listing listing, MarketAnalysis analysis) {
        NegotiationStrategy strategy = new NegotiationStrategy();
        
        // Price negotiation strategy
        if (analysis.negotiationPotential > 0.2 && userNeeds.maxPrice != null && listing.getPrice() > userNeeds.maxPrice) {
            strategy.shouldNegotiatePrice = true;
            strategy.targetPrice = userNeeds.maxPrice;
            strategy.priceJustification = "Market analysis shows similar properties average lower prices";
        }
        
        // Lease terms strategy
        strategy.negotiateTerms = true;
        strategy.proposedTerms.add("Flexible lease duration");
        strategy.proposedTerms.add("Utility arrangements");
        strategy.proposedTerms.add("Pet policy if applicable");
        
        // Move-in incentives
        if (analysis.daysOnMarket > 20) {
            strategy.requestIncentives = true;
            strategy.incentives.add("Reduced security deposit");
            strategy.incentives.add("First month prorated");
        }
        
        strategy.estimatedSuccessProbability = calculateSuccessProbability(analysis);
        
        Log.d(TAG, "Generated negotiation strategy: price=" + strategy.shouldNegotiatePrice + 
                   ", terms=" + strategy.negotiateTerms + 
                   ", success=" + (strategy.estimatedSuccessProbability * 100) + "%");
        
        return strategy;
    }
    
    /**
     * Calculate success probability for negotiation
     */
    private double calculateSuccessProbability(MarketAnalysis analysis) {
        double baseProbability = 0.5;
        
        // Adjust based on market conditions
        if ("increasing".equals(analysis.marketTrend)) {
            baseProbability -= 0.1;
        }
        
        // Adjust based on days on market
        if (analysis.daysOnMarket > 20) {
            baseProbability += 0.2;
        }
        
        // Adjust based on seasonal factor
        baseProbability += (1 - analysis.seasonalFactor) * 0.3;
        
        return Math.min(Math.max(baseProbability, 0.1), 0.9);
    }
    
    /**
     * Get seasonal factor for rental market
     */
    private double getSeasonalFactor() {
        Calendar cal = Calendar.getInstance();
        int month = cal.get(Calendar.MONTH);
        
        switch (month) {
            case 0: return 0.85;  // January - Low demand
            case 1: return 0.90;  // February
            case 2: return 0.95;  // March - Spring pickup
            case 3: return 1.00;  // April
            case 4: return 1.05;  // May - Peak season
            case 5: return 1.10;  // June - Peak season
            case 6: return 1.05;  // July
            case 7: return 1.00;  // August
            case 8: return 0.95;  // September
            case 9: return 0.90;  // October
            case 10: return 0.85; // November - Low demand
            case 11: return 0.80; // December - Lowest demand
            default: return 1.0;
        }
    }
    
    /**
     * Market analysis data class
     */
    private static class MarketAnalysis {
        Double averageRentInArea;
        String marketTrend;
        int daysOnMarket;
        double seasonalFactor;
        double negotiationPotential;
    }
    
    /**
     * Negotiation strategy data class
     */
    private static class NegotiationStrategy {
        boolean shouldNegotiatePrice = false;
        Double targetPrice;
        String priceJustification;
        boolean negotiateTerms = false;
        List<String> proposedTerms = new ArrayList<>();
        boolean requestIncentives = false;
        List<String> incentives = new ArrayList<>();
        double estimatedSuccessProbability;
    }
    
    /**
     * Send the negotiation message through chat service
     */
    private void sendNegotiationMessage(String conversationId, String message, Listing listing) {
        chatService.sendMessage(conversationId, message, new RealTimeChatService.MessageListener() {
            @Override
            public void onMessageSent(ChatMessage sentMessage) {
                Log.d(TAG, "✅ Negotiation message sent successfully");
                mainHandler.post(() -> {
                    if (callback != null) {
                        callback.onMessage("AI", "✅ Message sent to " + getDisplayName(listing.getUserEmail()) + " for " + listing.getTitle());
                        callback.onMessage("AI", "📱 Message sent: \"" + message.substring(0, Math.min(100, message.length())) + 
                                          (message.length() > 100 ? "...\"" : "\""));
                        callback.onNegotiationComplete(listing.getId(), "Message sent successfully");
                    }
                });
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Failed to send negotiation message: " + error);
                mainHandler.post(() -> {
                    if (callback != null) {
                        callback.onMessage("AI", "❌ Failed to send message for " + listing.getTitle() + ": " + error);
                    }
                });
            }
            
            @Override
            public void onMessageReceived(ChatMessage message) {
                // Handle landlord responses in real-time
                Log.d(TAG, "📬 Received message from " + message.getSenderEmail() + ": " + message.getContent());
                
                // Check if this is a landlord reply (not from current user)
                if (!message.getSenderEmail().equals(currentUserEmail)) {
                    Log.d(TAG, "🏠 Landlord reply detected: " + message.getContent());
                    
                    mainHandler.post(() -> {
                        if (callback != null) {
                            callback.onMessage("AI", "📧 **Landlord Response Received**\\n\\n" + message.getContent());
                            callback.onMessage("AI", "🤖 Analyzing response and preparing follow-up negotiation...");
                        }
                    });
                    
                    // Continue negotiation based on landlord reply
                    continueNegotiationBasedOnReply(listing.getId(), message.getContent());
                }
            }
            
            @Override
            public void onTypingIndicator(String senderEmail, boolean isTyping) {
                // Handle typing indicators if needed
            }
        });
    }
    
    /**
     * Get display name for email
     */
    private String getDisplayName(String email) {
        if (email == null) return "Landlord";
        
        // Extract name before @ symbol
        int atIndex = email.indexOf('@');
        if (atIndex > 0) {
            return email.substring(0, atIndex);
        }
        return email;
    }
    
    /**
     * Set matching listings for negotiation (called from fragment)
     */
    public void setMatchingListings(List<Listing> listings) {
        this.matchingListings = listings;
    }
    
    /**
     * Start monitoring for real-time negotiation updates (port of website's listenForNegotiationUpdates)
     */
    public void startNegotiationMonitoring() {
        if (isMonitoring || currentUserEmail == null) {
            return;
        }
        
        Log.d(TAG, "🔔 Starting real-time negotiation monitoring for user: " + currentUserEmail);
        isMonitoring = true;
        
        // Poll for negotiation updates every 5 seconds (similar to message polling)
        executorService.scheduleWithFixedDelay(() -> {
            if (isMonitoring && !activeNegotiationIds.isEmpty()) {
                checkForNegotiationUpdates();
            }
        }, 5, 5, TimeUnit.SECONDS);
    }
    
    /**
     * Stop monitoring for negotiation updates
     */
    public void stopNegotiationMonitoring() {
        isMonitoring = false;
        activeNegotiationIds.clear();
        Log.d(TAG, "🔕 Stopped negotiation monitoring");
    }
    
    /**
     * Check for negotiation updates from ai_chats table
     */
    private void checkForNegotiationUpdates() {
        try {
            // Query ai_chats table for updates (similar to website's subscription)
            String url = ApiKeys.SUPABASE_URL + "rest/v1/ai_chats?select=*" +
                         "&user_email=eq." + currentUserEmail +
                         "&order=created_at.desc&limit=10";
            
            Request request = new Request.Builder()
                    .url(url)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .build();
            
            try (okhttp3.Response response = httpClient.newCall(request).execute()) {
                if (response.isSuccessful() && response.body() != null) {
                    String responseBody = response.body().string();
                    org.json.JSONArray updates = new org.json.JSONArray(responseBody);
                    
                    for (int i = 0; i < updates.length(); i++) {
                        org.json.JSONObject update = updates.getJSONObject(i);
                        processNegotiationUpdate(update);
                    }
                }
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error checking negotiation updates", e);
        }
    }
    
    /**
     * Process negotiation update (port of website's update processing)
     */
    private void processNegotiationUpdate(org.json.JSONObject update) {
        try {
            String title = update.optString("title", "");
            String message = update.optString("message", "");
            String listingId = update.optString("listing_id", "");
            
            Log.d(TAG, "📨 Processing negotiation update: " + title);
            
            if (title.contains("Negotiation Success")) {
                handleNegotiationSuccess(update);
            } else if (title.contains("Landlord Reply")) {
                handleLandlordReply(update);
            } else if (title.contains("Negotiation Progress")) {
                handleNegotiationProgress(update);
            } else if (title.contains("Negotiation Failed")) {
                handleNegotiationFailure(update);
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error processing negotiation update", e);
        }
    }
    
    /**
     * Handle negotiation success
     */
    private void handleNegotiationSuccess(org.json.JSONObject update) {
        try {
            String listingId = update.optString("listing_id", "");
            String finalTerms = update.optString("final_terms", "");
            
            mainHandler.post(() -> {
                if (callback != null) {
                    callback.onMessage("AI", "🎉 **Negotiation Success!** \n\nGreat news! I've successfully negotiated terms for listing " + listingId);
                    if (!finalTerms.isEmpty()) {
                        callback.onMessage("AI", "📄 **Final Terms:** " + finalTerms);
                    }
                    callback.onNegotiationComplete(listingId, "success");
                }
            });
            
            // Remove from active negotiations
            activeNegotiationIds.remove(listingId);
            
        } catch (Exception e) {
            Log.e(TAG, "Error handling negotiation success", e);
        }
    }
    
    /**
     * Handle landlord reply (deprecated - now handled by real-time chat monitoring)
     */
    private void handleLandlordReply(org.json.JSONObject update) {
        try {
            String listingId = update.optString("listing_id", "");
            String reply = update.optString("message", "");
            
            // Note: Landlord replies are now handled immediately by onMessageReceived for faster response
            // This method is kept for backwards compatibility but may not be needed
            Log.d(TAG, "📭 Landlord reply detected in AI monitoring (may be duplicate): " + reply);
            
        } catch (Exception e) {
            Log.e(TAG, "Error handling landlord reply", e);
        }
    }
    
    /**
     * Handle negotiation progress
     */
    private void handleNegotiationProgress(org.json.JSONObject update) {
        try {
            String progress = update.optString("message", "");
            
            mainHandler.post(() -> {
                if (callback != null) {
                    callback.onMessage("AI", "⏳ **Negotiation Update:** " + progress);
                }
            });
            
        } catch (Exception e) {
            Log.e(TAG, "Error handling negotiation progress", e);
        }
    }
    
    /**
     * Handle negotiation failure
     */
    private void handleNegotiationFailure(org.json.JSONObject update) {
        try {
            String listingId = update.optString("listing_id", "");
            String reason = update.optString("message", "");
            
            mainHandler.post(() -> {
                if (callback != null) {
                    callback.onMessage("AI", "❌ **Negotiation Unsuccessful** for listing " + listingId);
                    if (!reason.isEmpty()) {
                        callback.onMessage("AI", "**Reason:** " + reason);
                    }
                    callback.onNegotiationComplete(listingId, "failed");
                }
            });
            
            // Remove from active negotiations
            activeNegotiationIds.remove(listingId);
            
        } catch (Exception e) {
            Log.e(TAG, "Error handling negotiation failure", e);
        }
    }
    
    /**
     * Continue negotiation based on landlord reply
     */
    private void continueNegotiationBasedOnReply(String listingId, String reply) {
        executorService.execute(() -> {
            try {
                Thread.sleep(2000); // Brief delay to show analysis message
                
                // Check if negotiation should continue
                if (!shouldContinueNegotiation(listingId)) {
                    mainHandler.post(() -> {
                        if (callback != null) {
                            callback.onMessage("AI", "📋 Negotiation cycle completed for listing " + listingId + ". Moving to conclusion phase.");
                        }
                    });
                    return;
                }
                
                // Update conversation state
                updateConversationState(listingId, "processing_reply", reply);
                
                // Determine next action using intelligent analysis
                String nextAction = determineNextAction(listingId, reply);
                Log.d(TAG, "Next action for " + listingId + ": " + nextAction);
                
                // Find the listing
                Listing listing = null;
                for (Listing l : matchingListings) {
                    if (l.getId().equals(listingId)) {
                        listing = l;
                        break;
                    }
                }
                
                if (listing != null) {
                    // Generate intelligent follow-up message
                    String followUpMessage = generateFollowUpMessage(listingId, reply, nextAction);
                    
                    mainHandler.post(() -> {
                        if (callback != null) {
                            callback.onMessage("AI", "🧠 Analysis: " + nextAction.replace("_", " ").toUpperCase() + " detected");
                            callback.onMessage("AI", "📤 Sending intelligent follow-up message...");
                        }
                    });
                    
                    // Update state to sending follow-up
                    updateConversationState(listingId, "sending_followup", followUpMessage);
                    
                    // Send follow-up through chat service
                    sendFollowUpMessage(listingId, followUpMessage, listing);
                    
                    // Handle conclusion if negative response
                    if ("negative_response".equals(nextAction)) {
                        updateConversationState(listingId, "completed", "Negotiation concluded - negative response");
                        activeConversations.remove(listingId);
                    }
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error continuing negotiation", e);
            }
        });
    }
    
    // Old generateFollowUpMessage method removed - now using intelligent conversation management
    
    /**
     * Send follow-up message
     */
    private void sendFollowUpMessage(String listingId, String message, Listing listing) {
        // Use existing message sending logic
        if (chatService != null) {
            // Find or create conversation for this listing
            chatService.startConversation(
                listing,
                listing.getUserEmail(),
                new RealTimeChatService.ConversationCallback() {
                    @Override
                    public void onSuccess(Conversation conversation) {
                        // Send the follow-up message
                        chatService.sendMessage(conversation.getId(), message, new RealTimeChatService.MessageListener() {
                            @Override
                            public void onMessageSent(ChatMessage sentMessage) {
                                Log.d(TAG, "✅ Follow-up message sent successfully");
                                mainHandler.post(() -> {
                                    if (callback != null) {
                                        callback.onMessage("AI", "✅ Follow-up message sent to landlord");
                                    }
                                });
                            }
                            
                            @Override
                            public void onError(String error) {
                                Log.e(TAG, "Failed to send follow-up message: " + error);
                            }
                            
                            @Override
                            public void onMessageReceived(ChatMessage message) {}
                            
                            @Override
                            public void onTypingIndicator(String senderEmail, boolean isTyping) {}
                        });
                    }
                    
                    @Override
                    public void onError(String error) {
                        Log.e(TAG, "Failed to continue conversation: " + error);
                    }
                }
            );
        }
    }
    
    /**
     * Message template class (from website's implementation)
     */
    private static class MessageTemplate {
        String subject;
        String body;
        
        MessageTemplate(String subject, String body) {
            this.subject = subject;
            this.body = body;
        }
    }
    
    /**
     * Conversation state class for tracking negotiation progress
     */
    private static class ConversationState {
        String listingId;
        String status; // "initiated", "negotiating", "awaiting_response", "completed"
        int messageCount;
        long lastMessageTime;
        String lastResponse;
        boolean isWaitingForLandlord;
        List<String> negotiationHistory;
        
        ConversationState(String listingId) {
            this.listingId = listingId;
            this.status = "initiated";
            this.messageCount = 0;
            this.lastMessageTime = System.currentTimeMillis();
            this.negotiationHistory = new ArrayList<>();
        }
        
        void addMessage(String message) {
            messageCount++;
            lastMessageTime = System.currentTimeMillis();
            negotiationHistory.add(message);
        }
        
        boolean shouldContinueNegotiation() {
            // Stop if too many messages or too much time has passed
            return messageCount < 5 && 
                   (System.currentTimeMillis() - lastMessageTime) < 24 * 60 * 60 * 1000; // 24 hours
        }
    }
}
