package com.roomfinder.android.auth;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Base64;
import android.util.Log;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.roomfinder.android.models.User;
import java.lang.reflect.Type;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;

/**
 * AuthManager - Android equivalent of universal-auth-manager.js
 * Provides consistent authentication state management across all activities.
 * Uses SharedPreferences as direct equivalent to localStorage.
 */
public class AuthManager {
    private static final String TAG = "AuthManager";
    private static final String PREFS_NAME = "RoomFinderAuth";
    private static final String KEY_CURRENT_USER = "currentUser";
    private static final String KEY_USERS = "users";
    
    private static AuthManager instance;
    private final SharedPreferences prefs;
    private final Gson gson;
    
    // Default profile image SVG (matching website exactly)
    public static final String DEFAULT_PROFILE_IMAGE = "data:image/svg+xml;base64," + 
        Base64.encodeToString(
            ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\" viewBox=\"0 0 100 100\">" +
             "<rect width=\"100\" height=\"100\" rx=\"50\" fill=\"#E5E7EB\"/>" +
             "<path d=\"M50 45C56.075 45 61 40.075 61 34C61 27.925 56.075 23 50 23C43.925 23 39 27.925 39 34C39 40.075 43.925 45 50 45Z\" fill=\"#9CA3AF\"/>" +
             "<path d=\"M30 77C30 77 30 66.103 30 62C30 55.373 36.268 50 44 50H56C63.732 50 70 55.373 70 62C70 66.103 70 77 70 77\" fill=\"#9CA3AF\"/>" +
             "</svg>").getBytes(), Base64.NO_WRAP
        );
    
    private AuthManager(Context context) {
        prefs = context.getApplicationContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        gson = new Gson();
    }
    
    public static synchronized AuthManager getInstance(Context context) {
        if (instance == null) {
            instance = new AuthManager(context);
        }
        return instance;
    }
    
    /**
     * Check if user is authenticated (matching website isUserAuthenticated())
     */
    public boolean isUserAuthenticated() {
        try {
            User currentUser = getCurrentUser();
            boolean hasUser = currentUser != null;
            boolean hasValidToken = hasUser && currentUser.getAccessToken() != null && 
                                  !currentUser.getAccessToken().isEmpty() && 
                                  !currentUser.getAccessToken().equals("null") &&
                                  !currentUser.getAccessToken().equals("undefined");
            
            boolean authenticated = hasUser && hasValidToken;
            Log.d(TAG, "isUserAuthenticated: " + authenticated + 
                      " (hasUser: " + hasUser + ", hasValidToken: " + hasValidToken + ")");
            
            if (hasUser && !hasValidToken) {
                Log.w(TAG, "User exists but no valid access token found. Generating tokens to upgrade account.");
                // Generate tokens for existing user instead of clearing session
                if (generateTokensForUser(currentUser)) {
                    // Re-check authentication after token generation
                    hasValidToken = currentUser.getAccessToken() != null && 
                                   !currentUser.getAccessToken().isEmpty() && 
                                   !currentUser.getAccessToken().equals("null") &&
                                   !currentUser.getAccessToken().equals("undefined");
                    authenticated = hasUser && hasValidToken;
                    Log.d(TAG, "Token generation successful. User now authenticated: " + authenticated);
                } else {
                    Log.e(TAG, "Token generation failed. Clearing invalid session.");
                    logout(); // Only logout if token generation fails
                }
            }
            
            return authenticated;
        } catch (Exception e) {
            Log.e(TAG, "Error checking authentication status", e);
            return false;
        }
    }
    
    /**
     * Get current user data (matching website getCurrentUser())
     */
    public User getCurrentUser() {
        try {
            String currentUserJson = prefs.getString(KEY_CURRENT_USER, null);
            if (currentUserJson == null || currentUserJson.equals("null") || currentUserJson.equals("undefined")) {
                return null;
            }
            
            User user = gson.fromJson(currentUserJson, User.class);
            Log.d(TAG, "getCurrentUser: " + (user != null ? user.getEmail() : "null"));
            return user;
        } catch (Exception error) {
            Log.e(TAG, "Error parsing current user", error);
            return null;
        }
    }
    
    /**
     * Get current user's email
     */
    public String getUserEmail() {
        User currentUser = getCurrentUser();
        return currentUser != null ? currentUser.getEmail() : null;
    }
    
    /**
     * Store current user (matching website localStorage.setItem('currentUser'))
     */
    public void storeCurrentUser(User user) {
        try {
            if (user == null) {
                prefs.edit().remove(KEY_CURRENT_USER).apply();
                Log.d(TAG, "Removed current user from storage");
                return;
            }
            
            // Ensure user has profile image
            if (user.getProfileImage() == null || user.getProfileImage().isEmpty()) {
                user.setProfileImage(DEFAULT_PROFILE_IMAGE);
            }
            
            String userJson = gson.toJson(user);
            prefs.edit().putString(KEY_CURRENT_USER, userJson).apply();
            
            // Also update users array
            updateUserInUsersArray(user);
            
            Log.d(TAG, "Stored current user: " + user.getEmail());
        } catch (Exception error) {
            Log.e(TAG, "Error storing current user", error);
        }
    }
    
    /**
     * Get stored profile image with fallback (matching website logic)
     */
    public String getStoredProfileImage(String email) {
        try {
            // Check multiple storage locations for profile image
            String profileImageKey = "profileImage_" + email;
            String storedImage = prefs.getString(profileImageKey, null);
            
            if (storedImage != null && !storedImage.equals("null") && !storedImage.equals("undefined")) {
                return storedImage;
            }
            
            // Check backup storage
            String backupKey = "profileImageBackup_" + email;
            String backupImage = prefs.getString(backupKey, null);
            
            if (backupImage != null && !backupImage.equals("null") && !backupImage.equals("undefined")) {
                return backupImage;
            }
            
            return null;
        } catch (Exception error) {
            Log.e(TAG, "Error retrieving stored profile image", error);
            return null;
        }
    }
    
    /**
     * Store profile image in multiple locations for persistence (matching website)
     */
    public void storeProfileImage(String email, String imageData) {
        try {
            String profileImageKey = "profileImage_" + email;
            String backupKey = "profileImageBackup_" + email;
            
            SharedPreferences.Editor editor = prefs.edit();
            editor.putString(profileImageKey, imageData);
            editor.putString(backupKey, imageData);
            editor.apply();
            
            Log.d(TAG, "Profile image stored successfully for: " + email);
        } catch (Exception error) {
            Log.e(TAG, "Error storing profile image", error);
        }
    }
    
    /**
     * Get all users from storage (matching website localStorage.getItem('users'))
     */
    public List<User> getAllUsers() {
        try {
            String usersJson = prefs.getString(KEY_USERS, null);
            if (usersJson == null || usersJson.isEmpty()) {
                return new ArrayList<>();
            }
            
            Type listType = new TypeToken<List<User>>(){}.getType();
            List<User> users = gson.fromJson(usersJson, listType);
            return users != null ? users : new ArrayList<>();
        } catch (Exception error) {
            Log.e(TAG, "Error parsing users from storage", error);
            return new ArrayList<>();
        }
    }
    
    /**
     * Save all users to storage (matching website localStorage.setItem('users'))
     */
    private void saveAllUsers(List<User> users) {
        try {
            String usersJson = gson.toJson(users);
            prefs.edit().putString(KEY_USERS, usersJson).apply();
            Log.d(TAG, "Saved " + users.size() + " users to storage");
        } catch (Exception error) {
            Log.e(TAG, "Error saving users to storage", error);
        }
    }
    
    /**
     * Update user in users array (matching website logic)
     */
    private void updateUserInUsersArray(User user) {
        try {
            List<User> users = getAllUsers();
            
            // Find existing user and update, or add new user
            boolean found = false;
            for (int i = 0; i < users.size(); i++) {
                User existingUser = users.get(i);
                if (existingUser != null && existingUser.getEmail() != null && 
                    existingUser.getEmail().equals(user.getEmail())) {
                    users.set(i, user);
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                users.add(user);
            }
            
            saveAllUsers(users);
        } catch (Exception error) {
            Log.e(TAG, "Error updating user in users array", error);
        }
    }
    
    /**
     * Find user by email in stored users (matching website logic)
     */
    public User findUserByEmail(String email) {
        try {
            List<User> users = getAllUsers();
            for (User user : users) {
                if (user != null && user.getEmail() != null && user.getEmail().equals(email)) {
                    return user;
                }
            }
            return null;
        } catch (Exception error) {
            Log.e(TAG, "Error finding user by email", error);
            return null;
        }
    }
    
    /**
     * Logout user (clear session)
     */
    public void logout() {
        try {
            prefs.edit().remove(KEY_CURRENT_USER).apply();
            Log.d(TAG, "User logged out successfully");
        } catch (Exception error) {
            Log.e(TAG, "Error during logout", error);
        }
    }
    
    /**
     * Complete logout with full session cleanup
     * This ensures no cached authentication data remains
     */
    public void completeLogout() {
        try {
            // Clear current user
            prefs.edit().remove(KEY_CURRENT_USER).apply();
            
            // Clear any other auth-related preferences that might be cached
            SharedPreferences.Editor editor = prefs.edit();
            String currentUserJson = prefs.getString(KEY_CURRENT_USER, null);
            if (currentUserJson != null) {
                try {
                    User user = gson.fromJson(currentUserJson, User.class);
                    if (user != null && user.getEmail() != null) {
                        // Clear profile image cache for this user
                        editor.remove("profileImage_" + user.getEmail());
                        editor.remove("profileImageBackup_" + user.getEmail());
                    }
                } catch (Exception e) {
                    Log.w(TAG, "Error clearing user-specific cache during logout", e);
                }
            }
            editor.apply();
            
            Log.d(TAG, "Complete logout performed successfully");
        } catch (Exception error) {
            Log.e(TAG, "Error during complete logout", error);
        }
    }
    
    /**
     * Clear all authentication data (for debugging/fixing login issues)
     */
    public void clearAllAuthData() {
        try {
            prefs.edit().clear().apply();
            Log.d(TAG, "Cleared all authentication data");
        } catch (Exception error) {
            Log.e(TAG, "Error clearing auth data", error);
        }
    }
    
    /**
     * Register new user (add to users array)
     */
    public void registerUser(User user) {
        try {
            if (user == null || user.getEmail() == null) {
                Log.w(TAG, "Cannot register null user or user without email");
                return;
            }
            
            // Set default profile image if not provided
            if (user.getProfileImage() == null || user.getProfileImage().isEmpty()) {
                user.setProfileImage(DEFAULT_PROFILE_IMAGE);
            }
            
            List<User> users = getAllUsers();
            
            // Check if user already exists to avoid duplicates
            boolean exists = false;
            for (int i = 0; i < users.size(); i++) {
                User existingUser = users.get(i);
                if (existingUser != null && existingUser.getEmail() != null && 
                    existingUser.getEmail().equals(user.getEmail())) {
                    // Update existing user
                    users.set(i, user);
                    exists = true;
                    break;
                }
            }
            
            if (!exists) {
                users.add(user);
            }
            
            saveAllUsers(users);
            Log.d(TAG, "User registered: " + user.getEmail());
        } catch (Exception error) {
            Log.e(TAG, "Error registering user", error);
        }
    }
    
    /**
     * Generate local tokens for existing users who don't have them
     * This upgrades old user accounts to work with the new authentication system
     */
    public boolean generateTokensForUser(User user) {
        try {
            if (user == null || user.getEmail() == null) {
                Log.w(TAG, "Cannot generate tokens for null user or user without email");
                return false;
            }
            
            // Generate tokens
            String accessToken = generateLocalToken(user.getEmail(), "access");
            String refreshToken = generateLocalToken(user.getEmail(), "refresh");
            
            // Set tokens on user
            user.setAccessToken(accessToken);
            user.setRefreshToken(refreshToken);
            
            // Update stored user
            storeCurrentUser(user);
            registerUser(user); // Update in users array too
            
            Log.d(TAG, "Generated tokens for user: " + user.getEmail());
            return true;
        } catch (Exception error) {
            Log.e(TAG, "Error generating tokens for user", error);
            return false;
        }
    }
    
    /**
     * Generate local token for authentication compatibility
     */
    private String generateLocalToken(String email, String type) {
        try {
            // Generate a simple but unique token for local auth
            String baseData = email + "_" + type + "_" + System.currentTimeMillis();
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hashBytes = md.digest(baseData.getBytes());
            StringBuilder sb = new StringBuilder();
            for (byte b : hashBytes) {
                sb.append(String.format("%02x", b));
            }
            // Return first 32 characters as token
            return "local_" + sb.toString().substring(0, 32);
        } catch (Exception e) {
            Log.e(TAG, "Error generating local token", e);
            // Fallback token
            return "local_" + email.hashCode() + "_" + type + "_" + System.currentTimeMillis();
        }
    }
}