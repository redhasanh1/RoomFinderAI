package com.roomfinder.android.auth;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.roomfinder.android.models.User;
import com.roomfinder.android.services.EmailService;
import java.lang.reflect.Type;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * LocalAuthService - Offline-first authentication system
 * Works without backend API calls for immediate app functionality
 */
public class LocalAuthService {
    private static final String TAG = "LocalAuthService";
    private static LocalAuthService instance;
    
    private final SharedPreferences prefs;
    private final Gson gson;
    private final AuthManager authManager;
    private final EmailService emailService;
    
    // Local storage keys
    private static final String PREFS_NAME = "LocalAuth";
    private static final String KEY_REGISTERED_USERS = "registeredUsers";
    private static final String KEY_VERIFICATION_CODES = "verificationCodes";
    
    // Demo accounts for testing
    private static final Map<String, String> DEMO_ACCOUNTS = new HashMap<>();
    static {
        DEMO_ACCOUNTS.put("demo@roomfinder.com", "demo123");
        DEMO_ACCOUNTS.put("test@roomfinder.com", "test123");
        DEMO_ACCOUNTS.put("user@example.com", "password123");
        DEMO_ACCOUNTS.put("humblewoslayer@gmail.com", "bigboy123"); // Test account with real credentials
    }
    
    private LocalAuthService(Context context) {
        prefs = context.getApplicationContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        gson = new Gson();
        authManager = AuthManager.getInstance(context);
        emailService = EmailService.getInstance(context);
        
        // Demo accounts will only be initialized if no real users exist
        // This is handled automatically when needed
    }
    
    public static synchronized LocalAuthService getInstance(Context context) {
        if (instance == null) {
            instance = new LocalAuthService(context);
        }
        return instance;
    }
    
    /**
     * Force reinitialize demo accounts (for debugging)
     */
    public void forceReinitializeDemoAccounts() {
        Log.d(TAG, "Force reinitializing demo accounts...");
        List<User> registeredUsers = getRegisteredUsers();
        
        // Remove any existing demo accounts first
        registeredUsers.removeIf(user -> DEMO_ACCOUNTS.containsKey(user.getEmail()));
        
        // Clear password hashes for demo accounts
        SharedPreferences.Editor editor = prefs.edit();
        for (String email : DEMO_ACCOUNTS.keySet()) {
            editor.remove("pwd_" + email);
        }
        editor.apply();
        
        // Re-add all demo accounts
        for (Map.Entry<String, String> demoAccount : DEMO_ACCOUNTS.entrySet()) {
            String email = demoAccount.getKey();
            String password = demoAccount.getValue();
            
            // Create demo user with proper names for test account
            User demoUser = new User();
            demoUser.setEmail(email);
            if (email.equals("humblewoslayer@gmail.com")) {
                demoUser.setFirstName("Humble");
                demoUser.setLastName("Woslayer");
            } else {
                demoUser.setFirstName("Demo");
                demoUser.setLastName("User");
            }
            demoUser.setProfileImage(AuthManager.DEFAULT_PROFILE_IMAGE);
            demoUser.setEmailVerified(true);
            
            // Hash password
            String hashedPassword = hashPassword(password);
            
            // Store user with hashed password
            registeredUsers.add(demoUser);
            
            // Store password hash separately
            prefs.edit().putString("pwd_" + email, hashedPassword).apply();
            
            Log.d(TAG, "Force created demo account: " + email);
        }
        
        saveRegisteredUsers(registeredUsers);
        Log.d(TAG, "Demo accounts reinitialization complete");
    }
    
    /**
     * Initialize demo accounts for testing (only if no users exist at all)
     * This method is now only called manually when needed for testing
     */
    public void initializeDemoAccountsIfEmpty() {
        List<User> registeredUsers = getRegisteredUsers();
        
        // Only initialize demo accounts if NO users exist at all
        if (!registeredUsers.isEmpty()) {
            Log.d(TAG, "Users already exist (" + registeredUsers.size() + "), skipping demo account initialization");
            return;
        }
        
        Log.d(TAG, "No users found, initializing demo accounts for testing");
        
        for (Map.Entry<String, String> demoAccount : DEMO_ACCOUNTS.entrySet()) {
            String email = demoAccount.getKey();
            String password = demoAccount.getValue();
            
            // Create demo user with proper names for test account
            User demoUser = new User();
            demoUser.setEmail(email);
            if (email.equals("humblewoslayer@gmail.com")) {
                demoUser.setFirstName("Humble");
                demoUser.setLastName("Woslayer");
            } else {
                demoUser.setFirstName("Demo");
                demoUser.setLastName("User");
            }
            demoUser.setProfileImage(AuthManager.DEFAULT_PROFILE_IMAGE);
            demoUser.setEmailVerified(true);
            
            // Hash password
            String hashedPassword = hashPassword(password);
            
            // Store user with hashed password
            registeredUsers.add(demoUser);
            
            // Store password hash separately
            prefs.edit().putString("pwd_" + email, hashedPassword).apply();
            
            Log.d(TAG, "Created demo account: " + email);
        }
        
        // Save all demo users at once
        saveRegisteredUsers(registeredUsers);
        Log.d(TAG, "Demo account initialization complete");
    }
    
    /**
     * Local login (offline)
     */
    public void loginLocal(String email, String password, AuthService.AuthCallback callback) {
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            try {
                Log.d(TAG, "Local login attempt for: " + email);
                
                // Check registered users
                List<User> registeredUsers = getRegisteredUsers();
                Log.d(TAG, "Found " + registeredUsers.size() + " registered users");
                
                // Log all registered users for debugging
                for (User u : registeredUsers) {
                    Log.d(TAG, "Registered user: " + u.getEmail());
                }
                
                User user = registeredUsers.stream()
                        .filter(u -> u.getEmail().equals(email))
                        .findFirst()
                        .orElse(null);
                
                if (user == null) {
                    Log.w(TAG, "User not found in registered users: " + email);
                    callback.onError("Account not found. Please sign up first.");
                    return;
                }
                
                Log.d(TAG, "Found user in registered users: " + email);
                
                // Check password
                String storedPasswordHash = prefs.getString("pwd_" + email, null);
                if (storedPasswordHash == null || !verifyPassword(password, storedPasswordHash)) {
                    callback.onError("Invalid email or password");
                    return;
                }
                
                // Ensure user has valid tokens (for compatibility with auth checks)
                if (user.getAccessToken() == null || user.getAccessToken().isEmpty()) {
                    String accessToken = generateLocalToken(email, "access");
                    String refreshToken = generateLocalToken(email, "refresh");
                    user.setAccessToken(accessToken);
                    user.setRefreshToken(refreshToken);
                    
                    // Update user in registered users list
                    for (int i = 0; i < registeredUsers.size(); i++) {
                        if (registeredUsers.get(i).getEmail().equals(email)) {
                            registeredUsers.set(i, user);
                            break;
                        }
                    }
                    saveRegisteredUsers(registeredUsers);
                    
                    Log.d(TAG, "Generated tokens for existing user: " + email);
                }
                
                // Login successful
                authManager.storeCurrentUser(user);
                Log.d(TAG, "Local login successful for: " + email);
                callback.onSuccess(user);
                
            } catch (Exception e) {
                Log.e(TAG, "Local login error", e);
                callback.onError("Login failed: " + e.getMessage());
            }
        }, 500); // Simulate network delay
    }
    
    /**
     * Local signup with real email verification (with demo fallback)
     */
    public void signupLocal(String firstName, String lastName, String email, String password, 
                           AuthService.VerificationCallback callback) {
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            try {
                Log.d(TAG, "Local signup attempt for: " + email);
                
                // Check if user already exists
                List<User> registeredUsers = getRegisteredUsers();
                boolean exists = registeredUsers.stream()
                        .anyMatch(user -> user.getEmail().equals(email));
                
                if (exists) {
                    callback.onError("Email already registered. Please login instead.");
                    return;
                }
                
                // Generate verification code
                String verificationCode = generateVerificationCode();
                
                // Store verification data
                Map<String, Object> verificationData = new HashMap<>();
                verificationData.put("code", verificationCode);
                verificationData.put("firstName", firstName);
                verificationData.put("lastName", lastName);
                verificationData.put("email", email);
                verificationData.put("password", password);
                verificationData.put("timestamp", System.currentTimeMillis());
                
                String verificationJson = gson.toJson(verificationData);
                prefs.edit().putString("verify_" + email, verificationJson).apply();
                
                Log.d(TAG, "Generated verification code for " + email + ": " + verificationCode);
                
                // Try to send real email first
                if (emailService.isConfigured()) {
                    Log.d(TAG, "Email service configured, attempting to send real email");
                    sendRealVerificationEmail(firstName, lastName, email, verificationCode, callback);
                } else {
                    Log.d(TAG, "Email service not configured, showing verification code directly");
                    callback.onSuccess("Your verification code is " + verificationCode + ". Email service is not configured, so we're showing your code directly. Please enter this code in the verification screen to complete your account creation.");
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Local signup error", e);
                callback.onError("Signup failed: " + e.getMessage());
            }
        }, 800); // Simulate network delay
    }
    
    /**
     * Send real verification email with fallback to demo mode
     */
    private void sendRealVerificationEmail(String firstName, String lastName, String email, String verificationCode, AuthService.VerificationCallback callback) {
        emailService.sendVerificationEmail(firstName, lastName, email, verificationCode, new EmailService.EmailCallback() {
            @Override
            public void onSuccess(String message) {
                Log.d(TAG, "Real email sent successfully to: " + email);
                callback.onSuccess("Verification email sent to " + email + ". Please check your inbox and spam folder. The code expires in 10 minutes.");
            }
            
            @Override
            public void onError(String error) {
                Log.w(TAG, "Real email sending failed, showing verification code directly: " + error);
                // Fallback to showing code directly if real email fails
                callback.onSuccess("EMAIL DELIVERY FAILED: Your verification code is " + verificationCode + ". We couldn't send the email (" + error + "), so we're showing your code directly. Please enter this code in the verification screen to complete your account creation.");
            }
        });
    }
    
    /**
     * Local email verification
     */
    public void verifyEmailLocal(String email, String code, AuthService.AuthCallback callback) {
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            try {
                Log.d(TAG, "Local email verification for: " + email);
                
                // Get verification data
                String verificationJson = prefs.getString("verify_" + email, null);
                if (verificationJson == null) {
                    callback.onError("No verification code found for this email");
                    return;
                }
                
                Map<String, Object> verificationData = gson.fromJson(verificationJson, 
                    new TypeToken<Map<String, Object>>(){}.getType());
                
                String storedCode = (String) verificationData.get("code");
                double timestamp = (Double) verificationData.get("timestamp");
                
                // Check if code expired (10 minutes)
                if (System.currentTimeMillis() - (long)timestamp > 10 * 60 * 1000) {
                    prefs.edit().remove("verify_" + email).apply();
                    callback.onError("Verification code has expired. Please sign up again.");
                    return;
                }
                
                // Check code
                if (!code.equals(storedCode)) {
                    callback.onError("Invalid verification code");
                    return;
                }
                
                // Create user account
                User user = new User();
                user.setFirstName((String) verificationData.get("firstName"));
                user.setLastName((String) verificationData.get("lastName"));
                user.setEmail(email);
                user.setProfileImage(AuthManager.DEFAULT_PROFILE_IMAGE);
                user.setEmailVerified(true);
                
                // Generate local tokens for authentication compatibility
                String accessToken = generateLocalToken(email, "access");
                String refreshToken = generateLocalToken(email, "refresh");
                user.setAccessToken(accessToken);
                user.setRefreshToken(refreshToken);
                
                // Store user
                List<User> registeredUsers = getRegisteredUsers();
                registeredUsers.add(user);
                saveRegisteredUsers(registeredUsers);
                
                // Store password hash
                String password = (String) verificationData.get("password");
                String hashedPassword = hashPassword(password);
                prefs.edit().putString("pwd_" + email, hashedPassword).apply();
                
                // Clean up verification data
                prefs.edit().remove("verify_" + email).apply();
                
                // Store as current user
                authManager.storeCurrentUser(user);
                
                Log.d(TAG, "Email verification successful for: " + email);
                callback.onSuccess(user);
                
            } catch (Exception e) {
                Log.e(TAG, "Local email verification error", e);
                callback.onError("Verification failed: " + e.getMessage());
            }
        }, 500);
    }
    
    /**
     * Get registered users from local storage
     */
    private List<User> getRegisteredUsers() {
        try {
            String usersJson = prefs.getString(KEY_REGISTERED_USERS, null);
            if (usersJson == null) {
                return new ArrayList<>();
            }
            
            Type listType = new TypeToken<List<User>>(){}.getType();
            List<User> users = gson.fromJson(usersJson, listType);
            return users != null ? users : new ArrayList<>();
        } catch (Exception e) {
            Log.e(TAG, "Error reading registered users", e);
            return new ArrayList<>();
        }
    }
    
    /**
     * Save registered users to local storage
     */
    private void saveRegisteredUsers(List<User> users) {
        try {
            String usersJson = gson.toJson(users);
            prefs.edit().putString(KEY_REGISTERED_USERS, usersJson).apply();
        } catch (Exception e) {
            Log.e(TAG, "Error saving registered users", e);
        }
    }
    
    /**
     * Generate 6-digit verification code
     */
    private String generateVerificationCode() {
        Random random = new Random();
        return String.format("%06d", random.nextInt(999999));
    }
    
    /**
     * Hash password for storage
     */
    private String hashPassword(String password) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hashBytes = md.digest(password.getBytes());
            StringBuilder sb = new StringBuilder();
            for (byte b : hashBytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            Log.e(TAG, "Error hashing password", e);
            return password; // Fallback (not secure, but for demo)
        }
    }
    
    /**
     * Verify password against hash
     */
    private boolean verifyPassword(String password, String hash) {
        String passwordHash = hashPassword(password);
        return passwordHash.equals(hash);
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