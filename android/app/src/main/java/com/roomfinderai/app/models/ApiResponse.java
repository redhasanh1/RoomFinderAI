package com.roomfinderai.app.models;

import com.google.gson.annotations.SerializedName;

public class ApiResponse<T> {
    @SerializedName("success")
    private boolean success;
    
    @SerializedName("data")
    private T data;
    
    @SerializedName("message")
    private String message;
    
    @SerializedName("error")
    private String error;
    
    @SerializedName("code")
    private int code;

    // Default constructor
    public ApiResponse() {}

    // Constructor for success response
    public ApiResponse(boolean success, T data, String message) {
        this.success = success;
        this.data = data;
        this.message = message;
    }

    // Constructor for error response
    public ApiResponse(boolean success, String error, int code) {
        this.success = success;
        this.error = error;
        this.code = code;
    }

    // Getters and Setters
    public boolean isSuccess() { return success; }
    public void setSuccess(boolean success) { this.success = success; }

    public T getData() { return data; }
    public void setData(T data) { this.data = data; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public String getError() { return error; }
    public void setError(String error) { this.error = error; }

    public int getCode() { return code; }
    public void setCode(int code) { this.code = code; }
}