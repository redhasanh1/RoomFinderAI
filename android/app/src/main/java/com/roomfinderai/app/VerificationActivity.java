package com.roomfinderai.app;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.TextUtils;
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

public class VerificationActivity extends AppCompatActivity {
    private static final String TAG = "VerificationActivity";
    private static final String PREFS_NAME = "RoomFinderAIPrefs";
    private static final String KEY_ACCESS_TOKEN = "access_token";
    private static final String KEY_USER_EMAIL = "user_email";
    
    private EditText codeEditText;
    private Button verifyButton;
    private TextView resendTextView;
    private TextView emailTextView;
    private ProgressBar progressBar;
    
    private String userEmail;
    private ApiService apiService;
    private SharedPreferences sharedPreferences;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_verification);
        
        sharedPreferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        
        // Get email from intent
        userEmail = getIntent().getStringExtra("email");
        if (userEmail == null) {
            finish();
            return;
        }
        
        initializeViews();
        setupClickListeners();
        
        apiService = ApiClient.getInstance().getApiService();
    }
    
    private void initializeViews() {
        codeEditText = findViewById(R.id.codeEditText);
        verifyButton = findViewById(R.id.verifyButton);
        resendTextView = findViewById(R.id.resendTextView);
        emailTextView = findViewById(R.id.emailTextView);
        progressBar = findViewById(R.id.progressBar);
        
        // Show the email where code was sent
        emailTextView.setText("We've sent a verification code to " + userEmail);
    }
    
    private void setupClickListeners() {
        verifyButton.setOnClickListener(v -> verifyCode());
        
        resendTextView.setOnClickListener(v -> {
            // TODO: Implement resend code functionality
            Toast.makeText(this, "Resend code feature coming soon", Toast.LENGTH_SHORT).show();
        });
        
        findViewById(R.id.backButton).setOnClickListener(v -> finish());
    }
    
    private void verifyCode() {
        String code = codeEditText.getText().toString().trim();
        
        if (TextUtils.isEmpty(code)) {
            codeEditText.setError("Verification code is required");
            return;
        }
        
        if (code.length() != 6) {
            codeEditText.setError("Code must be 6 digits");
            return;
        }
        
        showLoading(true);
        
        JsonObject verifyRequest = new JsonObject();
        verifyRequest.addProperty("email", userEmail);
        verifyRequest.addProperty("code", code);
        
        apiService.verifyCode(verifyRequest).enqueue(new Callback<JsonObject>() {
            @Override
            public void onResponse(Call<JsonObject> call, Response<JsonObject> response) {
                showLoading(false);
                
                if (response.isSuccessful() && response.body() != null) {
                    JsonObject responseBody = response.body();
                    String accessToken = responseBody.has("access_token") ? 
                            responseBody.get("access_token").getAsString() : null;
                    
                    if (accessToken != null) {
                        saveCredentials(accessToken, userEmail);
                        navigateToMainActivity();
                    } else {
                        showError("Verification successful! Please log in.");
                        navigateToLogin();
                    }
                } else {
                    showError("Invalid or expired verification code");
                }
            }
            
            @Override
            public void onFailure(Call<JsonObject> call, Throwable t) {
                showLoading(false);
                showError("Network error: " + t.getMessage());
            }
        });
    }
    
    private void showLoading(boolean show) {
        progressBar.setVisibility(show ? View.VISIBLE : View.GONE);
        verifyButton.setEnabled(!show);
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
        Intent intent = new Intent(VerificationActivity.this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }
    
    private void navigateToLogin() {
        Intent intent = new Intent(VerificationActivity.this, LoginActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }
}