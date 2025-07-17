package com.roomfinderai.app.models;

public class ChatRequest {
    private String message;
    private String userId;
    
    public ChatRequest(String message, String userId) {
        this.message = message;
        this.userId = userId;
    }
    
    public String getMessage() { return message; }
    public String getUserId() { return userId; }
}