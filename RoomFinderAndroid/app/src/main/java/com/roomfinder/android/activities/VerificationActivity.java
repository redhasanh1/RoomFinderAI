package com.roomfinder.android.activities;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.View;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.auth.AuthService;
import com.roomfinder.android.databinding.ActivityVerificationBinding;
import com.roomfinder.android.models.User;

/**
 * VerificationActivity - Handles 6-digit email verification
 * Matches the website's email verification flow exactly
 */
public class VerificationActivity extends AppCompatActivity {
    
    private static final String TAG = "VerificationActivity";
    private ActivityVerificationBinding binding;
    private AuthService authService;
    private AuthManager authManager;
    
    private String email;
    private String firstName;
    private String lastName;
    private String demoVerificationCode; // Store demo code for display
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        binding = ActivityVerificationBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        authService = AuthService.getInstance(this);
        authManager = AuthManager.getInstance(this);
        
        // Get data from intent
        email = getIntent().getStringExtra("email");
        firstName = getIntent().getStringExtra("firstName");
        lastName = getIntent().getStringExtra("lastName");
        demoVerificationCode = getIntent().getStringExtra("demo_code"); // Get demo code if passed
        
        // If no demo code was passed directly, try to get it from the signup success message
        if (demoVerificationCode == null) {
            String signupMessage = getIntent().getStringExtra("signup_message");
            if (signupMessage != null) {
                extractDemoCodeFromMessage(signupMessage);
            }
        }
        
        if (email == null) {
            Toast.makeText(this, "Invalid verification request", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        
        setupViews();
    }
    
    private void setupViews() {
        // Set email in UI (matching website)
        binding.verificationEmailText.setText(email);
        
        // Show demo code if available
        showDemoModeIfNeeded();
        
        // Format verification code input (matching website - only numbers)
        binding.verificationCodeInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}
            
            @Override
            public void afterTextChanged(Editable s) {
                // Remove non-numeric characters (matching website logic)
                String text = s.toString().replaceAll("[^0-9]", "");
                if (!text.equals(s.toString())) {
                    binding.verificationCodeInput.setText(text);
                    binding.verificationCodeInput.setSelection(text.length());
                }
                
                // Limit to 6 digits
                if (text.length() > 6) {
                    text = text.substring(0, 6);
                    binding.verificationCodeInput.setText(text);
                    binding.verificationCodeInput.setSelection(text.length());
                }
            }
        });
        
        // Verify button (matching website verificationForm.addEventListener('submit'))
        binding.verifyButton.setOnClickListener(v -> performVerification());
        
        // Resend code button (matching website resendCode.addEventListener('click'))
        binding.resendCodeButton.setOnClickListener(v -> resendVerificationCode());
        
        // Back button (matching website backToRegistration.addEventListener('click'))
        binding.backButton.setOnClickListener(v -> {
            setResult(RESULT_CANCELED);
            finish();
        });
        
        // Skip verification button (demo mode only)
        binding.skipVerificationButton.setOnClickListener(v -> {
            Log.d(TAG, "Skip verification requested in demo mode");
            skipVerificationForDemo();
        });
    }
    
    /**
     * Show verification code display if available
     */
    private void showDemoModeIfNeeded() {
        if (demoVerificationCode != null && !demoVerificationCode.isEmpty()) {
            // Show verification code card
            binding.demoCodeCard.setVisibility(View.VISIBLE);
            binding.demoCodeDisplay.setText(demoVerificationCode);
            
            // Check if this is a real demo account or just email delivery failure
            boolean isActualDemoAccount = isEmailInDemoAccounts(email);
            
            if (isActualDemoAccount) {
                // Actual demo account
                binding.verificationDescription.setText("DEMO ACCOUNT: Your verification code is displayed below:");
                binding.skipVerificationButton.setVisibility(View.VISIBLE);
                showDebugInfo("Demo account mode. Code: " + demoVerificationCode + " | Email: " + email);
            } else {
                // Real account, just showing code because email failed
                binding.verificationDescription.setText("EMAIL UNAVAILABLE: Your verification code is displayed below:");
                binding.skipVerificationButton.setVisibility(View.GONE); // No skip for real accounts
                showDebugInfo("Real account - email delivery failed. Code: " + demoVerificationCode + " | Email: " + email);
            }
            
            // Setup auto-fill and copy functionality
            setupDemoCodeInteractions();
        } else {
            // Regular mode - waiting for email
            binding.demoCodeCard.setVisibility(View.GONE);
            binding.skipVerificationButton.setVisibility(View.GONE);
            binding.verificationDescription.setText("We've sent a 6-digit verification code to:");
            
            // Show debug info for troubleshooting
            showDebugInfo("Regular mode. Waiting for email verification for: " + email);
        }
    }
    
    /**
     * Check if email is in the demo accounts list
     */
    private boolean isEmailInDemoAccounts(String email) {
        if (email == null) return false;
        
        // Demo account emails (matching LocalAuthService DEMO_ACCOUNTS)
        return email.equals("demo@roomfinder.com") || 
               email.equals("test@roomfinder.com") || 
               email.equals("user@example.com");
    }
    
    /**
     * Show debug information for troubleshooting
     */
    private void showDebugInfo(String info) {
        binding.debugInfo.setText("Debug: " + info);
        binding.debugInfo.setVisibility(View.VISIBLE);
        Log.d(TAG, "Debug info: " + info);
    }
    
    /**
     * Setup interactions for demo code (auto-fill, copy, tap to select)
     */
    private void setupDemoCodeInteractions() {
        if (demoVerificationCode == null) return;
        
        // Auto-fill button
        binding.autoFillButton.setOnClickListener(v -> {
            binding.verificationCodeInput.setText(demoVerificationCode);
            binding.verificationCodeInput.setSelection(demoVerificationCode.length());
            Toast.makeText(this, "Code auto-filled!", Toast.LENGTH_SHORT).show();
        });
        
        // Copy code button
        binding.copyCodeButton.setOnClickListener(v -> {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            ClipData clip = ClipData.newPlainText("Verification Code", demoVerificationCode);
            clipboard.setPrimaryClip(clip);
            Toast.makeText(this, "Code copied to clipboard!", Toast.LENGTH_SHORT).show();
        });
        
        // Tap code to auto-fill
        binding.demoCodeDisplay.setOnClickListener(v -> {
            binding.verificationCodeInput.setText(demoVerificationCode);
            binding.verificationCodeInput.setSelection(demoVerificationCode.length());
            Toast.makeText(this, "Code auto-filled! Tap 'Verify Email' to continue.", Toast.LENGTH_LONG).show();
        });
        
        // Auto-fill immediately if input is empty
        if (binding.verificationCodeInput.getText().toString().trim().isEmpty()) {
            // Auto-fill after a short delay to let UI settle
            binding.verificationCodeInput.postDelayed(() -> {
                binding.verificationCodeInput.setText(demoVerificationCode);
                binding.verificationCodeInput.setSelection(demoVerificationCode.length());
            }, 500);
        }
    }
    
    /**
     * Perform email verification (matching website verification logic)
     */
    private void performVerification() {
        String code = binding.verificationCodeInput.getText().toString().trim();
        
        if (code.isEmpty()) {
            Toast.makeText(this, "Please enter the verification code", Toast.LENGTH_SHORT).show();
            return;
        }
        
        if (code.length() != 6) {
            Toast.makeText(this, "Verification code must be 6 digits", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Show loading state
        setLoadingState(true);
        
        // Call verify email API (matching website fetch('/api/verify-email'))
        authService.verifyEmail(email, code, new AuthService.AuthCallback() {
            @Override
            public void onSuccess(User user) {
                Log.d(TAG, "Email verification successful for: " + user.getEmail());
                setLoadingState(false);
                
                // Create complete user object (matching website logic)
                user.setFirstName(firstName != null ? firstName : "User");
                user.setLastName(lastName != null ? lastName : "Name");
                user.setEmailVerified(true);
                // Ensure lists are initialized (matching website user structure)
                if (user.getAiChats() == null) {
                    user.setAiChats(new java.util.ArrayList<>());
                }
                if (user.getListings() == null) {
                    user.setListings(new java.util.ArrayList<>());
                }
                
                // Register and store user (matching website localStorage logic)
                authManager.registerUser(user);
                authManager.storeCurrentUser(user);
                
                Toast.makeText(VerificationActivity.this, "Email verified successfully! Welcome to RoomFinder AI.", 
                    Toast.LENGTH_SHORT).show();
                
                // Return success to LoginActivity
                setResult(RESULT_OK);
                finish();
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Email verification failed: " + error);
                setLoadingState(false);
                
                Toast.makeText(VerificationActivity.this, error, Toast.LENGTH_LONG).show();
            }
        });
    }
    
    /**
     * Resend verification code (matching website resend logic)
     */
    private void resendVerificationCode() {
        if (firstName == null || lastName == null) {
            Toast.makeText(this, "Cannot resend code - missing user data", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Show loading state for resend button
        binding.resendCodeButton.setEnabled(false);
        binding.resendCodeButton.setText("Sending...");
        
        // Call send verification API again (matching website resend logic)
        authService.sendVerification(firstName, lastName, email, "", new AuthService.VerificationCallback() {
            @Override
            public void onSuccess(String message) {
                Log.d(TAG, "Verification code resent successfully");
                
                // Extract demo code from message if it's demo mode
                extractDemoCodeFromMessage(message);
                
                Toast.makeText(VerificationActivity.this, "Verification code resent successfully!", 
                    Toast.LENGTH_SHORT).show();
                
                // Clear the input field (matching website)
                binding.verificationCodeInput.setText("");
                
                // Update demo mode display
                showDemoModeIfNeeded();
                
                // Reset resend button
                binding.resendCodeButton.setEnabled(true);
                binding.resendCodeButton.setText("Resend Code");
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Failed to resend verification code: " + error);
                
                Toast.makeText(VerificationActivity.this, error, Toast.LENGTH_LONG).show();
                
                // Reset resend button
                binding.resendCodeButton.setEnabled(true);
                binding.resendCodeButton.setText("Resend Code");
            }
        });
    }
    
    /**
     * Set loading state for verify button
     */
    private void setLoadingState(boolean loading) {
        binding.verifyButton.setEnabled(!loading);
        binding.verificationCodeInput.setEnabled(!loading);
        binding.resendCodeButton.setEnabled(!loading);
        binding.backButton.setEnabled(!loading);
        
        if (loading) {
            binding.verifyButton.setText("Verifying...");
        } else {
            binding.verifyButton.setText("Verify Email");
        }
    }
    
    /**
     * Extract verification code from demo mode success message with multiple methods
     */
    private void extractDemoCodeFromMessage(String message) {
        if (message == null) return;
        
        Log.d(TAG, "Attempting to extract demo code from message: " + message);
        
        // Method 1: Look for "verification code is XXXXXX"
        if (message.contains("verification code is ")) {
            try {
                int startIndex = message.indexOf("verification code is ") + "verification code is ".length();
                String potentialCode = message.substring(startIndex, Math.min(startIndex + 6, message.length()));
                
                // Validate it's 6 digits
                if (potentialCode.matches("\\d{6}")) {
                    demoVerificationCode = potentialCode;
                    Log.d(TAG, "Method 1 - Extracted demo verification code: " + demoVerificationCode);
                    return;
                }
            } catch (Exception e) {
                Log.e(TAG, "Method 1 failed to extract demo code", e);
            }
        }
        
        // Method 2: Use regex to find any 6-digit number in the message
        try {
            java.util.regex.Pattern pattern = java.util.regex.Pattern.compile("\\b(\\d{6})\\b");
            java.util.regex.Matcher matcher = pattern.matcher(message);
            if (matcher.find()) {
                demoVerificationCode = matcher.group(1);
                Log.d(TAG, "Method 2 - Extracted demo code via regex: " + demoVerificationCode);
                return;
            }
        } catch (Exception e) {
            Log.e(TAG, "Method 2 regex extraction failed", e);
        }
        
        // Method 3: Look for "DEMO MODE" and extract the first 6-digit sequence after it
        if (message.contains("DEMO MODE")) {
            try {
                int demoIndex = message.indexOf("DEMO MODE");
                String afterDemo = message.substring(demoIndex);
                java.util.regex.Pattern pattern = java.util.regex.Pattern.compile("(\\d{6})");
                java.util.regex.Matcher matcher = pattern.matcher(afterDemo);
                if (matcher.find()) {
                    demoVerificationCode = matcher.group(1);
                    Log.d(TAG, "Method 3 - Extracted demo code after DEMO MODE: " + demoVerificationCode);
                    return;
                }
            } catch (Exception e) {
                Log.e(TAG, "Method 3 failed to extract demo code", e);
            }
        }
        
        Log.w(TAG, "All extraction methods failed for message: " + message);
    }
    
    /**
     * Skip verification process for demo mode
     */
    private void skipVerificationForDemo() {
        Log.d(TAG, "Skipping verification for demo mode");
        
        // Create demo user directly
        User user = new User();
        user.setFirstName(firstName != null ? firstName : "Demo");
        user.setLastName(lastName != null ? lastName : "User");
        user.setEmail(email);
        user.setEmailVerified(true);
        user.setProfileImage(com.roomfinder.android.auth.AuthManager.DEFAULT_PROFILE_IMAGE);
        
        // Ensure lists are initialized
        if (user.getAiChats() == null) {
            user.setAiChats(new java.util.ArrayList<>());
        }
        if (user.getListings() == null) {
            user.setListings(new java.util.ArrayList<>());
        }
        
        // Register and store user
        authManager.registerUser(user);
        authManager.storeCurrentUser(user);
        
        Toast.makeText(this, "Demo account created successfully! Welcome to RoomFinder AI.", 
            Toast.LENGTH_LONG).show();
        
        // Return success to LoginActivity
        setResult(RESULT_OK);
        finish();
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (binding != null) {
            binding = null;
        }
    }
}