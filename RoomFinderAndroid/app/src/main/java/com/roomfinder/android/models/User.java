package com.roomfinder.android.models;

import com.google.gson.annotations.SerializedName;

public class User {
    @SerializedName("id")
    private String id;
    
    @SerializedName("email")
    private String email;
    
    @SerializedName("firstName")
    private String firstName;
    
    @SerializedName("lastName") 
    private String lastName;
    
    @SerializedName("profileImage")
    private String profileImage;
    
    @SerializedName("created_at")
    private String createdAt;
    
    @SerializedName("last_sign_in")
    private String lastSignIn;
    
    @SerializedName("updated_at")
    private String updatedAt;
    
    @SerializedName("emailVerified")
    private boolean emailVerified;
    
    // Authentication tokens
    @SerializedName("accessToken")
    private String accessToken;
    
    @SerializedName("refreshToken")
    private String refreshToken;
    
    // Additional fields matching website user structure
    @SerializedName("aiChats")
    private java.util.List<Object> aiChats;
    
    @SerializedName("listings")
    private java.util.List<Object> listings;
    
    // Constructors
    public User() {
        this.aiChats = new java.util.ArrayList<>();
        this.listings = new java.util.ArrayList<>();
    }
    
    public User(String id, String email, String firstName, String lastName, 
                String profileImage, boolean emailVerified) {
        this.id = id;
        this.email = email;
        this.firstName = firstName;
        this.lastName = lastName;
        this.profileImage = profileImage;
        this.emailVerified = emailVerified;
        this.aiChats = new java.util.ArrayList<>();
        this.listings = new java.util.ArrayList<>();
        this.createdAt = getCurrentTimestamp();
        this.updatedAt = getCurrentTimestamp();
    }
    
    // Getters and Setters
    public String getId() {
        return id;
    }
    
    public void setId(String id) {
        this.id = id;
    }
    
    public String getEmail() {
        return email;
    }
    
    public void setEmail(String email) {
        this.email = email;
    }
    
    public String getFirstName() {
        return firstName;
    }
    
    public void setFirstName(String firstName) {
        this.firstName = firstName;
    }
    
    public String getLastName() {
        return lastName;
    }
    
    public void setLastName(String lastName) {
        this.lastName = lastName;
    }
    
    public String getProfileImage() {
        return profileImage;
    }
    
    public void setProfileImage(String profileImage) {
        this.profileImage = profileImage;
    }
    
    public String getCreatedAt() {
        return createdAt;
    }
    
    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }
    
    public String getLastSignIn() {
        return lastSignIn;
    }
    
    public void setLastSignIn(String lastSignIn) {
        this.lastSignIn = lastSignIn;
    }
    
    public String getUpdatedAt() {
        return updatedAt;
    }
    
    public void setUpdatedAt(String updatedAt) {
        this.updatedAt = updatedAt;
    }
    
    public boolean isEmailVerified() {
        return emailVerified;
    }
    
    public void setEmailVerified(boolean emailVerified) {
        this.emailVerified = emailVerified;
    }
    
    public String getAccessToken() {
        return accessToken;
    }
    
    public void setAccessToken(String accessToken) {
        this.accessToken = accessToken;
    }
    
    public String getRefreshToken() {
        return refreshToken;
    }
    
    public void setRefreshToken(String refreshToken) {
        this.refreshToken = refreshToken;
    }
    
    public java.util.List<Object> getAiChats() {
        return aiChats != null ? aiChats : new java.util.ArrayList<>();
    }
    
    public void setAiChats(java.util.List<Object> aiChats) {
        this.aiChats = aiChats;
    }
    
    public java.util.List<Object> getListings() {
        return listings != null ? listings : new java.util.ArrayList<>();
    }
    
    public void setListings(java.util.List<Object> listings) {
        this.listings = listings;
    }
    
    // Helper methods
    public String getFullName() {
        if (firstName != null && lastName != null) {
            return firstName + " " + lastName;
        } else if (firstName != null) {
            return firstName;
        } else if (lastName != null) {
            return lastName;
        } else {
            return email != null ? email.split("@")[0] : "User";
        }
    }
    
    public String getDisplayName() {
        return getFullName();
    }
    
    /**
     * Generate profile image URL based on email (matching website logic)
     */
    public static String generateProfileImageUrl(String email) {
        if (email == null || email.isEmpty()) {
            return "https://via.placeholder.com/40";
        }
        
        try {
            // Convert email to base64 and create hash (matching website logic)
            String hash = android.util.Base64.encodeToString(
                email.getBytes(), android.util.Base64.NO_WRAP)
                .replaceAll("[^a-zA-Z0-9]", "")
                .substring(0, Math.min(10, email.length()));
            
            return "https://api.dicebear.com/6.x/initials/svg?seed=" + hash + 
                   "&backgroundColor=667eea,764ba2,f093fb,4f46e5,06b6d4&textColor=ffffff";
        } catch (Exception e) {
            return "https://via.placeholder.com/40";
        }
    }
    
    private String getCurrentTimestamp() {
        return java.time.Instant.now().toString();
    }
    
    @Override
    public String toString() {
        return "User{" +
                "id='" + id + '\'' +
                ", email='" + email + '\'' +
                ", firstName='" + firstName + '\'' +
                ", lastName='" + lastName + '\'' +
                ", emailVerified=" + emailVerified +
                '}';
    }
}