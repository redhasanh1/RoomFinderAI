package com.roomfinder.android.services;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.roomfinder.android.models.ChatMessage;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class ChatStorageService {
    
    private static final String PREFS_NAME = "RoomFinderChatStorage";
    private static final String KEY_CONVERSATIONS = "conversations";
    private static final String KEY_MESSAGES_PREFIX = "messages_";
    
    // Callback interfaces for async operations
    public interface ConversationsCallback {
        void onConversationsLoaded(List<Conversation> conversations);
        void onError(String error);
    }
    
    public interface MessagesCallback {
        void onMessagesLoaded(List<ChatMessage> messages);
        void onError(String error);
    }
    
    private static ChatStorageService instance;
    private final SharedPreferences prefs;
    private final Gson gson;
    private final ExecutorService executor;
    private final Handler mainHandler;
    
    // Conversation metadata
    public static class Conversation {
        public String id;
        public String listingTitle;
        public String otherUserEmail;
        public String currentUserEmail;
        public String listingId;
        public String lastMessage;
        public long lastMessageTime;
        public int unreadCount;
        
        public Conversation() {}
        
        public Conversation(String id, String listingTitle, String otherUserEmail, 
                           String currentUserEmail, String listingId) {
            this.id = id;
            this.listingTitle = listingTitle;
            this.otherUserEmail = otherUserEmail;
            this.currentUserEmail = currentUserEmail;
            this.listingId = listingId;
            this.lastMessageTime = System.currentTimeMillis();
            this.unreadCount = 0;
        }
    }
    
    private ChatStorageService(Context context) {
        prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        gson = new Gson();
        executor = Executors.newFixedThreadPool(2); // Small thread pool for background operations
        mainHandler = new Handler(Looper.getMainLooper());
    }
    
    public static synchronized ChatStorageService getInstance(Context context) {
        if (instance == null) {
            instance = new ChatStorageService(context.getApplicationContext());
        }
        return instance;
    }
    
    // Generate unique conversation ID
    public String generateConversationId(String user1, String user2, String listingId) {
        // Sort emails to ensure consistent ID regardless of who initiates
        String email1 = user1.compareTo(user2) < 0 ? user1 : user2;
        String email2 = user1.compareTo(user2) < 0 ? user2 : user1;
        return email1 + "_" + email2 + "_" + listingId;
    }
    
    // Save a message to a conversation
    public void saveMessage(String conversationId, ChatMessage message) {
        String key = KEY_MESSAGES_PREFIX + conversationId;
        List<ChatMessage> messages = getMessages(conversationId);
        if (messages == null) {
            messages = new ArrayList<>();
        }
        messages.add(message);
        
        String json = gson.toJson(messages);
        prefs.edit().putString(key, json).apply();
    }
    
    // Get messages for a conversation (sync version)
    public List<ChatMessage> getMessages(String conversationId) {
        String key = KEY_MESSAGES_PREFIX + conversationId;
        String json = prefs.getString(key, null);
        if (json == null) {
            return new ArrayList<>();
        }
        
        Type type = new TypeToken<List<ChatMessage>>(){}.getType();
        return gson.fromJson(json, type);
    }
    
    // Get messages for a conversation (async version)
    public void getMessagesAsync(String conversationId, MessagesCallback callback) {
        executor.execute(() -> {
            try {
                List<ChatMessage> messages = getMessages(conversationId);
                mainHandler.post(() -> callback.onMessagesLoaded(messages));
            } catch (Exception e) {
                mainHandler.post(() -> callback.onError("Failed to load messages: " + e.getMessage()));
            }
        });
    }
    
    // Update or create conversation metadata
    public void updateConversation(String conversationId, String listingTitle, 
                                   String otherUserEmail, String currentUserEmail,
                                   String listingId, String lastMessage) {
        Map<String, Conversation> conversations = getAllConversations();
        
        Conversation conversation = conversations.get(conversationId);
        if (conversation == null) {
            conversation = new Conversation(conversationId, listingTitle, 
                                           otherUserEmail, currentUserEmail, listingId);
        }
        
        conversation.lastMessage = lastMessage;
        conversation.lastMessageTime = System.currentTimeMillis();
        
        conversations.put(conversationId, conversation);
        saveAllConversations(conversations);
    }
    
    // Get all conversations
    public Map<String, Conversation> getAllConversations() {
        String json = prefs.getString(KEY_CONVERSATIONS, null);
        if (json == null) {
            return new HashMap<>();
        }
        
        Type type = new TypeToken<Map<String, Conversation>>(){}.getType();
        Map<String, Conversation> conversations = gson.fromJson(json, type);
        return conversations != null ? conversations : new HashMap<>();
    }
    
    // Get conversations for a specific user (sync version)
    public List<Conversation> getUserConversations(String userEmail) {
        Map<String, Conversation> allConversations = getAllConversations();
        List<Conversation> userConversations = new ArrayList<>();
        
        for (Conversation conv : allConversations.values()) {
            if (conv.currentUserEmail != null && conv.currentUserEmail.equals(userEmail)) {
                userConversations.add(conv);
            }
        }
        
        // Sort by last message time (most recent first)
        userConversations.sort((a, b) -> Long.compare(b.lastMessageTime, a.lastMessageTime));
        
        return userConversations;
    }
    
    // Get conversations for a specific user (async version)
    public void getUserConversationsAsync(String userEmail, ConversationsCallback callback) {
        executor.execute(() -> {
            try {
                List<Conversation> userConversations = getUserConversations(userEmail);
                mainHandler.post(() -> callback.onConversationsLoaded(userConversations));
            } catch (Exception e) {
                mainHandler.post(() -> callback.onError("Failed to load conversations: " + e.getMessage()));
            }
        });
    }
    
    // Save all conversations
    private void saveAllConversations(Map<String, Conversation> conversations) {
        String json = gson.toJson(conversations);
        prefs.edit().putString(KEY_CONVERSATIONS, json).apply();
    }
    
    // Delete a conversation
    public void deleteConversation(String conversationId) {
        // Delete messages
        String messagesKey = KEY_MESSAGES_PREFIX + conversationId;
        prefs.edit().remove(messagesKey).apply();
        
        // Delete from conversations list
        Map<String, Conversation> conversations = getAllConversations();
        conversations.remove(conversationId);
        saveAllConversations(conversations);
    }
    
    // Mark conversation as read
    public void markAsRead(String conversationId) {
        Map<String, Conversation> conversations = getAllConversations();
        Conversation conversation = conversations.get(conversationId);
        if (conversation != null) {
            conversation.unreadCount = 0;
            saveAllConversations(conversations);
        }
    }
    
    // Increment unread count
    public void incrementUnreadCount(String conversationId) {
        Map<String, Conversation> conversations = getAllConversations();
        Conversation conversation = conversations.get(conversationId);
        if (conversation != null) {
            conversation.unreadCount++;
            saveAllConversations(conversations);
        }
    }
    
    // Get total unread count for a user
    public int getTotalUnreadCount(String userEmail) {
        List<Conversation> userConversations = getUserConversations(userEmail);
        int total = 0;
        for (Conversation conv : userConversations) {
            total += conv.unreadCount;
        }
        return total;
    }
    
    // Clear all chat data (for logout)
    public void clearAllData() {
        prefs.edit().clear().apply();
    }
    
    // Clean up resources (call when app is shutting down)
    public void shutdown() {
        if (executor != null && !executor.isShutdown()) {
            executor.shutdown();
        }
    }
}