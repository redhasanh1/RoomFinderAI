package com.roomfinderai.app.models;

import com.google.gson.annotations.SerializedName;

public class AuthRequest {
    @SerializedName("email")
    private String email;
    
    @SerializedName("password")
    private String password;
    
    @SerializedName("full_name")
    private String fullName;
    
    @SerializedName("code")
    private String code;

    // Default constructor
    public AuthRequest() {}

    // Constructor for login
    public AuthRequest(String email, String password) {
        this.email = email;
        this.password = password;
    }

    // Constructor for registration
    public AuthRequest(String email, String password, String fullName) {
        this.email = email;
        this.password = password;
        this.fullName = fullName;
    }

    // Constructor for verification
    public AuthRequest(String email, String code, boolean isVerification) {
        this.email = email;
        this.code = code;
    }

    // Getters and Setters
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }

    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }
}