package com.roomfinder.android.auth;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Base64;
import android.util.Log;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.roomfinder.android.models.User;
import java.lang.reflect.Type;
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
        String currentUser = prefs.getString(KEY_CURRENT_USER, null);
        boolean authenticated = currentUser != null && !currentUser.equals("null") && !currentUser.equals("undefined");
        Log.d(TAG, "isUserAuthenticated: " + authenticated);
        return authenticated;
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
}