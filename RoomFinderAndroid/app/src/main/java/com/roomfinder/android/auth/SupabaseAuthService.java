package com.roomfinder.android.auth;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import com.google.gson.Gson;
import com.roomfinder.android.models.User;
import com.roomfinder.android.utils.ApiKeys;

import org.json.JSONObject;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class SupabaseAuthService {
    private static final String TAG = "SupabaseAuthService";
    private static SupabaseAuthService instance;
    
    private final OkHttpClient httpClient;
    private final Gson gson;
    private final Context context;
    private final SharedPreferences sharedPrefs;
    
    // Auth endpoints
    private final String baseUrl;
    private final String signUpUrl;
    private final String signInUrl;
    private final String signOutUrl;
    private final String sessionUrl;
    
    private User currentUser;
    
    public interface AuthCallback {
        void onSuccess(User user);
        void onError(String error);
    }
    
    public interface SignOutCallback {
        void onSuccess();
        void onError(String error);
    }
    
    private SupabaseAuthService(Context context) {
        this.context = context.getApplicationContext();
        this.sharedPrefs = context.getSharedPreferences("roomfinder_auth", Context.MODE_PRIVATE);
        this.gson = new Gson();
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build();
        
        // Set up URLs
        this.baseUrl = ApiKeys.SUPABASE_URL + "auth/v1/";
        this.signUpUrl = baseUrl + "signup";
        this.signInUrl = baseUrl + "token?grant_type=password";
        this.signOutUrl = baseUrl + "logout";
        this.sessionUrl = baseUrl + "user";
        
        // Try to restore session on initialization
        restoreSession();
    }
    
    public static synchronized SupabaseAuthService getInstance(Context context) {
        if (instance == null) {
            instance = new SupabaseAuthService(context);
        }
        return instance;
    }
    
    /**
     * Sign up with email and password
     */
    public void signUp(String email, String password, String firstName, String lastName, AuthCallback callback) {
        new Thread(() -> {
            try {
                Log.d(TAG, "Signing up user: " + email);
                
                JSONObject requestData = new JSONObject();
                requestData.put("email", email);
                requestData.put("password", password);
                requestData.put("data", new JSONObject()
                        .put("first_name", firstName)
                        .put("last_name", lastName));
                
                RequestBody body = RequestBody.create(
                    requestData.toString(),
                    MediaType.get("application/json")
                );
                
                Request request = new Request.Builder()
                        .url(signUpUrl)
                        .post(body)
                        .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                try (Response response = httpClient.newCall(request).execute()) {
                    String responseBody = response.body().string();
                    Log.d(TAG, "Sign up response: " + responseBody);
                    
                    if (response.isSuccessful()) {
                        JSONObject jsonResponse = new JSONObject(responseBody);
                        
                        // Check if response has user nested or is the user object directly
                        JSONObject userObj = null;
                        if (jsonResponse.has("user")) {
                            userObj = jsonResponse.getJSONObject("user");
                        } else if (jsonResponse.has("id") && jsonResponse.has("email")) {
                            // Response is the user object directly
                            userObj = jsonResponse;
                        }
                        
                        if (userObj != null) {
                            User user = createUserFromJson(userObj, firstName, lastName);
                            
                            // Save session if access token present
                            if (jsonResponse.has("access_token")) {
                                String accessToken = jsonResponse.getString("access_token");
                                String refreshToken = jsonResponse.optString("refresh_token", "");
                                saveSession(user, accessToken, refreshToken);
                            }
                            
                            // Create profile in database
                            createUserProfile(user);
                            
                            currentUser = user;
                            
                            // Check if email verification needed
                            boolean emailVerified = userObj.optBoolean("email_confirmed_at") || 
                                                  userObj.optBoolean("email_verified", false);
                            
                            // Post back to main thread
                            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                                callback.onSuccess(user));
                        } else {
                            String error = jsonResponse.optString("msg", "Sign up failed");
                            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                                callback.onError(error));
                        }
                    } else {
                        try {
                            JSONObject errorObj = new JSONObject(responseBody);
                            String error = errorObj.optString("msg", "Sign up failed");
                            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                                callback.onError(error));
                        } catch (Exception e) {
                            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                                callback.onError("Sign up failed: " + response.code()));
                        }
                    }
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Sign up error: " + e.getMessage(), e);
                new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                    callback.onError("Sign up failed: " + e.getMessage()));
            }
        }).start();
    }
    
    /**
     * Sign in with email and password
     */
    public void signIn(String email, String password, AuthCallback callback) {
        new Thread(() -> {
            try {
                Log.d(TAG, "Signing in user: " + email);
                
                JSONObject requestData = new JSONObject();
                requestData.put("email", email);
                requestData.put("password", password);
                
                RequestBody body = RequestBody.create(
                    requestData.toString(),
                    MediaType.get("application/json")
                );
                
                Request request = new Request.Builder()
                        .url(signInUrl)
                        .post(body)
                        .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                try (Response response = httpClient.newCall(request).execute()) {
                    String responseBody = response.body().string();
                    Log.d(TAG, "Sign in response code: " + response.code());
                    
                    if (response.isSuccessful()) {
                        JSONObject jsonResponse = new JSONObject(responseBody);
                        
                        if (jsonResponse.has("user")) {
                            JSONObject userObj = jsonResponse.getJSONObject("user");
                            User user = createUserFromJson(userObj, null, null);
                            
                            // Save session
                            if (jsonResponse.has("access_token")) {
                                String accessToken = jsonResponse.getString("access_token");
                                String refreshToken = jsonResponse.optString("refresh_token", "");
                                saveSession(user, accessToken, refreshToken);
                            }
                            
                            // Update last sign in
                            updateUserProfile(user);
                            
                            currentUser = user;
                            
                            // Post back to main thread
                            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                                callback.onSuccess(user));
                        } else {
                            String error = jsonResponse.optString("error_description", "Sign in failed");
                            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                                callback.onError(error));
                        }
                    } else {
                        try {
                            JSONObject errorObj = new JSONObject(responseBody);
                            String error = errorObj.optString("error_description", "Invalid email or password");
                            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                                callback.onError(error));
                        } catch (Exception e) {
                            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                                callback.onError("Invalid email or password"));
                        }
                    }
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Sign in error: " + e.getMessage(), e);
                new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                    callback.onError("Sign in failed: " + e.getMessage()));
            }
        }).start();
    }
    
    /**
     * Sign out current user
     */
    public void signOut(SignOutCallback callback) {
        new Thread(() -> {
            try {
                String accessToken = sharedPrefs.getString("access_token", "");
                
                if (!accessToken.isEmpty()) {
                    Request request = new Request.Builder()
                            .url(signOutUrl)
                            .post(RequestBody.create("", MediaType.get("application/json")))
                            .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                            .addHeader("Authorization", "Bearer " + accessToken)
                            .build();
                    
                    try (Response response = httpClient.newCall(request).execute()) {
                        Log.d(TAG, "Sign out response: " + response.code());
                    }
                }
                
                // Clear local session regardless of API response
                clearSession();
                currentUser = null;
                
                new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                    callback.onSuccess());
                
            } catch (Exception e) {
                Log.e(TAG, "Sign out error: " + e.getMessage(), e);
                // Still clear local session on error
                clearSession();
                currentUser = null;
                
                new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> 
                    callback.onSuccess());
            }
        }).start();
    }
    
    /**
     * Get current user
     */
    public User getCurrentUser() {
        return currentUser;
    }
    
    /**
     * Check if user is authenticated
     */
    public boolean isAuthenticated() {
        return currentUser != null && !getAccessToken().isEmpty();
    }
    
    /**
     * Get access token
     */
    public String getAccessToken() {
        return sharedPrefs.getString("access_token", "");
    }
    
    private User createUserFromJson(JSONObject userObj, String firstName, String lastName) throws Exception {
        String id = userObj.getString("id");
        String email = userObj.getString("email");
        boolean emailVerified = userObj.optBoolean("email_confirmed_at") || 
                               userObj.optBoolean("email_verified", false);
        
        // Try to get name from user metadata first
        String fName = firstName;
        String lName = lastName;
        
        if (userObj.has("user_metadata")) {
            JSONObject metadata = userObj.getJSONObject("user_metadata");
            if (fName == null) fName = metadata.optString("first_name", "");
            if (lName == null) lName = metadata.optString("last_name", "");
        }
        
        // Fallback to email username if no names provided
        if ((fName == null || fName.isEmpty()) && (lName == null || lName.isEmpty())) {
            String username = email.split("@")[0];
            fName = username;
            lName = "";
        }
        
        String profileImage = User.generateProfileImageUrl(email);
        
        User user = new User(id, email, fName, lName, profileImage, emailVerified);
        user.setCreatedAt(userObj.optString("created_at", ""));
        user.setLastSignIn(userObj.optString("last_sign_in_at", ""));
        user.setUpdatedAt(userObj.optString("updated_at", ""));
        
        return user;
    }
    
    private void saveSession(User user, String accessToken, String refreshToken) {
        SharedPreferences.Editor editor = sharedPrefs.edit();
        editor.putString("user", gson.toJson(user));
        editor.putString("access_token", accessToken);
        editor.putString("refresh_token", refreshToken);
        editor.putLong("session_timestamp", System.currentTimeMillis());
        editor.apply();
        
        Log.d(TAG, "Session saved for user: " + user.getEmail());
    }
    
    private void restoreSession() {
        try {
            String userJson = sharedPrefs.getString("user", "");
            String accessToken = sharedPrefs.getString("access_token", "");
            long sessionTimestamp = sharedPrefs.getLong("session_timestamp", 0);
            
            // Check if session is less than 7 days old
            long sessionAge = System.currentTimeMillis() - sessionTimestamp;
            long maxAge = 7 * 24 * 60 * 60 * 1000L; // 7 days
            
            if (!userJson.isEmpty() && !accessToken.isEmpty() && sessionAge < maxAge) {
                currentUser = gson.fromJson(userJson, User.class);
                Log.d(TAG, "Session restored for user: " + currentUser.getEmail());
            } else {
                Log.d(TAG, "No valid session to restore");
                clearSession();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error restoring session: " + e.getMessage(), e);
            clearSession();
        }
    }
    
    private void clearSession() {
        SharedPreferences.Editor editor = sharedPrefs.edit();
        editor.clear();
        editor.apply();
        Log.d(TAG, "Session cleared");
    }
    
    private void createUserProfile(User user) {
        // Create profile in user_profiles table (matching website)
        new Thread(() -> {
            try {
                JSONObject profileData = new JSONObject();
                profileData.put("id", user.getId());
                profileData.put("email", user.getEmail());
                profileData.put("profile_image", user.getProfileImage());
                profileData.put("last_sign_in", getCurrentTimestamp());
                profileData.put("updated_at", getCurrentTimestamp());
                
                RequestBody body = RequestBody.create(
                    profileData.toString(),
                    MediaType.get("application/json")
                );
                
                String url = ApiKeys.SUPABASE_URL + "rest/v1/user_profiles";
                Request request = new Request.Builder()
                        .url(url)
                        .post(body)
                        .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", "application/json")
                        .addHeader("Prefer", "resolution=merge-duplicates")
                        .build();
                
                try (Response response = httpClient.newCall(request).execute()) {
                    if (response.isSuccessful()) {
                        Log.d(TAG, "User profile created successfully");
                    } else {
                        Log.w(TAG, "Failed to create user profile: " + response.code());
                    }
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error creating user profile: " + e.getMessage(), e);
            }
        }).start();
    }
    
    private void updateUserProfile(User user) {
        // Update last_sign_in in user_profiles table
        new Thread(() -> {
            try {
                JSONObject updateData = new JSONObject();
                updateData.put("last_sign_in", getCurrentTimestamp());
                updateData.put("updated_at", getCurrentTimestamp());
                
                RequestBody body = RequestBody.create(
                    updateData.toString(),
                    MediaType.get("application/json")
                );
                
                String url = ApiKeys.SUPABASE_URL + "rest/v1/user_profiles?id=eq." + user.getId();
                Request request = new Request.Builder()
                        .url(url)
                        .patch(body)
                        .addHeader("apikey", ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                try (Response response = httpClient.newCall(request).execute()) {
                    if (response.isSuccessful()) {
                        Log.d(TAG, "User profile updated successfully");
                    } else {
                        Log.w(TAG, "Failed to update user profile: " + response.code());
                    }
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error updating user profile: " + e.getMessage(), e);
            }
        }).start();
    }
    
    private String getCurrentTimestamp() {
        return java.time.Instant.now().toString();
    }
}