package com.roomfinder.android.activities;

import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.roomfinder.android.auth.AuthService;
import com.roomfinder.android.databinding.ActivityResetPasswordBinding;

/**
 * ResetPasswordActivity - Final step of password reset flow
 * Matches the website's reset password functionality exactly
 */
public class ResetPasswordActivity extends AppCompatActivity {
    
    private static final String TAG = "ResetPasswordActivity";
    private ActivityResetPasswordBinding binding;
    private AuthService authService;
    
    private String email;
    private String code;
    private String sessionId;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        binding = ActivityResetPasswordBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        authService = AuthService.getInstance(this);
        
        // Get data from intent
        email = getIntent().getStringExtra("email");
        code = getIntent().getStringExtra("code");
        sessionId = getIntent().getStringExtra("sessionId");
        
        if (email == null || code == null || sessionId == null) {
            Toast.makeText(this, "Invalid reset request", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        
        setupViews();
    }
    
    private void setupViews() {
        // Show email in UI for context
        binding.resetEmailText.setText(email);
        
        // Back button
        binding.backButton.setOnClickListener(v -> finish());
        
        // Reset password button (matching website reset password logic)
        binding.resetPasswordButton.setOnClickListener(v -> resetPassword());
    }
    
    /**
     * Reset password using the verified code (matching website reset password logic)
     */
    private void resetPassword() {
        String newPassword = binding.newPasswordInput.getText().toString();
        String confirmPassword = binding.confirmPasswordInput.getText().toString();
        
        // Validation (matching website)
        if (newPassword.isEmpty()) {
            Toast.makeText(this, "Please enter a new password", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (newPassword.length() < 8) {
            Toast.makeText(this, "Password must be at least 8 characters", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (!newPassword.equals(confirmPassword)) {
            Toast.makeText(this, "Passwords do not match", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Show loading state
        setLoadingState(true);
        
        // Call reset password API (matching website fetch('/api/reset-password'))
        authService.resetPassword(email, code, newPassword, sessionId, new AuthService.PasswordResetCallback() {
            @Override
            public void onSuccess(String message) {
                Log.d(TAG, "Password reset successful: " + message);
                setLoadingState(false);
                
                // Show success message
                Toast.makeText(ResetPasswordActivity.this, 
                    "Password reset successfully! Please log in with your new password.", 
                    Toast.LENGTH_LONG).show();
                
                // Navigate back to login
                finish();
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Password reset failed: " + error);
                setLoadingState(false);
                
                Toast.makeText(ResetPasswordActivity.this, error, Toast.LENGTH_LONG).show();
            }
        });
    }
    
    /**
     * Set loading state
     */
    private void setLoadingState(boolean loading) {
        binding.resetPasswordButton.setEnabled(!loading);
        binding.newPasswordInput.setEnabled(!loading);
        binding.confirmPasswordInput.setEnabled(!loading);
        binding.backButton.setEnabled(!loading);
        
        if (loading) {
            binding.resetPasswordButton.setText("Resetting...");
        } else {
            binding.resetPasswordButton.setText("Reset Password");
        }
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (binding != null) {
            binding = null;
        }
    }
}