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
        // This would be handled by the WebSocket connection
        // For now, we'll use polling as a fallback
        startMessagePolling();
    }
    
    /**
     * Start polling for new messages (fallback for real-time)
     */
    private void startMessagePolling() {
        executorService.scheduleWithFixedDelay(() -> {
            if (currentUserEmail != null) {
                checkForNewMessages();
            }
        }, 0, 3, TimeUnit.SECONDS);
    }
    
    /**
     * Check for new messages via polling
     */
    private void checkForNewMessages() {
        // Implementation would check for new messages
        // This is a simplified version
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
        
        if (currentUserEmail.equals(receiverEmail)) {
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
     * Find existing conversation
     */
    private Conversation findExistingConversation(String listingId, String receiverEmail) {
        try {
            String url = ApiKeys.SUPABASE_URL + "rest/v1/conversations?select=*" +
                    "&listing_id=eq." + listingId +
                    "&sender_email=eq." + currentUserEmail +
                    "&receiver_email=eq." + receiverEmail +
                    "&limit=1";
            
            Request request = new Request.Builder()
                    .url(url)
                    .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                    .addHeader("Content-Type", "application/json")
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
            Log.e(TAG, "Error finding existing conversation", e);
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
                        for (int i = 0; i < messagesArray.length(); i++) {
                            JSONObject messageJson = messagesArray.getJSONObject(i);
                            ChatMessage message = parseMessageFromJson(messageJson);
                            messages.add(message);
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
        messageListeners.put(conversationId, listener);
    }
    
    /**
     * Unregister message listener
     */
    public void unregisterMessageListener(String conversationId) {
        messageListeners.remove(conversationId);
    }
    
    /**
     * Notify message listeners
     */
    private void notifyMessageListeners(ChatMessage message) {
        String conversationId = message.getConversationId();
        MessageListener listener = messageListeners.get(conversationId);
        
        if (listener != null) {
            mainHandler.post(() -> listener.onMessageReceived(message));
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
}