package com.roomfinderai.app;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.TextUtils;
import android.util.Log;
import android.util.Patterns;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.google.android.gms.auth.api.signin.GoogleSignIn;
import com.google.android.gms.auth.api.signin.GoogleSignInAccount;
import com.google.android.gms.auth.api.signin.GoogleSignInClient;
import com.google.android.gms.auth.api.signin.GoogleSignInOptions;
import com.google.android.gms.common.SignInButton;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.tasks.Task;
import com.google.gson.JsonObject;
import com.roomfinderai.app.api.ApiClient;
import com.roomfinderai.app.api.ApiService;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class LoginActivity extends AppCompatActivity {
    private static final String TAG = "LoginActivity";
    private static final int RC_SIGN_IN = 9001;
    private static final String PREFS_NAME = "RoomFinderAIPrefs";
    private static final String KEY_ACCESS_TOKEN = "access_token";
    private static final String KEY_USER_EMAIL = "user_email";
    
    private EditText emailEditText;
    private EditText passwordEditText;
    private Button loginButton;
    private SignInButton googleSignInButton;
    private TextView signUpTextView;
    private TextView forgotPasswordTextView;
    private ProgressBar progressBar;
    
    private GoogleSignInClient googleSignInClient;
    private ApiService apiService;
    private SharedPreferences sharedPreferences;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_login);
        
        // Initialize shared preferences
        sharedPreferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        
        // Check if user is already logged in
        if (isUserLoggedIn()) {
            navigateToMainActivity();
            return;
        }
        
        initializeViews();
        configureGoogleSignIn();
        setupClickListeners();
        
        // Clear any cached Google Sign-In data that might be corrupted
        clearGoogleSignInCache();
        
        // Initialize API service
        apiService = ApiClient.getInstance().getApiService();
    }
    
    private void initializeViews() {
        emailEditText = findViewById(R.id.emailEditText);
        passwordEditText = findViewById(R.id.passwordEditText);
        loginButton = findViewById(R.id.loginButton);
        googleSignInButton = findViewById(R.id.googleSignInButton);
        signUpTextView = findViewById(R.id.signUpTextView);
        forgotPasswordTextView = findViewById(R.id.forgotPasswordTextView);
        progressBar = findViewById(R.id.progressBar);
        
        // Set Google Sign-In button text
        TextView textView = (TextView) googleSignInButton.getChildAt(0);
        textView.setText("Sign in with Google");
    }
    
    private void configureGoogleSignIn() {
        try {
            // Try without requestIdToken first - simpler approach
            GoogleSignInOptions gso = new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                    .requestEmail()
                    .requestProfile()
                    .build();
            
            googleSignInClient = GoogleSignIn.getClient(this, gso);
            Log.d(TAG, "Google Sign-In configured without ID token requirement");
            
        } catch (Exception e) {
            Log.e(TAG, "Error configuring Google Sign-In: " + e.getMessage(), e);
            showError("Google Sign-In configuration failed");
        }
    }
    
    private void setupClickListeners() {
        loginButton.setOnClickListener(v -> performEmailPasswordLogin());
        
        googleSignInButton.setOnClickListener(v -> performGoogleSignIn());
        
        signUpTextView.setOnClickListener(v -> {
            // Navigate to sign up activity or show sign up dialog
            Intent intent = new Intent(LoginActivity.this, SignUpActivity.class);
            startActivity(intent);
        });
        
        forgotPasswordTextView.setOnClickListener(v -> {
            // Navigate to forgot password activity or show reset dialog
            Toast.makeText(this, "Forgot password feature coming soon", Toast.LENGTH_SHORT).show();
        });
    }
    
    private void performEmailPasswordLogin() {
        String email = emailEditText.getText().toString().trim();
        String password = passwordEditText.getText().toString().trim();
        
        // Validate input
        if (!validateEmailPassword(email, password)) {
            return;
        }
        
        showLoading(true);
        
        // Create login request
        JsonObject loginRequest = new JsonObject();
        loginRequest.addProperty("email", email);
        loginRequest.addProperty("password", password);
        
        // Make API call
        apiService.login(loginRequest).enqueue(new Callback<JsonObject>() {
            @Override
            public void onResponse(Call<JsonObject> call, Response<JsonObject> response) {
                showLoading(false);
                
                if (response.isSuccessful() && response.body() != null) {
                    JsonObject responseBody = response.body();
                    
                    // Extract access token and user info
                    String accessToken = responseBody.has("access_token") ? 
                            responseBody.get("access_token").getAsString() : null;
                    
                    if (accessToken != null) {
                        // Save credentials
                        saveCredentials(accessToken, email);
                        
                        // Navigate to main activity
                        navigateToMainActivity();
                    } else {
                        showError("Invalid response from server");
                    }
                } else {
                    showError("Invalid email or password");
                }
            }
            
            @Override
            public void onFailure(Call<JsonObject> call, Throwable t) {
                showLoading(false);
                showError("Network error: " + t.getMessage());
            }
        });
    }
    
    private void performGoogleSignIn() {
        Intent signInIntent = googleSignInClient.getSignInIntent();
        startActivityForResult(signInIntent, RC_SIGN_IN);
    }
    
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        if (requestCode == RC_SIGN_IN) {
            Task<GoogleSignInAccount> task = GoogleSignIn.getSignedInAccountFromIntent(data);
            handleGoogleSignInResult(task);
        }
    }
    
    private void handleGoogleSignInResult(Task<GoogleSignInAccount> completedTask) {
        try {
            GoogleSignInAccount account = completedTask.getResult(ApiException.class);
            
            String email = account.getEmail();
            String displayName = account.getDisplayName();
            
            Log.d(TAG, "Google Sign-In successful - Email: " + email + ", Name: " + displayName);
            
            if (email == null || email.isEmpty()) {
                showError("Failed to get email from Google account");
                return;
            }
            
            showLoading(true);
            
            // Send email and profile info to backend
            JsonObject googleSignInRequest = new JsonObject();
            googleSignInRequest.addProperty("email", email);
            googleSignInRequest.addProperty("name", displayName);
            googleSignInRequest.addProperty("provider", "google");
            
            apiService.googleSignIn(googleSignInRequest).enqueue(new Callback<JsonObject>() {
                @Override
                public void onResponse(Call<JsonObject> call, Response<JsonObject> response) {
                    showLoading(false);
                    
                    if (response.isSuccessful() && response.body() != null) {
                        JsonObject responseBody = response.body();
                        String accessToken = responseBody.has("access_token") ? 
                                responseBody.get("access_token").getAsString() : null;
                        
                        if (accessToken != null) {
                            saveCredentials(accessToken, email);
                            navigateToMainActivity();
                        } else {
                            showError("Invalid response from server");
                        }
                    } else {
                        showError("Google sign-in failed");
                    }
                }
                
                @Override
                public void onFailure(Call<JsonObject> call, Throwable t) {
                    showLoading(false);
                    showError("Network error: " + t.getMessage());
                }
            });
            
        } catch (ApiException e) {
            Log.w(TAG, "Google sign in failed with error code: " + e.getStatusCode(), e);
            
            String errorMessage;
            switch (e.getStatusCode()) {
                case 10:
                    errorMessage = "Google Sign-In configuration error";
                    break;
                default:
                    errorMessage = "Google sign-in failed: " + e.getStatusCode();
            }
            showError(errorMessage);
        }
    }
    
    private boolean validateEmailPassword(String email, String password) {
        if (TextUtils.isEmpty(email)) {
            emailEditText.setError("Email is required");
            return false;
        }
        
        if (!Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            emailEditText.setError("Enter a valid email");
            return false;
        }
        
        if (TextUtils.isEmpty(password)) {
            passwordEditText.setError("Password is required");
            return false;
        }
        
        if (password.length() < 6) {
            passwordEditText.setError("Password must be at least 6 characters");
            return false;
        }
        
        return true;
    }
    
    private void showLoading(boolean show) {
        progressBar.setVisibility(show ? View.VISIBLE : View.GONE);
        loginButton.setEnabled(!show);
        googleSignInButton.setEnabled(!show);
    }
    
    private void showError(String message) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show();
    }
    
    private void saveCredentials(String accessToken, String email) {
        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.putString(KEY_ACCESS_TOKEN, accessToken);
        editor.putString(KEY_USER_EMAIL, email);
        editor.apply();
        
        // Update API client with new token
        ApiClient.getInstance().setAuthToken(accessToken);
    }
    
    private boolean isUserLoggedIn() {
        String accessToken = sharedPreferences.getString(KEY_ACCESS_TOKEN, null);
        return accessToken != null && !accessToken.isEmpty();
    }
    
    private void clearGoogleSignInCache() {
        try {
            if (googleSignInClient != null) {
                googleSignInClient.signOut();
                Log.d(TAG, "Cleared Google Sign-In cache");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error clearing Google Sign-In cache: " + e.getMessage());
        }
    }

    private void navigateToMainActivity() {
        Intent intent = new Intent(LoginActivity.this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }
}