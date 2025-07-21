package com.roomfinderai.app.models;

public class ChatResponse {
    private String message;
    private String response;
    private boolean success;

    public ChatResponse() {}

    public ChatResponse(String message, String response, boolean success) {
        this.message = message;
        this.response = response;
        this.success = success;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getResponse() {
        return response;
    }

    public void setResponse(String response) {
        this.response = response;
    }

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }
}