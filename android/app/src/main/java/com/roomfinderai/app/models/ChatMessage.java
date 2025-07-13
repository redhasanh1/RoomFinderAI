package com.roomfinderai.app.models;

import com.google.gson.annotations.SerializedName;

public class ChatMessage {
    @SerializedName("id")
    private String id;
    
    @SerializedName("message")
    private String message;
    
    @SerializedName("is_user")
    private boolean isUser;
    
    @SerializedName("timestamp")
    private String timestamp;
    
    @SerializedName("user_id")
    private String userId;
    
    @SerializedName("session_id")
    private String sessionId;
    
    @SerializedName("created_at")
    private String createdAt;

    // Default constructor
    public ChatMessage() {}

    // Constructor for user messages
    public ChatMessage(String message, boolean isUser) {
        this.message = message;
        this.isUser = isUser;
        this.timestamp = String.valueOf(System.currentTimeMillis());
    }

    // Full constructor
    public ChatMessage(String id, String message, boolean isUser, String timestamp, String userId) {
        this.id = id;
        this.message = message;
        this.isUser = isUser;
        this.timestamp = timestamp;
        this.userId = userId;
    }

    // Getters and Setters
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public boolean isUser() { return isUser; }
    public void setUser(boolean user) { isUser = user; }

    public String getTimestamp() { return timestamp; }
    public void setTimestamp(String timestamp) { this.timestamp = timestamp; }

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    public String getSessionId() { return sessionId; }
    public void setSessionId(String sessionId) { this.sessionId = sessionId; }

    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }
}