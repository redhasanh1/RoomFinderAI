package com.roomfinderai.app.models;

import com.google.gson.annotations.SerializedName;
import java.util.List;

public class AIRequest {
    @SerializedName("message")
    private String message;
    
    @SerializedName("userEmail")
    private String userEmail;
    
    @SerializedName("conversationHistory")
    private List<ConversationMessage> conversationHistory;
    
    @SerializedName("user_id")
    private String userId;
    
    @SerializedName("session_id")
    private String sessionId;
    
    @SerializedName("context")
    private String context;
    
    @SerializedName("preferences")
    private UserPreferences preferences;

    // Default constructor
    public AIRequest() {}

    // Constructor for simple chat
    public AIRequest(String message, String userId) {
        this.message = message;
        this.userId = userId;
    }

    // Constructor with session
    public AIRequest(String message, String userId, String sessionId) {
        this.message = message;
        this.userId = userId;
        this.sessionId = sessionId;
    }
    
    // Constructor for backend AI negotiator
    public AIRequest(String message, String userEmail, List<ConversationMessage> conversationHistory) {
        this.message = message;
        this.userEmail = userEmail;
        this.conversationHistory = conversationHistory;
    }

    // Getters and Setters
    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public String getUserEmail() { return userEmail; }
    public void setUserEmail(String userEmail) { this.userEmail = userEmail; }
    
    public List<ConversationMessage> getConversationHistory() { return conversationHistory; }
    public void setConversationHistory(List<ConversationMessage> conversationHistory) { this.conversationHistory = conversationHistory; }

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    public String getSessionId() { return sessionId; }
    public void setSessionId(String sessionId) { this.sessionId = sessionId; }

    public String getContext() { return context; }
    public void setContext(String context) { this.context = context; }

    public UserPreferences getPreferences() { return preferences; }
    public void setPreferences(UserPreferences preferences) { this.preferences = preferences; }

    // Inner class for user preferences
    public static class UserPreferences {
        @SerializedName("max_budget")
        private double maxBudget;
        
        @SerializedName("preferred_location")
        private String preferredLocation;
        
        @SerializedName("bedrooms")
        private int bedrooms;
        
        @SerializedName("amenities")
        private List<String> amenities;

        public UserPreferences() {}

        // Getters and Setters
        public double getMaxBudget() { return maxBudget; }
        public void setMaxBudget(double maxBudget) { this.maxBudget = maxBudget; }

        public String getPreferredLocation() { return preferredLocation; }
        public void setPreferredLocation(String preferredLocation) { this.preferredLocation = preferredLocation; }

        public int getBedrooms() { return bedrooms; }
        public void setBedrooms(int bedrooms) { this.bedrooms = bedrooms; }

        public List<String> getAmenities() { return amenities; }
        public void setAmenities(List<String> amenities) { this.amenities = amenities; }
    }
    
    // Inner class for conversation messages
    public static class ConversationMessage {
        @SerializedName("role")
        private String role; // "user" or "assistant"
        
        @SerializedName("content")
        private String content;
        
        public ConversationMessage() {}
        
        public ConversationMessage(String role, String content) {
            this.role = role;
            this.content = content;
        }
        
        public String getRole() { return role; }
        public void setRole(String role) { this.role = role; }
        
        public String getContent() { return content; }
        public void setContent(String content) { this.content = content; }
    }
}