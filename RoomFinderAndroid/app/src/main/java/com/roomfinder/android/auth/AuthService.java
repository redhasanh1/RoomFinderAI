package com.roomfinder.android.auth;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import com.google.gson.Gson;
import com.roomfinder.android.models.User;
import org.json.JSONObject;
import java.io.IOException;
import java.util.concurrent.TimeUnit;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

/**
 * AuthService - Handles API communication exactly like the website
 * Mirrors login.html API calls and response handling
 */
public class AuthService {
    private static final String TAG = "AuthService";
    private static AuthService instance;
    
    private final OkHttpClient httpClient;
    private final Gson gson;
    private final AuthManager authManager;
    private final LocalAuthService localAuthService;
    
    // API endpoints (matching website exactly)
    private static final String BASE_URL = "https://www.roomfinderai.com";
    private static final String LOGIN_URL = BASE_URL + "/api/login";
    private static final String SEND_VERIFICATION_URL = BASE_URL + "/api/send-verification";
    private static final String VERIFY_EMAIL_URL = BASE_URL + "/api/verify-email";
    private static final String FORGOT_PASSWORD_URL = BASE_URL + "/api/forgot-password";
    private static final String RESET_PASSWORD_URL = BASE_URL + "/api/reset-password";
    
    // Callback interfaces (matching website patterns)
    public interface AuthCallback {
        void onSuccess(User user);
        void onError(String error);
    }
    
    public interface VerificationCallback {
        void onSuccess(String message);
        void onError(String error);
    }
    
    public interface PasswordResetCallback {
        void onSuccess(String message);
        void onError(String error);
    }
    
    private AuthService(Context context) {
        this.authManager = AuthManager.getInstance(context);
        this.localAuthService = LocalAuthService.getInstance(context);
        this.gson = new Gson();
        this.httpClient = new OkHttpClient.Builder()
                .connectTimeout(10, TimeUnit.SECONDS)  // Increased timeout to allow real email service
                .readTimeout(10, TimeUnit.SECONDS)
                .writeTimeout(10, TimeUnit.SECONDS)
                .build();
    }
    
    public static synchronized AuthService getInstance(Context context) {
        if (instance == null) {
            instance = new AuthService(context);
        }
        return instance;
    }
    
    /**
     * Login with email and password (API first, then local fallback - matching website exactly)
     */
    public void login(String email, String password, AuthCallback callback) {
        Log.d(TAG, "Starting login for: " + email);
        
        // Try API first (matching website login.html logic)
        loginWithAPI(email, password, new AuthCallback() {
            @Override
            public void onSuccess(User user) {
                Log.d(TAG, "✅ API login successful");
                callback.onSuccess(user);
            }
            
            @Override
            public void onError(String apiError) {
                Log.d(TAG, "API login failed, trying local auth: " + apiError);
                // Fallback to local authentication if API fails
                localAuthService.loginLocal(email, password, callback);
            }
        });
    }
    
    
    /**
     * Login using API (matching website login.html exactly)
     */
    private void loginWithAPI(String email, String password, AuthCallback callback) {
        new Thread(() -> {
            try {
                // Create request body (matching website exactly)
                JSONObject requestData = new JSONObject();
                requestData.put("email", email);
                requestData.put("password", password);
                
                RequestBody body = RequestBody.create(
                    requestData.toString(),
                    MediaType.get("application/json")
                );
                
                Request request = new Request.Builder()
                        .url(LOGIN_URL)
                        .post(body)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                Log.d(TAG, "🌐 Executing login request to: " + LOGIN_URL);
                Log.d(TAG, "📧 Email: " + email);
                Log.d(TAG, "🔗 Request body: " + requestData.toString());
                
                try (Response response = httpClient.newCall(request).execute()) {
                    String responseBody = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "📱 Login response code: " + response.code());
                    Log.d(TAG, "📝 Response headers: " + response.headers().toString());
                    Log.d(TAG, "📄 Response body: " + responseBody);
                    Log.d(TAG, "✅ Is successful: " + response.isSuccessful());
                    
                    if (response.isSuccessful()) {
                        Log.d(TAG, "🎉 API login successful, processing response");
                        // Handle successful login with API response data
                        handleLoginSuccessWithApiResponse(responseBody, callback);
                    } else {
                        Log.e(TAG, "❌ API login failed with code: " + response.code());
                        
                        // Handle specific error codes gracefully
                        if (response.code() == 404) {
                            Log.w(TAG, "⚠️ API endpoint not found (404) - this is expected, falling back to local auth");
                            runOnMainThread(() -> callback.onError("API endpoint unavailable"));
                        } else {
                            Log.e(TAG, "❌ Response body: " + responseBody);
                            
                            // Handle other API errors
                            try {
                                JSONObject errorObj = new JSONObject(responseBody);
                                String error = errorObj.optString("error", "API Error: " + response.code() + " - " + response.message());
                                Log.e(TAG, "❌ Parsed error: " + error);
                                runOnMainThread(() -> callback.onError("API login failed: " + error));
                            } catch (Exception e) {
                                Log.e(TAG, "❌ Error parsing response: " + e.getMessage());
                                String error = "API Error: " + response.code() + " - " + response.message();
                                runOnMainThread(() -> callback.onError(error));
                            }
                        }
                    }
                }
                
            } catch (IOException e) {
                Log.e(TAG, "🌐 Network error during API login to " + LOGIN_URL, e);
                Log.e(TAG, "🌐 IOException details: " + e.getMessage());
                runOnMainThread(() -> callback.onError("Network error accessing " + LOGIN_URL + ": " + e.getMessage()));
            } catch (Exception e) {
                Log.e(TAG, "💥 Unexpected error during API login", e);
                Log.e(TAG, "💥 Exception details: " + e.getMessage());
                runOnMainThread(() -> callback.onError("API login failed: " + e.getMessage()));
            }
        }).start();
    }
    
    /**
     * Handle successful login with API response data
     */
    private void handleLoginSuccessWithApiResponse(String responseBody, AuthCallback callback) {
        try {
            Log.d(TAG, "Processing API login response: " + responseBody);
            
            JSONObject apiResponse = new JSONObject(responseBody);
            JSONObject userData = apiResponse.optJSONObject("user");
            
            if (userData != null) {
                // Create user from API response (matching website logic)
                User user = new User();
                user.setFirstName(userData.optString("firstName", "User"));
                user.setLastName(userData.optString("lastName", "Account"));
                user.setEmail(userData.optString("email"));
                user.setProfileImage(AuthManager.DEFAULT_PROFILE_IMAGE);
                user.setEmailVerified(true);
                
                // Set tokens if provided
                String accessToken = apiResponse.optString("access_token");
                if (!accessToken.isEmpty()) {
                    user.setAccessToken(accessToken);
                }
                
                // Initialize lists (matching website user structure)
                user.setAiChats(new java.util.ArrayList<>());
                user.setListings(new java.util.ArrayList<>());
                
                // Store user and complete authentication
                authManager.storeCurrentUser(user);
                Log.d(TAG, "API login successful for user: " + user.getFirstName() + " " + user.getLastName() + " (" + user.getEmail() + ")");
                runOnMainThread(() -> callback.onSuccess(user));
            } else {
                Log.e(TAG, "API response missing user data");
                runOnMainThread(() -> callback.onError("Invalid API response format"));
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error processing API login response", e);
            runOnMainThread(() -> callback.onError("Login processing failed"));
        }
    }
    
    /**
     * Handle successful login (matching website logic exactly)
     */
    private void handleLoginSuccess(String email, AuthCallback callback) {
        try {
            // First check if we have a currentUser that matches this email (website logic)
            User currentUser = authManager.getCurrentUser();
            if (currentUser != null && currentUser.getEmail().equals(email)) {
                // Use existing user data (preserves name and profile picture)
                authManager.storeCurrentUser(currentUser);
                Log.d(TAG, "Using existing currentUser data for: " + email);
                runOnMainThread(() -> callback.onSuccess(currentUser));
                return;
            }
            
            // Check users array for existing user (website logic)
            User existingUser = authManager.findUserByEmail(email);
            if (existingUser != null) {
                // Use existing user data (preserves name and profile picture)
                authManager.storeCurrentUser(existingUser);
                Log.d(TAG, "Using existing user data for: " + email);
                runOnMainThread(() -> callback.onSuccess(existingUser));
            } else {
                // Create basic user for backward compatibility (website logic)
                User newUser = new User();
                newUser.setFirstName("User");
                newUser.setLastName("Name");
                newUser.setEmail(email);
                newUser.setProfileImage(AuthManager.DEFAULT_PROFILE_IMAGE);
                newUser.setEmailVerified(true);
                // Initialize lists (matching website user structure)
                newUser.setAiChats(new java.util.ArrayList<>());
                newUser.setListings(new java.util.ArrayList<>());
                
                // Register and store user
                authManager.registerUser(newUser);
                authManager.storeCurrentUser(newUser);
                
                Log.d(TAG, "Created new user for: " + email);
                runOnMainThread(() -> callback.onSuccess(newUser));
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Error handling login success", e);
            runOnMainThread(() -> callback.onError("Login processing failed"));
        }
    }
    
    /**
     * Send verification email (API first, local fallback)
     */
    public void sendVerification(String firstName, String lastName, String email, String password, VerificationCallback callback) {
        Log.d(TAG, "Sending verification for: " + email);
        
        // Try API first, fallback to local auth
        sendVerificationWithAPI(firstName, lastName, email, password, new VerificationCallback() {
            @Override
            public void onSuccess(String message) {
                callback.onSuccess(message);
            }
            
            @Override
            public void onError(String error) {
                Log.d(TAG, "API verification failed, trying local auth: " + error);
                localAuthService.signupLocal(firstName, lastName, email, password, callback);
            }
        });
    }
    
    /**
     * Send verification using API (original implementation)
     */
    private void sendVerificationWithAPI(String firstName, String lastName, String email, String password, VerificationCallback callback) {
        new Thread(() -> {
            try {
                // Create request body (matching website exactly)
                JSONObject requestData = new JSONObject();
                requestData.put("firstName", firstName);
                requestData.put("lastName", lastName);
                requestData.put("email", email);
                requestData.put("password", password);
                
                RequestBody body = RequestBody.create(
                    requestData.toString(),
                    MediaType.get("application/json")
                );
                
                Request request = new Request.Builder()
                        .url(SEND_VERIFICATION_URL)
                        .post(body)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                Log.d(TAG, "Executing send verification request");
                
                try (Response response = httpClient.newCall(request).execute()) {
                    String responseBody = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "Send verification response code: " + response.code());
                    
                    if (response.isSuccessful()) {
                        JSONObject jsonResponse = new JSONObject(responseBody);
                        String message = jsonResponse.optString("message", "Verification email sent successfully");
                        runOnMainThread(() -> callback.onSuccess(message));
                    } else {
                        try {
                            JSONObject errorObj = new JSONObject(responseBody);
                            String error = errorObj.optString("error", "Failed to send verification email");
                            runOnMainThread(() -> callback.onError(error));
                        } catch (Exception e) {
                            runOnMainThread(() -> callback.onError("Failed to send verification email"));
                        }
                    }
                }
                
            } catch (IOException e) {
                Log.e(TAG, "Network error during send verification", e);
                runOnMainThread(() -> callback.onError("Network error: Please check your internet connection"));
            } catch (Exception e) {
                Log.e(TAG, "Send verification error", e);
                runOnMainThread(() -> callback.onError("Failed to send verification email: " + e.getMessage()));
            }
        }).start();
    }
    
    /**
     * Verify email with code (API first, local fallback)
     */
    public void verifyEmail(String email, String code, AuthCallback callback) {
        Log.d(TAG, "Verifying email for: " + email);
        
        // Try API first, fallback to local auth
        verifyEmailWithAPI(email, code, new AuthCallback() {
            @Override
            public void onSuccess(User user) {
                callback.onSuccess(user);
            }
            
            @Override
            public void onError(String error) {
                Log.d(TAG, "API email verification failed, trying local auth: " + error);
                localAuthService.verifyEmailLocal(email, code, callback);
            }
        });
    }
    
    /**
     * Verify email using API (original implementation)
     */
    private void verifyEmailWithAPI(String email, String code, AuthCallback callback) {
        new Thread(() -> {
            try {
                // Create request body (matching website exactly)
                JSONObject requestData = new JSONObject();
                requestData.put("email", email);
                requestData.put("code", code);
                
                RequestBody body = RequestBody.create(
                    requestData.toString(),
                    MediaType.get("application/json")
                );
                
                Request request = new Request.Builder()
                        .url(VERIFY_EMAIL_URL)
                        .post(body)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                Log.d(TAG, "Executing verify email request");
                
                try (Response response = httpClient.newCall(request).execute()) {
                    String responseBody = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "Verify email response code: " + response.code());
                    
                    if (response.isSuccessful()) {
                        // Email verified successfully - user should already be created by sendVerification
                        User existingUser = authManager.findUserByEmail(email);
                        if (existingUser != null) {
                            existingUser.setEmailVerified(true);
                            authManager.storeCurrentUser(existingUser);
                            runOnMainThread(() -> callback.onSuccess(existingUser));
                        } else {
                            // Fallback: create user (shouldn't happen but for safety)
                            User user = new User();
                            user.setEmail(email);
                            user.setFirstName("User");
                            user.setLastName("Name");
                            user.setProfileImage(AuthManager.DEFAULT_PROFILE_IMAGE);
                            user.setEmailVerified(true);
                            // Initialize lists (matching website user structure)
                            user.setAiChats(new java.util.ArrayList<>());
                            user.setListings(new java.util.ArrayList<>());
                            
                            authManager.registerUser(user);
                            authManager.storeCurrentUser(user);
                            runOnMainThread(() -> callback.onSuccess(user));
                        }
                    } else {
                        try {
                            JSONObject errorObj = new JSONObject(responseBody);
                            String error = errorObj.optString("error", "Email verification failed");
                            runOnMainThread(() -> callback.onError(error));
                        } catch (Exception e) {
                            runOnMainThread(() -> callback.onError("Email verification failed"));
                        }
                    }
                }
                
            } catch (IOException e) {
                Log.e(TAG, "Network error during verify email", e);
                runOnMainThread(() -> callback.onError("Network error: Please check your internet connection"));
            } catch (Exception e) {
                Log.e(TAG, "Verify email error", e);
                runOnMainThread(() -> callback.onError("Email verification failed: " + e.getMessage()));
            }
        }).start();
    }
    
    /**
     * Forgot password (matching website /api/forgot-password call)
     */
    public void forgotPassword(String email, PasswordResetCallback callback) {
        Log.d(TAG, "Requesting password reset for: " + email);
        
        new Thread(() -> {
            try {
                // Create request body (matching website exactly)
                JSONObject requestData = new JSONObject();
                requestData.put("email", email);
                
                RequestBody body = RequestBody.create(
                    requestData.toString(),
                    MediaType.get("application/json")
                );
                
                Request request = new Request.Builder()
                        .url(FORGOT_PASSWORD_URL)
                        .post(body)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                Log.d(TAG, "Executing forgot password request");
                
                try (Response response = httpClient.newCall(request).execute()) {
                    String responseBody = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "Forgot password response code: " + response.code());
                    
                    if (response.isSuccessful()) {
                        JSONObject jsonResponse = new JSONObject(responseBody);
                        String message = jsonResponse.optString("message", "Password reset email sent successfully");
                        runOnMainThread(() -> callback.onSuccess(message));
                    } else {
                        try {
                            JSONObject errorObj = new JSONObject(responseBody);
                            String error = errorObj.optString("error", "Failed to send password reset email");
                            runOnMainThread(() -> callback.onError(error));
                        } catch (Exception e) {
                            runOnMainThread(() -> callback.onError("Failed to send password reset email"));
                        }
                    }
                }
                
            } catch (IOException e) {
                Log.e(TAG, "Network error during forgot password", e);
                runOnMainThread(() -> callback.onError("Network error: Please check your internet connection"));
            } catch (Exception e) {
                Log.e(TAG, "Forgot password error", e);
                runOnMainThread(() -> callback.onError("Failed to send password reset email: " + e.getMessage()));
            }
        }).start();
    }
    
    /**
     * Reset password with token (matching website /api/reset-password call)
     */
    public void resetPassword(String token, String newPassword, PasswordResetCallback callback) {
        Log.d(TAG, "Resetting password with token");
        
        new Thread(() -> {
            try {
                // Create request body (matching website exactly)
                JSONObject requestData = new JSONObject();
                requestData.put("token", token);
                requestData.put("newPassword", newPassword);
                
                RequestBody body = RequestBody.create(
                    requestData.toString(),
                    MediaType.get("application/json")
                );
                
                Request request = new Request.Builder()
                        .url(RESET_PASSWORD_URL)
                        .post(body)
                        .addHeader("Content-Type", "application/json")
                        .build();
                
                Log.d(TAG, "Executing reset password request");
                
                try (Response response = httpClient.newCall(request).execute()) {
                    String responseBody = response.body() != null ? response.body().string() : "";
                    Log.d(TAG, "Reset password response code: " + response.code());
                    
                    if (response.isSuccessful()) {
                        JSONObject jsonResponse = new JSONObject(responseBody);
                        String message = jsonResponse.optString("message", "Password reset successfully");
                        runOnMainThread(() -> callback.onSuccess(message));
                    } else {
                        try {
                            JSONObject errorObj = new JSONObject(responseBody);
                            String error = errorObj.optString("error", "Failed to reset password");
                            runOnMainThread(() -> callback.onError(error));
                        } catch (Exception e) {
                            runOnMainThread(() -> callback.onError("Failed to reset password"));
                        }
                    }
                }
                
            } catch (IOException e) {
                Log.e(TAG, "Network error during reset password", e);
                runOnMainThread(() -> callback.onError("Network error: Please check your internet connection"));
            } catch (Exception e) {
                Log.e(TAG, "Reset password error", e);
                runOnMainThread(() -> callback.onError("Failed to reset password: " + e.getMessage()));
            }
        }).start();
    }
    
    /**
     * Helper method to run code on main thread
     */
    private void runOnMainThread(Runnable runnable) {
        new Handler(Looper.getMainLooper()).post(runnable);
    }
}