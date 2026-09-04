package com.roomfinder.android.activities;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
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

        // Android 15 draws this activity edge to edge, so without the inset the
        // back arrow sits on top of the clock.
        androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(binding.getRoot(), (view, insets) -> {
            int top = insets.getInsets(androidx.core.view.WindowInsetsCompat.Type.systemBars()).top;
            view.setPadding(view.getPaddingLeft(), top, view.getPaddingRight(), view.getPaddingBottom());
            return insets;
        });

        // Arrives pre-filled when the email was already typed on the sign-in form.
        String prefill = getIntent().getStringExtra("email");
        if (prefill != null && !prefill.isEmpty()) {
            binding.emailInput.setText(prefill);
        }
        
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
        binding.errorText.setVisibility(android.view.View.GONE);

        // No challenge here any more. The server exempts app traffic (it
        // matches the RoomFinderAI/<version> Android user agent this app now
        // sends), because Turnstile cannot complete inside an app WebView -
        // iOS is exempted for exactly the same reason. Running the widget
        // first only guaranteed a failure before the request was ever made.
        sendResetWithToken(email, null);
    }

    private void sendResetWithToken(String email, String turnstileToken) {
        authService.sendPasswordResetCode(email, turnstileToken, new AuthService.ResetCodeCallback() {
            @Override
            public void onSuccess(String sessionId) {
                Log.d(TAG, "Reset code sent successfully, sessionId: " + sessionId);
                setLoadingState(false);
                
                // Show success message (matching website)
                Toast.makeText(ForgotPasswordActivity.this, 
                    "Reset code sent! Please check your email.", 
                    Toast.LENGTH_LONG).show();
                
                // Navigate to verification activity with session info
                navigateToVerification(email, sessionId);
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Send reset code failed: " + error);
                setLoadingState(false);
                if (error != null && error.toLowerCase().contains("bot verification")) {
                    // An older server build that has not learned about the
                    // Android user agent yet.
                    offerBrowserFallback(error);
                } else {
                    showError(error);
                }
            }
        });
    }
    
    /**
     * Navigate to verification activity with reset code flow
     */
    private void navigateToVerification(String email, String sessionId) {
        Intent intent = new Intent(this, VerificationActivity.class);
        intent.putExtra("email", email);
        intent.putExtra("sessionId", sessionId);
        intent.putExtra("verificationType", "password_reset");
        startActivity(intent);
        finish(); // Close this activity
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

    /**
     * Puts the failure on the screen instead of only in the log.
     *
     * Tapping Send used to produce nothing visible at all when the request was
     * rejected, so the button looked broken.
     */
    private void showError(String error) {
        String message = error == null ? "" : error.trim();
        if (message.toLowerCase().contains("bot verification")) {
            // The site guards this endpoint with Cloudflare Turnstile and the
            // app carries no token, so say what to do rather than repeating a
            // server-side term nobody outside the codebase knows.
            message = "We can't verify this request from the app yet. Reset your password on roomfinderai.com for now.";
        } else if (message.isEmpty()) {
            message = "That didn't send. Try again in a moment.";
        }
        binding.errorText.setText(message);
        binding.errorText.setVisibility(android.view.View.VISIBLE);
    }

    /**
     * Hands the reset off to the browser when the in-app check cannot run.
     *
     * Cloudflare refuses the challenge inside an Android WebView even on the
     * right domain, so the app cannot obtain a token itself today. The website
     * can, and it is one tap away.
     */
    private void offerBrowserFallback(String reason) {
        Log.w(TAG, "In-app verification unavailable: " + reason);
        binding.errorText.setText("We can't run the security check inside the app. "
                + "Tap here to reset your password in your browser.");
        binding.errorText.setVisibility(android.view.View.VISIBLE);
        binding.errorText.setOnClickListener(v -> {
            String email = binding.emailInput.getText() == null
                    ? "" : binding.emailInput.getText().toString().trim();
            String url = "https://www.roomfinderai.com/forgot-password";
            if (!email.isEmpty()) {
                url += "?email=" + android.net.Uri.encode(email);
            }
            startActivity(new android.content.Intent(android.content.Intent.ACTION_VIEW,
                    android.net.Uri.parse(url)));
        });
    }
}