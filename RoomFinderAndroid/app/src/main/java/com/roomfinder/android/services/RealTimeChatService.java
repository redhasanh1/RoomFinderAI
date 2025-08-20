package com.roomfinder.android.services;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import com.roomfinder.android.models.ChatMessage;
import com.roomfinder.android.models.Conversation;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.database.SupabaseClient;
import com.roomfinder.android.utils.ApiKeys;
import com.roomfinder.android.auth.AuthManager;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import okhttp3.*;
import okhttp3.sse.*;
import java.util.concurrent.ExecutorService;

/**
 * Real-time chat service for handling user-to-user messaging
 * Replicates the website's chat functionality using Supabase real-time subscriptions
 */
public class RealTimeChatService {
    private static final String TAG = "RealTimeChatService";
    private static RealTimeChatService instance;
    
    private Context context;
    private SupabaseClient supabaseClient;
    private Handler mainHandler;
    private ScheduledExecutorService executorService;
    
    // Real-time connection management
    private OkHttpClient httpClient;
    private EventSource eventSource;
    private String currentSubscriptionChannel;
    private boolean isConnected = false;
    private int reconnectAttempts = 0;
    private static final int MAX_RECONNECT_ATTEMPTS = 5;
    
    // Message listeners
    private ConcurrentHashMap<String, MessageListener> messageListeners = new ConcurrentHashMap<>();
    private ConcurrentHashMap<String, ConversationListener> conversationListeners = new ConcurrentHashMap<>();
    
    // Message tracking for polling
    private ConcurrentHashMap<String, Long> lastMessageTimestamps = new ConcurrentHashMap<>();
    private ConcurrentHashMap<String, String> lastMessageIds = new ConcurrentHashMap<>();
    
    // Health check tracking
    private ConcurrentHashMap<String, Long> lastSuccessfulPoll = new ConcurrentHashMap<>();
    private ConcurrentHashMap<String, Integer> consecutiveFailures = new ConcurrentHashMap<>();
    
    // Conversation cache
    private List<Conversation> cachedConversations = new ArrayList<>();
    private String currentUserEmail;
    
    public interface MessageListener {
        void onMessageReceived(ChatMessage message);
        void onMessageSent(ChatMessage message);
        void onTypingIndicator(String senderEmail, boolean isTyping);
        void onError(String error);
    }
    
    public interface ConversationListener {
        void onConversationCreated(Conversation conversation);
        void onConversationUpdated(Conversation conversation);
        void onConversationsLoaded(List<Conversation> conversations);
        void onError(String error);
    }
    
    public interface ConversationCallback {
        void onSuccess(Conversation conversation);
        void onError(String error);
    }
    
    public interface MessagesCallback {
        void onSuccess(List<ChatMessage> messages);
        void onError(String error);
    }
    
    private RealTimeChatService(Context context) {
        this.context = context.getApplicationContext();
        this.supabaseClient = SupabaseClient.getInstance();
        this.mainHandler = new Handler(Looper.getMainLooper());
        this.executorService = Executors.newScheduledThreadPool(2);
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .build();
        
        // Get current user
        AuthManager authManager = AuthManager.getInstance(context);
        if (authManager.isUserAuthenticated()) {
            this.currentUserEmail = authManager.getCurrentUser().getEmail();
        }
    }
    
    public static synchronized RealTimeChatService getInstance(Context context) {
        if (instance == null) {
            instance = new RealTimeChatService(context);
        }
        return instance;
    }
    
    /**
     * Initialize real-time connection for messaging
     */
    public void initialize() {
        Log.d(TAG, "Initializing RealTimeChatService...");
        
        if (currentUserEmail == null) {
            Log.e(TAG, "Cannot initialize chat service: User not authenticated");
            return;
        }
        
        setupRealtimeConnection();
        
        // Auto-debug conversations immediately
        Log.w(TAG, "🔍 AUTO-DEBUG: Running conversation debug immediately after initialization");
        debugAllUserConversations();
        
        // Also scan for recent messages containing common test words
        scanForRecentMessages();
    }
    
    /**
     * Setup real-time connection using Supabase realtime
     */
    private void setupRealtimeConnection() {
        try {
            // Fix URL construction to avoid double slashes
            String baseUrl = ApiKeys.SUPABASE_URL;
            if (baseUrl.endsWith("/")) {
                baseUrl = baseUrl.substring(0, baseUrl.length() - 1);
            }
            String realtimeUrl = baseUrl.replace("https://", "wss://") + "/realtime/v1/websocket";
            String channel = "messages_realtime_" + System.currentTimeMillis();
            
            Log.d(TAG, "🔗 Attempting to connect to: " + realtimeUrl);
            
            // Build WebSocket URL with authentication - add null safety check
            HttpUrl parsedUrl = HttpUrl.parse(realtimeUrl);
            if (parsedUrl == null) {
                Log.e(TAG, "❌ Failed to parse realtime URL: " + realtimeUrl);
                handleConnectionError("Invalid WebSocket URL");
                return;
            }
            
            HttpUrl.Builder urlBuilder = parsedUrl.newBuilder()
                    .addQueryParameter("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addQueryParameter("vsn", "1.0.0");
        
            Request request = new Request.Builder()
                    .url(urlBuilder.build())
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .build();
            
            EventSourceListener listener = new EventSourceListener() {
                @Override
                public void onOpen(EventSource eventSource, Response response) {
                    Log.d(TAG, "✅ Real-time connection opened");
                    isConnected = true;
                    reconnectAttempts = 0;
                    subscribeToMessages();
                }
                
                @Override
                public void onEvent(EventSource eventSource, String id, String type, String data) {
                    Log.d(TAG, "📨 Real-time event received: " + type + " - " + data);
                    handleRealtimeEvent(type, data);
                }
                
                @Override
                public void onClosed(EventSource eventSource) {
                    Log.d(TAG, "🔌 Real-time connection closed");
                    isConnected = false;
                    scheduleReconnect();
                }
                
                @Override
                public void onFailure(EventSource eventSource, Throwable t, Response response) {
                    Log.e(TAG, "❌ Real-time connection failed", t);
                    isConnected = false;
                    scheduleReconnect();
                }
            };
            
            eventSource = EventSources.createFactory(httpClient).newEventSource(request, listener);
            
        } catch (Exception e) {
            Log.e(TAG, "❌ Failed to setup real-time connection", e);
            handleConnectionError("Real-time connection setup failed: " + e.getMessage());
        }
    }
    
    /**
     * Subscribe to message changes
     */
    private void subscribeToMessages() {
        try {
            if (isConnected && eventSource != null) {
                // Send subscription message for all active conversations
                for (String conversationId : messageListeners.keySet()) {
                    subscribeToConversation(conversationId);
                }
                
                Log.d(TAG, "✅ Subscribed to " + messageListeners.size() + " conversation channels");
            } else {
                Log.d(TAG, "WebSocket not connected, using polling fallback");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error subscribing to messages, falling back to polling", e);
        }
        
        // Always start polling as a fallback
        startMessagePolling();
    }
    
    /**
     * Subscribe to a specific conversation channel
     */
    private void subscribeToConversation(String conversationId) {
        try {
            // Create subscription payload for Supabase realtime
            JSONObject payload = new JSONObject();
            payload.put("topic", "realtime:messages");
            payload.put("event", "phx_join");
            
            JSONObject payloadData = new JSONObject();
            payloadData.put("config", new JSONObject()
                    .put("postgres_changes", new JSONArray()
                            .put(new JSONObject()
                                    .put("event", "INSERT")
                                    .put("schema", "public")
                                    .put("table", "messages")
                                    .put("filter", "conversation_id=eq." + conversationId)
                            )
                    )
            );
            payload.put("payload", payloadData);
            payload.put("ref", "conversation_" + conversationId);
            
            Log.d(TAG, "🔔 Subscribing to conversation: " + conversationId);
            
            // Note: In a real implementation, this would send the subscription through the WebSocket
            // For now, we rely on polling since the WebSocket subscription is complex
            
        } catch (JSONException e) {
            Log.e(TAG, "Error creating subscription payload for conversation " + conversationId, e);
        }
    }
    
    /**
     * Start polling for new messages (fallback for real-time)
     */
    private void startMessagePolling() {
        executorService.scheduleWithFixedDelay(() -> {
            if (currentUserEmail != null) {
                checkForNewMessages();
                
                // Also check for ANY conversations involving current user (website compatibility)
                checkForAllUserConversations();
            }
        }, 0, 15, TimeUnit.SECONDS); // Reduced from 1s to 15s to calm down excessive polling
    }
    
    /**
     * Check for new messages via polling
     */
    private void checkForNewMessages() {
        if (messageListeners.isEmpty()) {
            Log.v(TAG, "🔍 [POLLING] No active message listeners - skipping poll");
            return; // No active conversations to check
        }
        
        Log.v(TAG, "🔍 [POLLING] ===== POLLING CYCLE START =====");
        Log.v(TAG, "🔍 [POLLING] Active conversations: " + messageListeners.size());
        Log.v(TAG, "🔍 [POLLING] Conversation IDs: " + messageListeners.keySet());
        Log.v(TAG, "🔍 [POLLING] Current user: " + currentUserEmail);
        
        // Check each conversation that has an active listener
        for (String conversationId : messageListeners.keySet()) {
            Log.v(TAG, "🔍 [POLLING] Checking conversation: " + conversationId);
            checkMessagesForConversation(conversationId);
        }
        
        Log.v(TAG, "🔍 [POLLING] ===== POLLING CYCLE END =====");
    }
    
    /**
     * Check for conversations involving current user that we might not be monitoring
     * This helps catch messages from website or other platforms
     */
    private void checkForAllUserConversations() {
        if (currentUserEmail == null) {
            return;
        }
        
        // Run this check much less frequently to reduce API calls
        if (System.currentTimeMillis() % 60000 < 15000) { // Roughly every 60 seconds
            Log.v(TAG, "🌐 [GLOBAL_CHECK] Checking for any conversations involving user: " + currentUserEmail);
            
            executorService.execute(() -> {
                try {
                    // Get all conversations involving current user (both as sender and receiver)
                    String url = ApiKeys.SUPABASE_URL + "rest/v1/conversations?select=*" +
                            "&or=(sender_email.eq." + currentUserEmail + ",receiver_email.eq." + currentUserEmail + ")" +
                            "&order=created_at.desc&limit=20";
                    
                    Log.v(TAG, "🌐 [GLOBAL_CHECK] URL: " + url);
                    
                    Request request = new Request.Builder()
                            .url(url)
                            .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                            .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                            .addHeader("Content-Type", "application/json")
                            .build();
                    
                    try (Response response = httpClient.newCall(request).execute()) {
                        if (response.isSuccessful() && response.body() != null) {
                            String responseBody = response.body().string();
                            Log.v(TAG, "🌐 [GLOBAL_CHECK] Found conversations: " + responseBody);
                            
                            JSONArray conversations = new JSONArray(responseBody);
                            for (int i = 0; i < conversations.length(); i++) {
                                JSONObject conv = conversations.getJSONObject(i);
                                String conversationId = conv.optString("id");
                                
                                // If we're not already monitoring this conversation, check it for new messages
                                if (!messageListeners.containsKey(conversationId)) {
                                    Log.d(TAG, "🌐 [GLOBAL_CHECK] Found unmonitored conversation: " + conversationId);
                                    
                                    // Check for recent messages in this conversation
                                    checkMessagesForConversation(conversationId);
                                }
                            }
                        }
                    }
                } catch (Exception e) {
                    Log.e(TAG, "🌐 [GLOBAL_CHECK] Error checking all user conversations", e);
                }
            });
        }
    }
    
    /**
     * Check for new messages in a specific conversation
     */
    private void checkMessagesForConversation(String conversationId) {
        Log.v(TAG, "🔍 [POLL_CONV] ===== CHECKING CONVERSATION =====");
        Log.v(TAG, "🔍 [POLL_CONV] ConversationId: " + conversationId);
        Log.v(TAG, "🔍 [POLL_CONV] Current user email: " + currentUserEmail);
        
        try {
            // Get the last message timestamp for this conversation
            Long lastTimestamp = lastMessageTimestamps.get(conversationId);
            String lastMessageId = lastMessageIds.get(conversationId);
            
            Log.v(TAG, "🔍 [POLL_CONV] Last timestamp: " + lastTimestamp);
            Log.v(TAG, "🔍 [POLL_CONV] Last message ID: " + lastMessageId);
            
            // Build URL to get messages newer than last known
            StringBuilder urlBuilder = new StringBuilder();
            urlBuilder.append(ApiKeys.SUPABASE_URL)
                    .append("rest/v1/messages?select=*")
                    .append("&conversation_id=eq.").append(conversationId)
                    .append("&order=created_at.asc");
            
            // If we have a last timestamp, only get newer messages
            if (lastTimestamp != null) {
                // Convert timestamp to ISO format for Supabase
                String isoTimestamp = java.time.Instant.ofEpochMilli(lastTimestamp).toString();
                urlBuilder.append("&created_at=gt.").append(isoTimestamp);
            }
            
            String url = urlBuilder.toString();
            
            Log.v(TAG, "🔍 [POLL_CONV] Request URL: " + url);
            
            Request request = new Request.Builder()
                    .url(url)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .build();
            
            Log.v(TAG, "🔍 [POLL_CONV] Making HTTP request...");
            
            // Execute request asynchronously
            httpClient.newCall(request).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    Log.e(TAG, "🔍 [POLLING] ❌ Failed to poll messages for conversation " + conversationId + ": " + e.getMessage());
                    
                    // Track consecutive failures
                    int failures = consecutiveFailures.getOrDefault(conversationId, 0) + 1;
                    consecutiveFailures.put(conversationId, failures);
                    Log.w(TAG, "🔍 [POLLING] ⚠️ Consecutive failures for " + conversationId + ": " + failures);
                    
                    // Retry mechanism with exponential backoff
                    long retryDelay = Math.min(5 * failures, 30); // 5s, 10s, 15s, up to 30s max
                    Log.d(TAG, "🔍 [POLLING] 🔄 Scheduling retry for conversation " + conversationId + " in " + retryDelay + " seconds...");
                    executorService.schedule(() -> {
                        Log.d(TAG, "🔍 [POLLING] 🔄 Retrying message check for conversation " + conversationId + " (attempt " + (failures + 1) + ")");
                        checkMessagesForConversation(conversationId);
                    }, retryDelay, TimeUnit.SECONDS);
                }
                
                @Override
                public void onResponse(Call call, Response response) throws IOException {
                    if (response.isSuccessful() && response.body() != null) {
                        // Reset failure tracking on successful response
                        consecutiveFailures.put(conversationId, 0);
                        lastSuccessfulPoll.put(conversationId, System.currentTimeMillis());
                        
                        try {
                            String responseBody = response.body().string();
                            Log.v(TAG, "🔍 [POLL_CONV] Response body length: " + responseBody.length());
                            Log.v(TAG, "🔍 [POLL_CONV] Response body: " + responseBody);
                            
                            JSONArray messagesArray = new JSONArray(responseBody);
                            Log.v(TAG, "🔍 [POLL_CONV] Found " + messagesArray.length() + " messages in response");
                            
                            List<ChatMessage> newMessages = new ArrayList<>();
                            for (int i = 0; i < messagesArray.length(); i++) {
                                JSONObject messageJson = messagesArray.getJSONObject(i);
                                ChatMessage message = parseMessageFromJson(messageJson);
                                
                                Log.d(TAG, "🔍 [POLLING] Processing message: " + message.getId() + " from " + message.getSenderEmail());
                                Log.d(TAG, "🔍 [POLLING] Message content: '" + message.getContent() + "'");
                                Log.d(TAG, "🔍 [POLLING] Current user email: '" + currentUserEmail + "'");
                                Log.d(TAG, "🔍 [POLLING] Message conversation ID: " + message.getConversationId());
                                Log.d(TAG, "🔍 [POLLING] Expected conversation ID: " + conversationId);
                                
                                // Skip if this is the last message we already have
                                if (lastMessageId != null && lastMessageId.equals(message.getId())) {
                                    Log.v(TAG, "🔍 [POLLING] ⏭️ Skipping already processed message: " + message.getId());
                                    continue;
                                }
                                
                                // Skip messages from current user (they're already shown when sent)
                                // Add comprehensive email normalization and comparison
                                String messageSender = normalizeEmail(message.getSenderEmail());
                                String normalizedCurrentUser = normalizeEmail(currentUserEmail);
                                
                                Log.d(TAG, "🔍 [POLLING] Email comparison - Current: '" + normalizedCurrentUser + "' vs Message: '" + messageSender + "'");
                                
                                if (normalizedCurrentUser != null && messageSender != null) {
                                    if (normalizedCurrentUser.equals(messageSender)) {
                                        Log.d(TAG, "🔍 [POLLING] ⏭️ Skipping own message from: " + messageSender);
                                        continue;
                                    }
                                } else {
                                    Log.w(TAG, "🔍 [POLLING] ⚠️ Null email detected - currentUser: " + normalizedCurrentUser + ", messageSender: " + messageSender);
                                    if (normalizedCurrentUser == null) {
                                        Log.e(TAG, "🔍 [POLLING] ❌ CRITICAL: Current user email is null - message detection will fail!");
                                    }
                                }
                                
                                Log.d(TAG, "🔍 [POLLING] ✅ NEW MESSAGE DETECTED: '" + message.getContent() + "' from " + message.getSenderEmail());
                                newMessages.add(message);
                                
                                // Update tracking
                                lastMessageTimestamps.put(conversationId, message.getTimestamp());
                                lastMessageIds.put(conversationId, message.getId());
                            }
                            
                            // Notify listeners of new messages
                            if (!newMessages.isEmpty()) {
                                Log.d(TAG, "🔍 [POLLING] 📬 Found " + newMessages.size() + " new messages for conversation " + conversationId);
                                for (ChatMessage message : newMessages) {
                                    Log.d(TAG, "🔍 [POLLING] 📨 Notifying listeners about message: '" + message.getContent() + "'");
                                    notifyMessageListeners(message);
                                    
                                    // NOTE: Removed checkForAiNegotiationTrigger to prevent duplicate responses
                                    // AI negotiation is already handled through the message listeners
                                }
                            } else {
                                Log.d(TAG, "🔍 [POLLING] 📭 No new messages found for conversation " + conversationId);
                            }
                            
                        } catch (JSONException e) {
                            Log.e(TAG, "Error parsing messages response for conversation " + conversationId, e);
                        }
                    }
                    response.close();
                }
            });
            
        } catch (Exception e) {
            Log.e(TAG, "Error checking messages for conversation " + conversationId, e);
        }
    }
    
    /**
     * Handle real-time events from Supabase
     */
    private void handleRealtimeEvent(String eventType, String data) {
        try {
            JSONObject eventData = new JSONObject(data);
            
            if ("postgres_changes".equals(eventType)) {
                String table = eventData.optString("table");
                String eventAction = eventData.optString("event");
                JSONObject record = eventData.optJSONObject("record");
                
                if ("messages".equals(table) && "INSERT".equals(eventAction) && record != null) {
                    ChatMessage message = parseMessageFromJson(record);
                    notifyMessageListeners(message);
                }
            }
        } catch (JSONException e) {
            Log.e(TAG, "Error parsing real-time event", e);
        }
    }
    
    /**
     * Parse ChatMessage from JSON
     */
    private ChatMessage parseMessageFromJson(JSONObject json) {
        ChatMessage message = new ChatMessage();
        message.setId(json.optString("id"));
        message.setContent(json.optString("content"));
        message.setSenderEmail(json.optString("sender_email"));
        message.setConversationId(json.optString("conversation_id"));
        message.setMessageType(json.optString("message_type", "text"));
        message.setFileUrl(json.optString("file_url"));
        message.setFileName(json.optString("file_name"));
        
        String createdAt = json.optString("created_at");
        if (!createdAt.isEmpty()) {
            // Parse ISO timestamp
            try {
                message.setTimestamp(System.currentTimeMillis()); // Simplified
            } catch (Exception e) {
                message.setTimestamp(System.currentTimeMillis());
            }
        }
        
        if ("file".equals(message.getMessageType())) {
            message.setType(ChatMessage.MessageType.FILE_MESSAGE);
        } else {
            message.setType(ChatMessage.MessageType.USER_MESSAGE);
        }
        
        return message;
    }
    
    /**
     * Handle connection errors and fallback to polling
     */
    private void handleConnectionError(String errorMessage) {
        Log.e(TAG, "Connection error: " + errorMessage);
        isConnected = false;
        
        // Notify all message listeners about the error
        for (MessageListener listener : messageListeners.values()) {
            if (listener != null) {
                mainHandler.post(() -> listener.onError("Real-time connection failed: " + errorMessage));
            }
        }
        
        // Start polling as fallback
        startMessagePolling();
    }
    
    /**
     * Schedule reconnection attempt
     */
    private void scheduleReconnect() {
        if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
            reconnectAttempts++;
            long delay = Math.min(5000 * reconnectAttempts, 30000); // Exponential backoff
            
            Log.d(TAG, "Scheduling reconnect attempt " + reconnectAttempts + " in " + delay + "ms");
            
            executorService.schedule(() -> {
                if (!isConnected) {
                    setupRealtimeConnection();
                }
            }, delay, TimeUnit.MILLISECONDS);
        } else {
            Log.e(TAG, "Max reconnect attempts reached. Real-time disabled.");
        }
    }
    
    /**
     * Start or find conversation with a user about a listing
     */
    public void startConversation(Listing listing, String receiverEmail, ConversationCallback callback) {
        if (currentUserEmail == null) {
            callback.onError("User not authenticated");
            return;
        }
        
        if (normalizeEmail(currentUserEmail).equals(normalizeEmail(receiverEmail))) {
            callback.onError("Cannot start conversation with yourself");
            return;
        }
        
        executorService.execute(() -> {
            try {
                // First check if conversation exists
                Conversation existingConversation = findExistingConversation(listing.getId(), receiverEmail);
                
                if (existingConversation != null) {
                    mainHandler.post(() -> callback.onSuccess(existingConversation));
                    return;
                }
                
                // Create new conversation
                Conversation newConversation = createNewConversation(listing, receiverEmail);
                if (newConversation != null) {
                    mainHandler.post(() -> callback.onSuccess(newConversation));
                } else {
                    mainHandler.post(() -> callback.onError("Failed to create conversation"));
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error starting conversation", e);
                mainHandler.post(() -> callback.onError("Error starting conversation: " + e.getMessage()));
            }
        });
    }
    
    /**
     * Find existing conversation - BIDIRECTIONAL LOOKUP for website-Android compatibility
     */
    private Conversation findExistingConversation(String listingId, String receiverEmail) {
        Log.d(TAG, "🔍 [FIND_CONV] ===== BIDIRECTIONAL CONVERSATION SEARCH =====");
        Log.d(TAG, "🔍 [FIND_CONV] Listing ID: " + listingId);
        Log.d(TAG, "🔍 [FIND_CONV] Current user: " + currentUserEmail);
        Log.d(TAG, "🔍 [FIND_CONV] Target email: " + receiverEmail);
        
        try {
            // Try direction 1: Android user as sender (original logic)
            Log.d(TAG, "🔍 [FIND_CONV] Checking direction 1: Android->Landlord");
            String url1 = ApiKeys.SUPABASE_URL + "rest/v1/conversations?select=*" +
                    "&listing_id=eq." + listingId +
                    "&sender_email=eq." + currentUserEmail +
                    "&receiver_email=eq." + receiverEmail +
                    "&limit=1";
            
            Log.d(TAG, "🔍 [FIND_CONV] URL1: " + url1);
            Conversation conv1 = checkConversationUrl(url1);
            if (conv1 != null) {
                Log.d(TAG, "🔍 [FIND_CONV] ✅ Found conversation (direction 1): " + conv1.getId());
                return conv1;
            }
            
            // Try direction 2: Android user as receiver (for website replies)
            Log.d(TAG, "🔍 [FIND_CONV] Checking direction 2: Landlord->Android");
            String url2 = ApiKeys.SUPABASE_URL + "rest/v1/conversations?select=*" +
                    "&listing_id=eq." + listingId +
                    "&sender_email=eq." + receiverEmail +
                    "&receiver_email=eq." + currentUserEmail +
                    "&limit=1";
            
            Log.d(TAG, "🔍 [FIND_CONV] URL2: " + url2);
            Conversation conv2 = checkConversationUrl(url2);
            if (conv2 != null) {
                Log.d(TAG, "🔍 [FIND_CONV] ✅ Found conversation (direction 2): " + conv2.getId());
                return conv2;
            }
            
            // Try fallback: Any conversation for this listing involving both users
            Log.d(TAG, "🔍 [FIND_CONV] Checking fallback: Any conversation for listing");
            String url3 = ApiKeys.SUPABASE_URL + "rest/v1/conversations?select=*" +
                    "&listing_id=eq." + listingId +
                    "&limit=10"; // Get up to 10 to find the right one
            
            Log.d(TAG, "🔍 [FIND_CONV] URL3: " + url3);
            Conversation conv3 = findConversationInResults(url3, currentUserEmail, receiverEmail);
            if (conv3 != null) {
                Log.d(TAG, "🔍 [FIND_CONV] ✅ Found conversation (fallback): " + conv3.getId());
                return conv3;
            }
            
            Log.w(TAG, "🔍 [FIND_CONV] ❌ No conversation found in any direction");
            return null;
            
        } catch (Exception e) {
            Log.e(TAG, "🔍 [FIND_CONV] ❌ Error finding existing conversation", e);
        }
        return null;
    }
    
    /**
     * Helper method to check a conversation URL
     */
    private Conversation checkConversationUrl(String url) {
        try {
            Request request = new Request.Builder()
                    .url(url)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .build();
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (response.isSuccessful() && response.body() != null) {
                    String responseBody = response.body().string();
                    Log.d(TAG, "🔍 [FIND_CONV] Response: " + responseBody);
                    
                    JSONArray conversations = new JSONArray(responseBody);
                    if (conversations.length() > 0) {
                        JSONObject conversationJson = conversations.getJSONObject(0);
                        return parseConversationFromJson(conversationJson);
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "🔍 [FIND_CONV] Error checking conversation URL", e);
        }
        return null;
    }
    
    /**
     * Helper method to find conversation involving both users in results
     */
    private Conversation findConversationInResults(String url, String user1, String user2) {
        try {
            Request request = new Request.Builder()
                    .url(url)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .build();
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (response.isSuccessful() && response.body() != null) {
                    String responseBody = response.body().string();
                    Log.d(TAG, "🔍 [FIND_CONV] Fallback response: " + responseBody);
                    
                    JSONArray conversations = new JSONArray(responseBody);
                    for (int i = 0; i < conversations.length(); i++) {
                        JSONObject conv = conversations.getJSONObject(i);
                        String sender = conv.optString("sender_email");
                        String receiver = conv.optString("receiver_email");
                        
                        // Check if this conversation involves both users (with normalized email comparison)
                        String normalizedSender = normalizeEmail(sender);
                        String normalizedReceiver = normalizeEmail(receiver);
                        String normalizedUser1 = normalizeEmail(user1);
                        String normalizedUser2 = normalizeEmail(user2);
                        
                        if ((normalizedSender.equals(normalizedUser1) && normalizedReceiver.equals(normalizedUser2)) ||
                            (normalizedSender.equals(normalizedUser2) && normalizedReceiver.equals(normalizedUser1))) {
                            Log.d(TAG, "🔍 [FIND_CONV] Found matching conversation: " + conv.optString("id"));
                            Log.d(TAG, "🔍 [FIND_CONV] Conversation participants: " + normalizedSender + " <-> " + normalizedReceiver);
                            return parseConversationFromJson(conv);
                        }
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "🔍 [FIND_CONV] Error checking fallback conversations", e);
        }
        return null;
    }
    
    /**
     * Create new conversation
     */
    private Conversation createNewConversation(Listing listing, String receiverEmail) {
        try {
            JSONObject conversationData = new JSONObject();
            conversationData.put("listing_id", listing.getId());
            conversationData.put("sender_email", currentUserEmail);
            conversationData.put("receiver_email", receiverEmail);
            conversationData.put("created_at", java.time.Instant.now().toString());
            
            String url = ApiKeys.SUPABASE_URL + "rest/v1/conversations";
            
            RequestBody body = RequestBody.create(
                    conversationData.toString(),
                    MediaType.parse("application/json")
            );
            
            Request request = new Request.Builder()
                    .url(url)
                    .post(body)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .addHeader("Prefer", "return=representation")
                    .build();
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (response.isSuccessful() && response.body() != null) {
                    String responseBody = response.body().string();
                    JSONArray conversations = new JSONArray(responseBody);
                    
                    if (conversations.length() > 0) {
                        JSONObject conversationJson = conversations.getJSONObject(0);
                        return parseConversationFromJson(conversationJson);
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error creating new conversation", e);
        }
        return null;
    }
    
    /**
     * Parse Conversation from JSON
     */
    private Conversation parseConversationFromJson(JSONObject json) {
        Conversation conversation = new Conversation();
        conversation.setId(json.optString("id"));
        conversation.setListingId(json.optString("listing_id"));
        conversation.setSenderEmail(json.optString("sender_email"));
        conversation.setReceiverEmail(json.optString("receiver_email"));
        
        String createdAt = json.optString("created_at");
        if (!createdAt.isEmpty()) {
            conversation.setCreatedAt(System.currentTimeMillis()); // Simplified
        }
        
        return conversation;
    }
    
    /**
     * Send a file message
     */
    public void sendFileMessage(String conversationId, String fileName, String fileUrl, String caption, MessageListener listener) {
        if (currentUserEmail == null) {
            if (listener != null) listener.onError("User not authenticated");
            return;
        }
        
        executorService.execute(() -> {
            try {
                JSONObject messageData = new JSONObject();
                messageData.put("conversation_id", conversationId);
                messageData.put("sender_email", currentUserEmail);
                messageData.put("content", caption != null && !caption.trim().isEmpty() ? caption : fileName);
                messageData.put("message_type", "file");
                messageData.put("file_url", fileUrl != null ? fileUrl : "");
                messageData.put("file_name", fileName != null ? fileName : "photo.jpg");
                messageData.put("created_at", java.time.Instant.now().toString());
                
                String url = ApiKeys.SUPABASE_URL + "rest/v1/messages";
                
                RequestBody body = RequestBody.create(
                        messageData.toString(),
                        MediaType.parse("application/json")
                );
                
                Request request = new Request.Builder()
                        .url(url)
                        .post(body)
                        .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", "application/json")
                        .addHeader("Prefer", "return=representation")
                        .build();
                
                try (Response response = httpClient.newCall(request).execute()) {
                    if (response.isSuccessful() && response.body() != null) {
                        String responseBody = response.body().string();
                        JSONArray messages = new JSONArray(responseBody);
                        
                        if (messages.length() > 0) {
                            JSONObject messageJson = messages.getJSONObject(0);
                            ChatMessage message = parseMessageFromJson(messageJson);
                            
                            mainHandler.post(() -> {
                                if (listener != null) listener.onMessageSent(message);
                            });
                        } else {
                            mainHandler.post(() -> {
                                if (listener != null) listener.onError("No message returned from server");
                            });
                        }
                    } else {
                        String errorMessage = "Failed to send file message";
                        if (response.body() != null) {
                            try {
                                String errorBody = response.body().string();
                                Log.e(TAG, "File message send error response: " + errorBody);
                                errorMessage = "Failed to send file message: " + response.code();
                            } catch (Exception e) {
                                // Ignore
                            }
                        }
                        final String finalError = errorMessage;
                        mainHandler.post(() -> {
                            if (listener != null) listener.onError(finalError);
                        });
                    }
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error sending file message", e);
                mainHandler.post(() -> {
                    if (listener != null) listener.onError("Error sending file message: " + e.getMessage());
                });
            }
        });
    }
    
    /**
     * Send a text message
     */
    public void sendMessage(String conversationId, String content, MessageListener listener) {
        if (currentUserEmail == null) {
            if (listener != null) listener.onError("User not authenticated");
            return;
        }
        
        executorService.execute(() -> {
            try {
                JSONObject messageData = new JSONObject();
                messageData.put("conversation_id", conversationId);
                messageData.put("sender_email", currentUserEmail);
                messageData.put("content", content);
                messageData.put("message_type", "text");
                messageData.put("created_at", java.time.Instant.now().toString());
                
                String url = ApiKeys.SUPABASE_URL + "rest/v1/messages";
                
                RequestBody body = RequestBody.create(
                        messageData.toString(),
                        MediaType.parse("application/json")
                );
                
                Request request = new Request.Builder()
                        .url(url)
                        .post(body)
                        .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", "application/json")
                        .addHeader("Prefer", "return=representation")
                        .build();
                
                try (Response response = httpClient.newCall(request).execute()) {
                    if (response.isSuccessful() && response.body() != null) {
                        String responseBody = response.body().string();
                        JSONArray messages = new JSONArray(responseBody);
                        
                        if (messages.length() > 0) {
                            JSONObject messageJson = messages.getJSONObject(0);
                            ChatMessage message = parseMessageFromJson(messageJson);
                            
                            mainHandler.post(() -> {
                                if (listener != null) listener.onMessageSent(message);
                            });
                        }
                    } else {
                        mainHandler.post(() -> {
                            if (listener != null) listener.onError("Failed to send message");
                        });
                    }
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error sending message", e);
                mainHandler.post(() -> {
                    if (listener != null) listener.onError("Error sending message: " + e.getMessage());
                });
            }
        });
    }
    
    /**
     * Load messages for a conversation
     */
    public void loadMessages(String conversationId, MessagesCallback callback) {
        executorService.execute(() -> {
            try {
                String url = ApiKeys.SUPABASE_URL + "rest/v1/messages?select=*" +
                        "&conversation_id=eq." + conversationId +
                        "&order=created_at.asc";
                
                Request request = new Request.Builder()
                        .url(url)
                        .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                try (Response response = httpClient.newCall(request).execute()) {
                    if (response.isSuccessful() && response.body() != null) {
                        String responseBody = response.body().string();
                        JSONArray messagesArray = new JSONArray(responseBody);
                        
                        List<ChatMessage> messages = new ArrayList<>();
                        ChatMessage lastMessage = null;
                        
                        for (int i = 0; i < messagesArray.length(); i++) {
                            JSONObject messageJson = messagesArray.getJSONObject(i);
                            ChatMessage message = parseMessageFromJson(messageJson);
                            messages.add(message);
                            lastMessage = message; // Keep track of the latest message
                        }
                        
                        // Update tracking data with the latest message
                        if (lastMessage != null) {
                            lastMessageTimestamps.put(conversationId, lastMessage.getTimestamp());
                            lastMessageIds.put(conversationId, lastMessage.getId());
                            Log.d(TAG, "Updated tracking for conversation " + conversationId + " - last message: " + lastMessage.getId());
                        }
                        
                        mainHandler.post(() -> callback.onSuccess(messages));
                    } else {
                        mainHandler.post(() -> callback.onError("Failed to load messages"));
                    }
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error loading messages", e);
                mainHandler.post(() -> callback.onError("Error loading messages: " + e.getMessage()));
            }
        });
    }
    
    /**
     * Register message listener for a conversation
     */
    public void registerMessageListener(String conversationId, MessageListener listener) {
        // Ensure we have current user email
        if (currentUserEmail == null) {
            AuthManager authManager = AuthManager.getInstance(context);
            if (authManager.isUserAuthenticated()) {
                this.currentUserEmail = authManager.getCurrentUser().getEmail();
                Log.d(TAG, "📱 [REGISTER] ✅ Updated current user email: " + currentUserEmail);
            } else {
                Log.e(TAG, "📱 [REGISTER] ❌ User not authenticated - message detection may fail!");
            }
        }
        
        messageListeners.put(conversationId, listener);
        
        // Initialize timestamp tracking for this conversation
        if (!lastMessageTimestamps.containsKey(conversationId)) {
            lastMessageTimestamps.put(conversationId, System.currentTimeMillis());
        }
        
        // Subscribe to this conversation if we're connected
        if (isConnected) {
            subscribeToConversation(conversationId);
        }
        
        Log.d(TAG, "📱 [REGISTER] Registered listener for conversation: " + conversationId);
        Log.d(TAG, "📱 [REGISTER] Current user: " + currentUserEmail);
        Log.d(TAG, "📱 [REGISTER] Total active listeners: " + messageListeners.size());
        Log.d(TAG, "📱 [REGISTER] Polling will check this conversation every 15 seconds");
        
        // Immediate check for existing messages (catch-up mechanism)
        Log.d(TAG, "📱 [REGISTER] Performing immediate catch-up check...");
        checkMessagesForConversation(conversationId);
    }
    
    /**
     * Unregister message listener
     */
    public void unregisterMessageListener(String conversationId) {
        messageListeners.remove(conversationId);
        
        // Clean up all tracking data for this conversation
        lastMessageTimestamps.remove(conversationId);
        lastMessageIds.remove(conversationId);
        lastSuccessfulPoll.remove(conversationId);
        consecutiveFailures.remove(conversationId);
        
        Log.d(TAG, "🗑️ [UNREGISTER] Unregistered listener and cleaned up tracking for conversation: " + conversationId);
        Log.d(TAG, "🗑️ [UNREGISTER] Remaining active listeners: " + messageListeners.size());
    }
    
    /**
     * Normalize email for consistent comparison across platforms
     */
    private String normalizeEmail(String email) {
        if (email == null) {
            return null;
        }
        return email.trim().toLowerCase();
    }
    
    
    /**
     * Notify message listeners
     */
    private void notifyMessageListeners(ChatMessage message) {
        String conversationId = message.getConversationId();
        MessageListener listener = messageListeners.get(conversationId);
        
        Log.d(TAG, "🔔 [NOTIFY] Message listener for conversation " + conversationId + ": " + (listener != null ? "FOUND" : "NOT FOUND"));
        
        if (listener != null) {
            Log.d(TAG, "🔔 [NOTIFY] ✅ Calling onMessageReceived for: '" + message.getContent() + "'");
            mainHandler.post(() -> {
                Log.d(TAG, "🔔 [NOTIFY] 📨 Executing onMessageReceived callback on main thread");
                listener.onMessageReceived(message);
            });
        } else {
            Log.w(TAG, "🔔 [NOTIFY] ❌ No listener registered for conversation: " + conversationId);
            Log.d(TAG, "🔔 [NOTIFY] Available listeners: " + messageListeners.keySet());
        }
    }
    
    /**
     * Cleanup resources
     */
    public void cleanup() {
        if (eventSource != null) {
            eventSource.cancel();
        }
        
        if (executorService != null && !executorService.isShutdown()) {
            executorService.shutdown();
        }
        
        messageListeners.clear();
        conversationListeners.clear();
        lastMessageTimestamps.clear();
        lastMessageIds.clear();
    }
    
    /**
     * Check if service is connected
     */
    public boolean isConnected() {
        return isConnected;
    }
    
    /**
     * Get current user email
     */
    public String getCurrentUserEmail() {
        return currentUserEmail;
    }
    
    /**
     * DIAGNOSTIC: Manually check all conversations for current user
     * Call this to debug website-Android conversation sync issues
     */
    public void debugAllUserConversations() {
        if (currentUserEmail == null) {
            Log.e(TAG, "🔍 [DEBUG] Cannot debug - current user email is null");
            return;
        }
        
        Log.w(TAG, "🔍 [DEBUG] ===== MANUAL CONVERSATION DEBUG =====");
        Log.w(TAG, "🔍 [DEBUG] Current user: " + currentUserEmail);
        Log.w(TAG, "🔍 [DEBUG] Normalized user: " + normalizeEmail(currentUserEmail));
        
        executorService.execute(() -> {
            try {
                // Get ALL conversations involving this user  
                String url = ApiKeys.SUPABASE_URL + "rest/v1/conversations?select=*" +
                        "&or=(sender_email.eq." + currentUserEmail + ",receiver_email.eq." + currentUserEmail + ")" +
                        "&order=created_at.desc&limit=50";
                
                Log.w(TAG, "🔍 [DEBUG] Query URL: " + url);
                
                Request request = new Request.Builder()
                        .url(url)
                        .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                try (Response response = httpClient.newCall(request).execute()) {
                    if (response.isSuccessful() && response.body() != null) {
                        String responseBody = response.body().string();
                        Log.w(TAG, "🔍 [DEBUG] Raw response: " + responseBody);
                        
                        JSONArray conversations = new JSONArray(responseBody);
                        Log.w(TAG, "🔍 [DEBUG] Found " + conversations.length() + " total conversations");
                        
                        for (int i = 0; i < conversations.length(); i++) {
                            JSONObject conv = conversations.getJSONObject(i);
                            String id = conv.optString("id");
                            String sender = conv.optString("sender_email");
                            String receiver = conv.optString("receiver_email");
                            String listingId = conv.optString("listing_id");
                            String createdAt = conv.optString("created_at");
                            
                            Log.w(TAG, "🔍 [DEBUG] Conversation " + (i+1) + ":");
                            Log.w(TAG, "🔍 [DEBUG]   ID: " + id);
                            Log.w(TAG, "🔍 [DEBUG]   Sender: " + sender);
                            Log.w(TAG, "🔍 [DEBUG]   Receiver: " + receiver);
                            Log.w(TAG, "🔍 [DEBUG]   Listing: " + listingId);
                            Log.w(TAG, "🔍 [DEBUG]   Created: " + createdAt);
                            Log.w(TAG, "🔍 [DEBUG]   Monitored: " + messageListeners.containsKey(id));
                            
                            // Check for recent messages in this conversation
                            checkRecentMessagesInConversation(id);
                        }
                    } else {
                        Log.e(TAG, "🔍 [DEBUG] Failed to get conversations: " + response.code());
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "🔍 [DEBUG] Error debugging conversations", e);
            }
        });
    }
    
    /**
     * DIAGNOSTIC: Check recent messages in a conversation
     */
    private void checkRecentMessagesInConversation(String conversationId) {
        try {
            String url = ApiKeys.SUPABASE_URL + "rest/v1/messages?select=*" +
                    "&conversation_id=eq." + conversationId +
                    "&order=created_at.desc&limit=5";
            
            Request request = new Request.Builder()
                    .url(url)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
                    .build();
            
            try (Response response = httpClient.newCall(request).execute()) {
                if (response.isSuccessful() && response.body() != null) {
                    String responseBody = response.body().string();
                    JSONArray messages = new JSONArray(responseBody);
                    
                    Log.w(TAG, "🔍 [DEBUG]   Recent messages (" + messages.length() + "):");
                    for (int j = 0; j < Math.min(3, messages.length()); j++) {
                        JSONObject msg = messages.getJSONObject(j);
                        String content = msg.optString("content");
                        String sender = msg.optString("sender_email");
                        String createdAt = msg.optString("created_at");
                        
                        Log.w(TAG, "🔍 [DEBUG]     " + (j+1) + ". '" + content.substring(0, Math.min(50, content.length())) + "...' from " + sender + " at " + createdAt);
                    }
                } else {
                    Log.w(TAG, "🔍 [DEBUG]   Failed to get messages for conversation " + conversationId);
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "🔍 [DEBUG] Error checking messages for conversation " + conversationId, e);
        }
    }
    
    /**
     * Scan for recent messages containing test keywords to find hidden conversations
     */
    private void scanForRecentMessages() {
        if (currentUserEmail == null) {
            Log.e(TAG, "🔍 [SCAN] Cannot scan - current user email is null");
            return;
        }
        
        Log.w(TAG, "🔍 [SCAN] ===== SCANNING FOR RECENT MESSAGES =====");
        Log.w(TAG, "🔍 [SCAN] Looking for messages with: hi, lower, abit");
        
        executorService.execute(() -> {
            try {
                // Get recent messages across ALL conversations
                String url = ApiKeys.SUPABASE_URL + "rest/v1/messages?select=*,conversations(*)" +
                        "&order=created_at.desc&limit=20";
                
                Log.w(TAG, "🔍 [SCAN] Query URL: " + url);
                
                Request request = new Request.Builder()
                        .url(url)
                        .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                try (Response response = httpClient.newCall(request).execute()) {
                    if (response.isSuccessful() && response.body() != null) {
                        String responseBody = response.body().string();
                        Log.w(TAG, "🔍 [SCAN] Raw response: " + responseBody.substring(0, Math.min(500, responseBody.length())) + "...");
                        
                        JSONArray messages = new JSONArray(responseBody);
                        Log.w(TAG, "🔍 [SCAN] Found " + messages.length() + " recent messages");
                        
                        for (int i = 0; i < messages.length(); i++) {
                            JSONObject msg = messages.getJSONObject(i);
                            String content = msg.optString("content").toLowerCase();
                            String sender = msg.optString("sender_email");
                            String conversationId = msg.optString("conversation_id");
                            String createdAt = msg.optString("created_at");
                            
                            // Look for test messages
                            if (content.contains("hi") || content.contains("lower") || content.contains("abit")) {
                                Log.w(TAG, "🔍 [SCAN] ⚡ FOUND POTENTIAL MESSAGE!");
                                Log.w(TAG, "🔍 [SCAN]   Content: '" + content + "'");
                                Log.w(TAG, "🔍 [SCAN]   From: " + sender);
                                Log.w(TAG, "🔍 [SCAN]   Conversation ID: " + conversationId);
                                Log.w(TAG, "🔍 [SCAN]   Created: " + createdAt);
                                Log.w(TAG, "🔍 [SCAN]   Currently monitored: " + messageListeners.containsKey(conversationId));
                                
                                // Check if this involves current user
                                if (!normalizeEmail(currentUserEmail).equals(normalizeEmail(sender))) {
                                    Log.w(TAG, "🔍 [SCAN] 🎯 THIS IS A LANDLORD MESSAGE WE'RE MISSING!");
                                }
                            }
                        }
                    } else {
                        Log.e(TAG, "🔍 [SCAN] Failed to get recent messages: " + response.code());
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "🔍 [SCAN] Error scanning recent messages", e);
            }
        });
    }
}