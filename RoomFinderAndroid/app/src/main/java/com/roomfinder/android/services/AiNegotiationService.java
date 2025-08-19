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

/**
 * AI Negotiation Service - Port of website's AIChatHandler
 * Handles automatic property search, landlord negotiation, and deal reporting
 */
public class AiNegotiationService {
    private static final String TAG = "AiNegotiationService";
    private static AiNegotiationService instance;
    
    private final Context context;
    private final OkHttpClient httpClient;
    private final ExecutorService executorService;
    private final Handler mainHandler;
    private final ApiService apiService;
    
    // Real-time chat integration
    private RealTimeChatService chatService;
    
    // User state (similar to website's AIChatHandler)
    private String currentUserEmail;
    private UserNeeds userNeeds;
    private List<Listing> matchingListings;
    private String negotiationState;
    private Map<String, Object> activeNegotiations;
    private String pendingUserResponse;
    
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
        this.executorService = Executors.newFixedThreadPool(3);
        this.mainHandler = new Handler(Looper.getMainLooper());
        this.apiService = ApiClient.getInstance().getApiService();
        
        // Initialize state (like website's constructor)
        this.userNeeds = new UserNeeds();
        this.matchingListings = new ArrayList<>();
        this.negotiationState = "idle";
        this.activeNegotiations = new HashMap<>();
        this.pendingUserResponse = null;
    }
    
    public static synchronized AiNegotiationService getInstance(Context context) {
        if (instance == null) {
            instance = new AiNegotiationService(context);
        }
        return instance;
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
     * Generate professional negotiation message
     */
    private String generateNegotiationMessage(Listing listing) {
        StringBuilder message = new StringBuilder();
        
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
        
        // Add user preferences context
        if (userNeeds.maxPrice != null || userNeeds.bedrooms != null || userNeeds.houseType != null) {
            message.append("I'm looking for ");
            List<String> preferences = new ArrayList<>();
            
            if (userNeeds.houseType != null) {
                preferences.add("a " + userNeeds.houseType.toLowerCase());
            }
            if (userNeeds.bedrooms != null) {
                preferences.add(userNeeds.bedrooms + " bedroom" + (userNeeds.bedrooms > 1 ? "s" : ""));
            }
            if (userNeeds.maxPrice != null) {
                preferences.add("within my budget of $" + userNeeds.maxPrice.intValue());
            }
            
            message.append(String.join(", ", preferences)).append(".\n\n");
        }
        
        message.append("Could you please provide more details about the property? ");
        message.append("I'm ready to move in soon and would appreciate the opportunity to discuss this rental. ");
        
        if (listing.getPrice() > 0 && userNeeds.maxPrice != null && listing.getPrice() > userNeeds.maxPrice) {
            message.append("I noticed the listing price is $").append((int)listing.getPrice())
                   .append(", and I was hoping we could discuss the possibility of a rent adjustment to $")
                   .append(userNeeds.maxPrice.intValue()).append(" given my specific situation.");
        }
        
        message.append("\n\nThank you for your time, and I look forward to hearing from you!");
        
        return message.toString();
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
                // Handle any immediate responses from landlord
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
}