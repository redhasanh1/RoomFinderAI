package com.roomfinderai.app.models;

import com.google.gson.annotations.SerializedName;

public class User {
    @SerializedName("id")
    private String id;
    
    @SerializedName("email")
    private String email;
    
    @SerializedName("full_name")
    private String fullName;
    
    @SerializedName("phone")
    private String phone;
    
    @SerializedName("avatar_url")
    private String avatarUrl;
    
    @SerializedName("created_at")
    private String createdAt;
    
    @SerializedName("updated_at")
    private String updatedAt;
    
    @SerializedName("email_verified")
    private boolean emailVerified;
    
    @SerializedName("profile_image")
    private String profileImage;

    // Default constructor
    public User() {}

    // Constructor
    public User(String email, String fullName) {
        this.email = email;
        this.fullName = fullName;
        this.emailVerified = false;
    }

    // Getters and Setters
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }

    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }

    public String getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(String updatedAt) { this.updatedAt = updatedAt; }

    public boolean isEmailVerified() { return emailVerified; }
    public void setEmailVerified(boolean emailVerified) { this.emailVerified = emailVerified; }

    public String getProfileImage() { return profileImage; }
    public void setProfileImage(String profileImage) { this.profileImage = profileImage; }
}