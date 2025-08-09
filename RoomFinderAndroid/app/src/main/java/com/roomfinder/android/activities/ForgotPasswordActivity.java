package com.roomfinder.android.activities;

import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.roomfinder.android.auth.AuthService;
import com.roomfinder.android.databinding.ActivityForgotPasswordBinding;

/**
 * ForgotPasswordActivity - Handles password reset requests
 * Matches the website's forgot password flow exactly
 */
public class ForgotPasswordActivity extends AppCompatActivity {
    
    private static final String TAG = "ForgotPasswordActivity";
    private ActivityForgotPasswordBinding binding;
    private AuthService authService;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        binding = ActivityForgotPasswordBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        authService = AuthService.getInstance(this);
        
        setupViews();
    }
    
    private void setupViews() {
        // Back button
        binding.backButton.setOnClickListener(v -> finish());
        
        // Send reset email button (matching website forgot password logic)
        binding.sendResetButton.setOnClickListener(v -> sendPasswordReset());
        
        // Pre-fill email if provided
        String email = getIntent().getStringExtra("email");
        if (email != null && !email.isEmpty()) {
            binding.emailInput.setText(email);
        }
    }
    
    /**
     * Send password reset email (matching website forgot password logic)
     */
    private void sendPasswordReset() {
        String email = binding.emailInput.getText().toString().trim();
        
        // Basic validation (matching website)
        if (email.isEmpty()) {
            Toast.makeText(this, "Please enter your email address", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (!isValidEmail(email)) {
            Toast.makeText(this, "Please enter a valid email address", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Show loading state
        setLoadingState(true);
        
        // Call forgot password API (matching website fetch('/api/forgot-password'))
        authService.forgotPassword(email, new AuthService.PasswordResetCallback() {
            @Override
            public void onSuccess(String message) {
                Log.d(TAG, "Password reset email sent successfully");
                setLoadingState(false);
                
                // Show success message (matching website)
                Toast.makeText(ForgotPasswordActivity.this, 
                    "Password reset email sent! Please check your inbox.", 
                    Toast.LENGTH_LONG).show();
                
                // Show success state
                showSuccessState();
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Forgot password failed: " + error);
                setLoadingState(false);
                
                Toast.makeText(ForgotPasswordActivity.this, error, Toast.LENGTH_LONG).show();
            }
        });
    }
    
    /**
     * Show success state after email is sent
     */
    private void showSuccessState() {
        // Hide the form and show success message
        binding.formContainer.setVisibility(View.GONE);
        binding.successContainer.setVisibility(View.VISIBLE);
        
        String email = binding.emailInput.getText().toString().trim();
        binding.successEmailText.setText(email);
    }
    
    /**
     * Set loading state
     */
    private void setLoadingState(boolean loading) {
        binding.sendResetButton.setEnabled(!loading);
        binding.emailInput.setEnabled(!loading);
        binding.backButton.setEnabled(!loading);
        
        if (loading) {
            binding.sendResetButton.setText("Sending...");
        } else {
            binding.sendResetButton.setText("Send Reset Email");
        }
    }
    
    /**
     * Email validation (matching website logic)
     */
    private boolean isValidEmail(String email) {
        return email != null && email.contains("@") && email.contains(".") && email.length() > 5;
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (binding != null) {
            binding = null;
        }
    }
}