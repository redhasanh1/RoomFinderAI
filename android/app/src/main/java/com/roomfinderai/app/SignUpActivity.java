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
import com.google.gson.JsonObject;
import com.roomfinderai.app.api.ApiClient;
import com.roomfinderai.app.api.ApiService;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class SignUpActivity extends AppCompatActivity {
    private static final String TAG = "SignUpActivity";
    private static final String PREFS_NAME = "RoomFinderAIPrefs";
    private static final String KEY_ACCESS_TOKEN = "access_token";
    private static final String KEY_USER_EMAIL = "user_email";
    
    private EditText nameEditText;
    private EditText emailEditText;
    private EditText passwordEditText;
    private EditText confirmPasswordEditText;
    private Button signUpButton;
    private TextView loginTextView;
    private ProgressBar progressBar;
    
    private ApiService apiService;
    private SharedPreferences sharedPreferences;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_sign_up);
        
        sharedPreferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        
        initializeViews();
        setupClickListeners();
        
        apiService = ApiClient.getInstance().getApiService();
    }
    
    private void initializeViews() {
        nameEditText = findViewById(R.id.nameEditText);
        emailEditText = findViewById(R.id.emailEditText);
        passwordEditText = findViewById(R.id.passwordEditText);
        confirmPasswordEditText = findViewById(R.id.confirmPasswordEditText);
        signUpButton = findViewById(R.id.signUpButton);
        loginTextView = findViewById(R.id.loginTextView);
        progressBar = findViewById(R.id.progressBar);
        
        // Back button
        findViewById(R.id.backButton).setOnClickListener(v -> finish());
    }
    
    private void setupClickListeners() {
        signUpButton.setOnClickListener(v -> performSignUp());
        
        loginTextView.setOnClickListener(v -> {
            finish(); // Go back to login activity
        });
    }
    
    private void performSignUp() {
        String name = nameEditText.getText().toString().trim();
        String email = emailEditText.getText().toString().trim();
        String password = passwordEditText.getText().toString().trim();
        String confirmPassword = confirmPasswordEditText.getText().toString().trim();
        
        if (!validateInput(name, email, password, confirmPassword)) {
            return;
        }
        
        showLoading(true);
        
        JsonObject signUpRequest = new JsonObject();
        signUpRequest.addProperty("name", name);
        signUpRequest.addProperty("email", email);
        signUpRequest.addProperty("password", password);
        
        apiService.signUp(signUpRequest).enqueue(new Callback<JsonObject>() {
            @Override
            public void onResponse(Call<JsonObject> call, Response<JsonObject> response) {
                showLoading(false);
                
                if (response.isSuccessful() && response.body() != null) {
                    JsonObject responseBody = response.body();
                    String accessToken = responseBody.has("access_token") ? 
                            responseBody.get("access_token").getAsString() : null;
                    
                    // Check if verification is required
                    boolean requiresVerification = responseBody.has("requiresVerification") && 
                            responseBody.get("requiresVerification").getAsBoolean();
                    
                    if (requiresVerification) {
                        // Navigate to verification activity
                        Intent intent = new Intent(SignUpActivity.this, VerificationActivity.class);
                        intent.putExtra("email", email);
                        startActivity(intent);
                        finish();
                    } else if (accessToken != null) {
                        saveCredentials(accessToken, email);
                        navigateToMainActivity();
                    } else {
                        showError("Sign up successful! Please log in.");
                        finish();
                    }
                } else {
                    showError("Email already exists or invalid data");
                }
            }
            
            @Override
            public void onFailure(Call<JsonObject> call, Throwable t) {
                showLoading(false);
                showError("Network error: " + t.getMessage());
            }
        });
    }
    
    private boolean validateInput(String name, String email, String password, String confirmPassword) {
        if (TextUtils.isEmpty(name)) {
            nameEditText.setError("Name is required");
            return false;
        }
        
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
        
        if (!password.equals(confirmPassword)) {
            confirmPasswordEditText.setError("Passwords do not match");
            return false;
        }
        
        return true;
    }
    
    private void showLoading(boolean show) {
        progressBar.setVisibility(show ? View.VISIBLE : View.GONE);
        signUpButton.setEnabled(!show);
    }
    
    private void showError(String message) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show();
    }
    
    private void saveCredentials(String accessToken, String email) {
        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.putString(KEY_ACCESS_TOKEN, accessToken);
        editor.putString(KEY_USER_EMAIL, email);
        editor.apply();
        
        ApiClient.getInstance().setAuthToken(accessToken);
    }
    
    private void navigateToMainActivity() {
        Intent intent = new Intent(SignUpActivity.this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }
}